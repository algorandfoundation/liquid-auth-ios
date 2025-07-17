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

- ***iOS 17+***

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

```swift
import LiquidAuthSDK

// ...

func register (origin: String, requestId: String) async {
  let client = LiquidAuthClient()

  let result = try await client.register(
    origin: origin,
    requestId: requestId,
    algorandAddress: address,
    challengeSigner: challengeSigner,
    p256KeyPair: p256KeyPair,
    messageHandler: messageHandler,
    userAgent: userAgent,
    device: device
  )
}

// ...

func authenticate (origin: String, requestId: String) async {
  let client = LiquidAuthClient()

  let result = try await client.authenticate(
    origin: origin,
    requestId: requestId,
    algorandAddress: address,
    challengeSigner: challengeSigner,
    p256KeyPair: p256KeyPair,
    messageHandler: messageHandler,
    userAgent: userAgent,
    device: device
  )
}

```

The client exposes the `register` and `authenticate` methods. Use them to register and authenticate with a passkey respectively. 

- `origin`: typically refers to the domain of the Web3 frontend. Note that it doesn't necessarily have to coincide with the domain of the underlying Liquid Auth backend, e.g. if you are relying on a node provider to run the backend for you. Typically parsed from a `liquid://` URI QR code.

- `requestId`: a UUID corresponding to the current connection request. The point of the WebAuthn flow is to authenticate that specific UUID, so we can then setup the WebRTC connection over it. Typically parsed from a `liquid://` URI QR code.

- `algorandAddress`: base32-encoded Algorand address (58 characters)

- `challengeSigner`: a method you need to implement and pass along into the SDK in accordance with `protocol LiquidAuthChallengeSigner`. It must be able to accept a 32 byte challenge nonce and return the signature bytes of it signed by the above-mentioned Algorand address/public key. The challenge refers to the Liquid extension that has been added on top of the standard WebAuthn flow.

- `p256KeyPair`: the passkey (P256 elliptic-curve private/public keypair) that is to be registered or authenticated with. Feel free to either generate a random keypair with the standard iOS Crypto library, or deterministically do so (with a 24 word mnemonic) using the [dP256 library](deterministic-P256-swift/Tests/deterministicP…).

- `messageHandler`: the second method you need to implement in accordance with `protocol LiquidAuthMessageHandler`. This method will accept messages from the counter-party (e.g., transaction bytes to sign), allow you to handle them (e.g., signing those bytes) before sending them back in a response.

- `userAgent`: Your app's user agent string (e.g., "liquid-auth/1.0 (iPhone; iOS 18.5)"). Needs to conform with [ua-parser-js](https://www.npmjs.com/package/ua-parser-js).

- `device`: Device identifier (e.g., "iPhone", "iPad")

```swift
class MyChallengeSigner: LiquidAuthChallengeSigner {
    func signChallenge(_ challenge: Data) async throws -> Data {
        // Implementation example
    }
}

class MyMessageHandler: LiquidAuthMessageHandler {
    func handleMessage(_ message: String) async -> String? {
        // Implementation example  
    }
}
```

[!IMPORTANT]
The Liquid Auth SDK in its current implementation is only for "client"/"answerer" usage, against an "offerer". It does not have the capability to be the "offerer", generate request IDs for other devices to connect. Simply put, it is intended to be implemented as part of mobile wallets, registering/authenticating against a dApp.

┌─────────────┐     WebRTC     ┌─────────────┐
│   dApp      │◄──────────────►│   Wallet    │
│ (Offerer)   │                │ (Answerer)  │
└─────────────┘                └─────────────┘
      │                               │
      └─────── Liquid Auth Backend ───┘


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