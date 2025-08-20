# Liquid Auth (iOS)

Welcome to the iOS SDK implementation of [Liquid Auth](https://liquidauth.com)!

For the reference iOS app implementation, please refer to [liquid-auth-ios-example](https://github.com/algorandfoundation/liquid-auth-ios-example). The example app showcases how to integrate the Liquid Auth iOS SDK into a main app, as well as how to integrate Liquid Auth into an Autofill Credential Extension.


## Background

Liquid Auth does three major things:

* Brings self-sovereignty to the FIDO2/WebAuthn authentication process, using [deterministically generated P256 passkeys](https://github.com/algorandfoundation/deterministic-P256-swift). No more relying on a centralized password manager or Big Tech vendor for passkeys.

* Allows for decentralized, peer-to-peer, authenticated, communications between dApps and wallets, using WebRTC. Web3 applications should not have to communicate with their users through communication channels controlled by rent-seeking, centralized entities. The passkeys allow for authenticating a user before setting up the WebRTC communication tunnel.

* Adds an extension field to the vanilla FIDO2/WebAuthn protocol, containing a challenge signed by an Ed25519 Algorand address. This enables "Sign-In with Algorand" use-cases piggy-backing off of the Web Authentication Standard.

# How to Use

Please refer to the [example app](https://github.com/algorandfoundation/liquid-auth-ios-example) for a complete reference implementation of Liquid Auth (iOS).

## Installation

### Requirements:

- ***iOS 17+*** for use in Autofill Extension Credential.

Note that running WebRTC on a simulated iOS device is not possible. You must use an actual device to test it out.

### Swift Package Manager

Add this to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/algorandfoundation/liquid-auth-ios.git", from: "1.0.0")
]
```
### Xcode

- File → Add Package Dependencies...
- Enter: https://github.com/algorandfoundation/liquid-auth-ios.git


## 

## Liquid Auth "Modes of Operation"

This SDK can be used in two ways:

1. Paired with the Liquid Auth Backend, allowing for authenticated peer-to-peer communications.
  -> `liquid://{origin}/?requestId={UUID}` URIs.
2. Hooked into iOS' Autofill Credential Extension, for authentication with standard Web2 sites.
  -> `FIDO:/{CTAP}` URIs.

For an example of 1., check out the [LiquidAuth.com](http://liquidauth.com) demo, or the [use-wallet](https://txnlab.gitbook.io/use-wallet) example frontends.

For an example of 2., check out [webauthn.io](webauthn.io), [webauthn.me](webauthn.me) or [passkeys.com](passkeys.com). Or, visit any Passkey-enabled site (like Github itself).


## Implementing Liquid Auth (`liquid://`)


The following is an example Liquid Auth Implementation. It has three functions:

- `registration(...)`: Illustrates the flow of registering a passkey, for future authentication.
- `authentication(...)`: Illustrates the flow of authenticating with an already registered passkey.

In the process of going through the above two flows, the request ID - a UUID sent from the origin/relying party - is what ultimately gets authenticated and what is communicated over.

- `startSignaling(...)`: Is provided with an origin and requestId, setting up communication.

The app

```swift
import AuthenticationServices
import CryptoKit
import Foundation
import SwiftCBOR
import WebRTC

#if canImport(UIKit)
import UIKit
#endif

/// Register implementation - contains all the complex WebAuthn logic
///
/// - Parameters:
///   - origin: The origin domain for the WebAuthn ceremony
///   - requestId: Unique identifier for this registration request
///   - algorandAddress: The Algorand address to associate with this credential
///   - p256KeyPair: The P256 key pair to use for the credential
///   - userAgent: User agent string to send to the server (provided by the calling app)
///   - device: Device identifier string to send to the server (provided by the calling app)
/// - Returns: Result indicating success or failure

func registration(
    origin: String,
    requestId: String,
    algorandAddress: String,
    p256KeyPair: P256.Signing.PrivateKey,
    userAgent: String,
    device: String
) async throws -> LiquidAuthResult {
    let attestationApi = AttestationApi()

    let options: [String: Any] = [
        "username": algorandAddress,
        "displayName": "Liquid Auth User",
        "authenticatorSelection": ["userVerification": "required"],
        "extensions": ["liquid": true],
    ]

    // Post attestation options
    let (data, sessionCookie) = try await attestationApi.postAttestationOptions(
        origin: origin,
        userAgent: userAgent,
        options: options
    )

    guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
          let challengeBase64Url = json["challenge"] as? String,
          let rp = json["rp"] as? [String: Any],
          let rpId = rp["id"] as? String
    else {
        throw NSError(domain: "com.liquidauth.error", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "Failed to parse response JSON"])
    }

    if origin != rpId {
        print("⚠️ Origin (\(origin)) and rpId (\(rpId)) are different.")
    }

    // Decode the challenge
    let challengeBytes = Data([UInt8](Utility.decodeBase64Url(challengeBase64Url)!))

    // Sign the challenge with your Algorand Ed25519 private key
    // This is where you integrate with your wallet's signing mechanism
    let signature = /* your wallet signing logic here */

    // Create the Liquid extension JSON object
    let liquidExt = [
        "type": "algorand",
        "requestId": requestId,
        "address": algorandAddress,
        "signature": signature.base64URLEncodedString(),
        "device": device,
    ]

    // Deterministic ID - derived from P256 Public Key
    let rawId = Data([UInt8](Utility.hashSHA256(p256KeyPair.publicKey.rawRepresentation)))

    // Create clientDataJSON
    let clientData: [String: Any] = [
        "type": "webauthn.create",
        "challenge": challengeBase64Url,
        "origin": "https://\(rpId)",
    ]

    guard let clientDataJSONData = try? JSONSerialization.data(withJSONObject: clientData, options: []) else {
        throw NSError(domain: "com.liquidauth.error", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "Failed to create clientDataJSON"])
    }

    let clientDataJSONBase64Url = clientDataJSONData.base64URLEncodedString()

    // Create attestationObject
    let attestedCredData = Utility.getAttestedCredentialData(
        aaguid: UUID(uuidString: "1F59713A-C021-4E63-9158-2CC5FDC14E52")!,
        credentialId: rawId,
        publicKey: p256KeyPair.publicKey.rawRepresentation
    )

    let rpIdHash = Utility.hashSHA256(rpId.data(using: .utf8)!)
    let authData = AuthenticatorData.attestation(
        rpIdHash: rpIdHash,
        userPresent: true,
        userVerified: true,
        backupEligible: true,
        backupState: true,
        signCount: 0,
        attestedCredentialData: attestedCredData,
        extensions: nil
    )

    let attObj: [String: Any] = [
        "attStmt": [:],
        "authData": authData.toData(),
        "fmt": "none",
    ]

    let cborEncoded = try CBOR.encodeMap(attObj)
    let attestationObject = Data(cborEncoded)

    let credential: [String: Any] = [
        "id": rawId.base64URLEncodedString(),
        "type": "public-key",
        "rawId": rawId.base64URLEncodedString(),
        "response": [
            "clientDataJSON": clientDataJSONBase64Url,
            "attestationObject": attestationObject.base64URLEncodedString(),
        ],
    ]

    // Post attestation result
    let responseData = try await attestationApi.postAttestationResult(
        origin: origin,
        userAgent: userAgent,
        credential: credential,
        liquidExt: liquidExt,
        device: device
    )

    // Handle the server response
    let responseString = String(data: responseData, encoding: .utf8) ?? "Invalid response"

    // Parse the response to check for errors
    if let responseJSON = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
        let errorReason = responseJSON["error"] as? String
    {
        print("Registration failed: \(errorReason)")
        return LiquidAuthResult(success: false, errorMessage: "Registration failed: \(errorReason)")
    } else {
        print("Registration completed successfully.")
        return LiquidAuthResult(success: true)
    }
}

/// Authentication Flow
///
/// - Parameters:
///   - origin: The origin domain for the WebAuthn ceremony
///   - requestId: Unique identifier for this authentication request
///   - algorandAddress: The Algorand address associated with the credential
///   - challengeSigner: Handler for signing the WebAuthn Ed25519 Liquid Extension challenge
///   - p256KeyPair: The P256 key pair associated with the credential
///   - userAgent: User agent string to send to the server (provided by the calling app)
///   - device: Device identifier string to send to the server (provided by the calling app)
/// - Returns: Result indicating success or failure
func authentication(
    origin: String,
    requestId: String,
    algorandAddress: String,
    p256KeyPair: P256.Signing.PrivateKey,
    userAgent: String,
    device: String
) async throws -> LiquidAuthResult {
    let assertionApi = AssertionApi()

    let credentialId = Data([UInt8](Utility.hashSHA256(p256KeyPair.publicKey.rawRepresentation)))
        .base64URLEncodedString()

    // Call postAssertionOptions
    let (data, sessionCookie) = try await assertionApi.postAssertionOptions(
        origin: origin,
        userAgent: userAgent,
        credentialId: credentialId
    )

    // Parse the response data
    guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
          let challengeBase64Url = json["challenge"] as? String
    else {
        throw NSError(domain: "com.liquidauth.error", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "Failed to parse response JSON"])
    }

    // Support both "rp": { "id": ... } and "rpId": ...
    let rpId: String
    if let rp = json["rp"] as? [String: Any], let id = rp["id"] as? String {
        rpId = id
    } else if let id = json["rpId"] as? String {
        rpId = id
    } else {
        throw NSError(domain: "com.liquidauth.error", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "Failed to find rpId in response."])
    }

    if origin != rpId {
        print("⚠️ Origin (\(origin)) and rpId (\(rpId)) are different.")
    }

    // Decode the challenge
    let challengeBytes = Data([UInt8](Utility.decodeBase64Url(challengeBase64Url)!))

    // Sign the challenge with your Algorand Ed25519 private key
    // This is where you integrate with your wallet's signing mechanism
    let signature = /* your wallet signing logic here */

    // Create the Liquid extension JSON object
    let liquidExt = [
        "type": "algorand",
        "requestId": requestId,
        "address": algorandAddress,
        "signature": signature.base64URLEncodedString(),
        "device": device,
    ]

    // Create clientDataJSON
    let clientData: [String: Any] = [
        "type": "webauthn.get",
        "challenge": challengeBase64Url,
        "origin": "https://\(rpId)",
    ]

    guard let clientDataJSONData = try? JSONSerialization.data(withJSONObject: clientData, options: []) else {
        throw NSError(domain: "com.liquidauth.error", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "Failed to create clientDataJSON"])
    }

    let clientDataJSONBase64Url = clientDataJSONData.base64URLEncodedString()

    let rpIdHash = Utility.hashSHA256(rpId.data(using: .utf8)!)
    let authenticatorData = AuthenticatorData.assertion(
        rpIdHash: rpIdHash,
        userPresent: true,
        userVerified: true,
        backupEligible: false,
        backupState: false
    ).toData()

    let clientDataHash = Utility.hashSHA256(clientDataJSONData)
    let dataToSign = authenticatorData + clientDataHash

    let p256Signature = try p256KeyPair.signature(for: dataToSign)

    let assertionResponse: [String: Any] = [
        "id": credentialId,
        "type": "public-key",
        "userHandle": "tester",
        "rawId": credentialId,
        "response": [
            "clientDataJSON": clientDataJSONData.base64URLEncodedString(),
            "authenticatorData": authenticatorData.base64URLEncodedString(),
            "signature": p256Signature.derRepresentation.base64URLEncodedString(),
        ],
    ]

    // Serialize the assertion response into a JSON string
    guard let assertionResponseData = try? JSONSerialization.data(withJSONObject: assertionResponse, options: []),
          let assertionResponseJSON = String(data: assertionResponseData, encoding: .utf8)
    else {
        throw NSError(domain: "com.liquidauth.error", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "Failed to serialize assertion response"])
    }

    // Post the assertion result
    let responseData = try await assertionApi.postAssertionResult(
        origin: origin,
        userAgent: userAgent,
        credential: assertionResponseJSON,
        liquidExt: liquidExt
    )

    // Handle the server response
    let responseString = String(data: responseData, encoding: .utf8) ?? "Invalid response"

    // Parse the response to check for errors
    if let responseJSON = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
        let errorReason = responseJSON["error"] as? String
    {
        print("Authentication failed: \(errorReason)")
        return LiquidAuthResult(success: false, errorMessage: "Authentication failed: \(errorReason)")
    } else {
        print("Authentication completed successfully.")
        return LiquidAuthResult(success: true)
    }
}

/// Start signaling for peer-to-peer communication
///
/// Can be called after either register or authenticate have been used
/// to prove ownership of a Request Id.
///
/// - Parameters:
///   - origin: The origin domain for the signaling service
///   - requestId: Unique identifier for this signaling session
///   - messageHandler: Handler for incoming messages during the session
/// - Throws: LiquidAuthError if signaling setup fails
func startSignaling(
    origin: String,
    requestId: String,
) async throws {
    let signalService = SignalService.shared

    signalService.start(url: origin, httpClient: URLSession.shared)

    let NODELY_TURN_USERNAME = "liquid-auth"
    let NODELY_TURN_CREDENTIAL = "sqmcP4MiTKMT4TGEDSk9jgHY"

    let iceServers = [
        RTCIceServer(
            urlStrings: [
                "stun:stun.l.google.com:19302",
                "stun:stun1.l.google.com:19302",
                "stun:stun2.l.google.com:19302",
                "stun:stun3.l.google.com:19302",
                "stun:stun4.l.google.com:19302",
            ]
        ),
        RTCIceServer(
            urlStrings: [
                "turn:global.turn.nodely.network:80?transport=tcp",
                "turns:global.turn.nodely.network:443?transport=tcp",
                "turn:eu.turn.nodely.io:80?transport=tcp",
                "turns:eu.turn.nodely.io:443?transport=tcp",
                "turn:us.turn.nodely.io:80?transport=tcp",
                "turns:us.turn.nodely.io:443?transport=tcp",
            ],
            username: NODELY_TURN_USERNAME,
            credential: NODELY_TURN_CREDENTIAL
        ),
    ]

    signalService.connectToPeer(
        requestId: requestId,
        type: "answer",
        origin: origin,
        iceServers: iceServers,
        onMessage: { message in
            print("💬 Received message: \(message)")

            Task {
                // Handle incoming messages from the dApp (e.g., transaction requests)
                // Integrate with your wallet's message handling and signing logic
                let response = /* your message handling logic here */
                
                if let response = response {
                    signalService.sendMessage(response)
                }
            }
        },
        onStateChange: { state in
            if state == "open" {
                print("✅ Data channel is OPEN")
                signalService.sendMessage("ping")
            }
        }
    )
}
```

**Integration Points:**

The SDK provides the WebAuthn infrastructure, but you'll need to integrate with your wallet for:

1. **Challenge Signing**: Sign the WebAuthn challenge with your Algorand Ed25519 private key
2. **Message Handling**: Process incoming WebRTC messages (typically transaction requests) according to your wallet's workflow
3. **Key Management**: Manage P256 key pairs and Algorand key pairs according to your security model

The exact implementation depends on your wallet's architecture, key storage, and user interaction patterns.


[!IMPORTANT]
The Liquid Auth SDK in its current implementation is only for "client"/"answerer" usage, against an "offerer". It does not have the capability to be the "offerer", generate request IDs for other devices to connect. Simply put, it is intended to be implemented as part of mobile wallets, registering/authenticating against a dApp.


```
┌─────────────┐     WebRTC     ┌─────────────┐
│   dApp      │◄──────────────►│   Wallet    │
│ (Offerer)   │                │ (Answerer)  │
└─────────────┘                └─────────────┘
      │                               │
      └─────── Liquid Auth Backend ───┘
```


## Implementing as part of an Autofill Credential Extension (`FIDO:/`)

Having an Autofill Credential Extension in your iOS app allows you to list your app as a passkey manager under `Settings -> General -> AutoFill & Passwords".

Then, when a `FIDO:/` QR code pops up, your users can open up the Camera app, scan the QR code, press `Save a passkey` when the option appears and follow the Sign in flow with your app as an option.

In your Extension, in addition to setting all the correct entitlements and so on, you will need to implement [ASCredentialProviderViewController](https://developer.apple.com/documentation/authenticationservices/ascredentialproviderviewcontroller), including overriding methods like `prepareInterface` (registration) and `prepareInterfaceToProvideCredential` (authentication).

When iOS system calls on your Extension, it expects you to create an [ASPasskeyRegistrationCredential](https://developer.apple.com/documentation/authenticationservices/aspasskeyregistrationcredential/) and to pass it back to the system ([completeRegistrationRequest](https://developer.apple.com/documentation/authenticationservices/ascredentialproviderextensioncontext/completeregistrationrequest(using:completionhandler:))).

In this mode of operation, iOS will handle things like calling the service's Assertion or Attestation API for you. Your responsibility is to construct the ASPasskeyRegistrationCredential credential. The utility of this SDK lies in constructing that credential.

```swift
import LiquidAuthSDK
import SwiftCBOR

// Registration, a.k.a. Attestation in the WebAuthn context
override func prepareInterface(forPasskeyRegistration request: ASCredentialRequest) {

  // ...

  let credentialID = Data([UInt8](Utility.hashSHA256(p256KeyPair.publicKey.rawRepresentation))) // Provided by LiquidAuthSDK

  // --- Build attestationObject ---
  let aaguid = UUID(uuidString: "1F59713A-C021-4E63-9158-2CC5FDC14E52")! // Generate something unique for your app.

  let attestedCredData = Utility.getAttestedCredentialData( // Provided by LiquidAuthSDK
      aaguid: aaguid,
      credentialId: credentialID,
      publicKey: p256KeyPair.publicKey.rawRepresentation
  )

  let rpIdHash = Utility.hashSHA256(request.credentialIdentity.relyingPartyIdentifier.data(using: .utf8)!)

  let authData = AuthenticatorData.attestation( // Provided by LiquidAuthSDK
      rpIdHash: rpIdHash,
      userPresent: true,
      userVerified: true, // Make sure to actually have the user verify!
      backupEligible: true, // These flags MUST be set
      backupState: true,
      signCount: 0,
      attestedCredentialData: attestedCredData,
      extensions: nil
  ).toData()

  let attObj: [String: CBOR] = [
      "attStmt": CBOR.map([:]),
      "authData": CBOR.byteString([UInt8](authData)),
      "fmt": CBOR.utf8String("none"),
  ]
  let cborEncoded = try CBOR.encode(attObj)
  let attestationObject = Data(cborEncoded)

  let credential = ASPasskeyRegistrationCredential(
              relyingParty: request.credentialIdentity.relyingPartyIdentifier,
              clientDataHash: request.clientDataHash,
              credentialID: credentialID,
              attestationObject: attestationObject
          )

  // ...

  await extensionContext.completeRegistrationRequest(using: credential) 
}

// Authentication, a.k.a. Assertion in the WebAuthn context
override func prepareInterfaceToProvideCredential(for request: ASCredentialRequest) {

  // ...

  let signature = p256KeyPair.signature(for: request.clientDataHash).derRepresentation
  let CredentialID = Data(Utility.hashSHA256(p256KeyPair.publicKey.rawRepresentation)) // Provided by LiquidAuthSDK

  // Only present if the credentialID matches what the system is asking for
  guard CredentialID == request.credentialIdentity.credentialID else {
      throw NSError(domain: "No matching credential found", code: -1)
  }

    // --- Build authenticatorData ---
  let rpIdHash = Utility.hashSHA256(request.credentialIdentity.relyingPartyIdentifier.data(using: .utf8)!) // Provided by LiquidAuthSDK
  let authenticatorData = AuthenticatorData.assertion( // Provided by LiquidAuthSDK
      rpIdHash: rpIdHash,
      userPresent: true,
      userVerified: true, // Make sure to actually have the user verify!
      backupEligible: true, // These flags must be set!
      backupState: true,
      signCount: 0
  ).toData()


  let credential = ASPasskeyAssertionCredential(
              userHandle: request.credentialIdentity.userHandle,
              relyingParty: request.credentialIdentity.relyingPartyIdentifier,
              signature: signature,
              clientDataHash: request.clientDataHash,
              authenticatorData: authenticatorData,
              credentialID: credentialID
          )

  // ...
  
  await extensionContext.completeAssertionRequest(using: credential)

  }
```

- `relyingParty`: the equivalent of the `origin`, the entity you are authenticating with. This data is passed into the Extension by iOS, through [ASPasskeyCredentialRequest](https://developer.apple.com/documentation/authenticationservices/aspasskeycredentialrequest).
- `clientDataHash`: this information is also made available from iOS.
- `credentialID`: The ID by which the RP stores your passkey by. In our implementation we deterministically generate this by taking a SHA256 hash of the public key. This important to make sure that different devices (or even the same device over time) will be able to recognize when the RP is presenting a specific passkey associated with a user handle and asking you to authenticate with it.
- `userHandle`: The user handle that the user is trying to sign in with at the relying party.
- `signature (authentication)`: a signature produced by signing the accompanying `request.clientDataHash` with the passkey in question. Must be in the Distinguished Encoding Rules (DER) representation.

`attestationObject` and `authenticatorData` respectively are objects that the LiquidAuthSDK library can help you construct.

What the code example above - taken and modified from [AutofillCredentialExtension/CredentialProviderViewController.swift](https://github.com/algorandfoundation/liquid-auth-ios-example/blob/main/liquid-auth-ios-example/AutofillCredentialExtension/CredentialProviderViewController.swift) in the reference app - omits is the exact details of how the p256 passkey is generated.


## Security Considerations
- Always verify user presence/verification flags
- Store private keys securely (Keychain/Secure Enclave)
- Validate origin domains against allowlists
- Use proper AAGUID for your application