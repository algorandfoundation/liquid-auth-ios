import AuthenticationServices
import CryptoKit
import Foundation
import WebRTC
import SwiftCBOR

#if canImport(UIKit)
import UIKit
#endif

// MARK: - LiquidAuthSDK Internal Implementation

// 🚀 This entire file will move to the LiquidAuthSDK package

/// This file contains all the complex WebAuthn/FIDO2 and signaling logic
/// It's currently in the example app for demonstration, but represents the internal
/// implementation that will be packaged in the LiquidAuthSDK to hide complexity from wallet developers

// MARK: - Helper Functions

private func getDeviceModel() -> String {
    #if canImport(UIKit) && !targetEnvironment(macCatalyst)
    return UIDevice.current.model
    #else
    return "Unknown Device"
    #endif
}

// MARK: - LiquidAuthSDK Internal Implementation

internal class LiquidAuthImplementation {
  /// Register implementation - contains all the complex WebAuthn logic
  internal static func performRegistration(
    origin: String,
    requestId: String,
    algorandAddress: String,
    challengeSigner: LiquidAuthChallengeSigner,
    p256KeyPair: P256.Signing.PrivateKey
  ) async throws -> LiquidAuthResult {
    // All this complex logic will be in the SDK
    let attestationApi = AttestationApi()

    let options: [String: Any] = [
      "username": algorandAddress,
      "displayName": "Liquid Auth User",
      "authenticatorSelection": ["userVerification": "required"],
      "extensions": ["liquid": true],
    ]

    let userAgent = Utility.getUserAgent()

    // Post attestation options
    let (data, sessionCookie) = try await attestationApi.postAttestationOptions(
      origin: origin,
      userAgent: userAgent,
      options: options
    )

    Logger.debug("Response data: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
    if let cookie = sessionCookie {
      Logger.debug("Session cookie: \(cookie)")
    }

    guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
          let challengeBase64Url = json["challenge"] as? String,
          let rp = json["rp"] as? [String: Any],
          let rpId = rp["id"] as? String
    else {
      throw NSError(domain: "com.liquidauth.error", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to parse response JSON"])
    }

    if origin != rpId {
      Logger.info("⚠️ Origin (\(origin)) and rpId (\(rpId)) are different.")
    }

    Logger.debug("Challenge (Base64): \(challengeBase64Url)")

    // Decode and sign the challenge using the provided signer
    let challengeBytes = Data(challengeBase64Url.utf8) // Pass the base64URL string as bytes, signer will decode

    let signature = try await challengeSigner.signLiquidAuthChallenge(challengeBytes)

    Logger.debug("Signature: \(signature.base64URLEncodedString())")

    // Create the Liquid extension JSON object
    let liquidExt = [
      "type": "algorand",
      "requestId": requestId,
      "address": algorandAddress,
      "signature": signature.base64URLEncodedString(),
      "device": getDeviceModel(),
    ]

    Logger.debug("Created liquidExt JSON object: \(liquidExt)")

    // Deterministic ID - derived from P256 Public Key
    let rawId = Data([UInt8](Utility.hashSHA256(p256KeyPair.publicKey.rawRepresentation)))
    Logger.debug("Created rawId: \(rawId.map { String(format: "%02hhx", $0) }.joined())")

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
    Logger.debug("Created clientDataJSON: \(clientDataJSONBase64Url)")

    // Create attestationObject
    let attestedCredData = Utility.getAttestedCredentialData(
      aaguid: UUID(uuidString: "1F59713A-C021-4E63-9158-2CC5FDC14E52")!,
      credentialId: rawId,
      publicKey: p256KeyPair.publicKey.rawRepresentation
    )

    Logger.debug("created attestedCredData: \(attestedCredData.count)")

    let rpIdHash = Utility.hashSHA256(rpId.data(using: .utf8)!)
    let authData = AuthenticatorData.attestation(
      rpIdHash: rpIdHash,
      userPresent: true,
      userVerified: true,
      backupEligible: false,
      backupState: false,
      signCount: 0,
      attestedCredentialData: attestedCredData,
      extensions: nil
    )
    Logger.debug("created authData: \(authData)")

    let attObj: [String: Any] = [
      "attStmt": [:],
      "authData": authData.toData(),
      "fmt": "none",
    ]

    let cborEncoded = try CBOR.encodeMap(attObj)
    let attestationObject = Data(cborEncoded)
    Logger.debug("Created attestationobject: \(attestationObject.base64URLEncodedString())")

    let credential: [String: Any] = [
      "id": rawId.base64URLEncodedString(),
      "type": "public-key",
      "rawId": rawId.base64URLEncodedString(),
      "response": [
        "clientDataJSON": clientDataJSONBase64Url,
        "attestationObject": attestationObject.base64URLEncodedString(),
      ],
    ]
    Logger.debug("Created credential: \(credential)")

    // Post attestation result
    let responseData = try await attestationApi.postAttestationResult(
      origin: origin,
      userAgent: Utility.getUserAgent(),
      credential: credential,
      liquidExt: liquidExt
    )

    // Handle the server response
    let responseString = String(data: responseData, encoding: .utf8) ?? "Invalid response"
    Logger.info("Attestation result posted: \(responseString)")

    // Parse the response to check for errors
    if let responseJSON = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
       let errorReason = responseJSON["error"] as? String
    {
      Logger.error("Registration failed: \(errorReason)")
      return LiquidAuthResult(success: false, errorMessage: "Registration failed: \(errorReason)")
    } else {
      Logger.info("Registration completed successfully.")

      // Save passkey identity (if available)
      if #available(iOS 17.0, macOS 14.0, *) {
        savePasskeyIdentity(
          relyingPartyIdentifier: origin,
          userName: algorandAddress,
          credentialID: rawId
        )
      }

      return LiquidAuthResult(success: true)
    }
  }

  /// Authenticate implementation - contains all the complex WebAuthn logic
  internal static func performAuthentication(
    origin: String,
    requestId: String,
    algorandAddress: String,
    challengeSigner: LiquidAuthChallengeSigner,
    p256KeyPair: P256.Signing.PrivateKey
  ) async throws -> LiquidAuthResult {
    let userAgent = Utility.getUserAgent()
    let assertionApi = AssertionApi()

    let credentialId = Data([UInt8](Utility.hashSHA256(p256KeyPair.publicKey.rawRepresentation))).base64URLEncodedString()

    // Call postAssertionOptions
    let (data, sessionCookie) = try await assertionApi.postAssertionOptions(
      origin: origin,
      userAgent: userAgent,
      credentialId: credentialId
    )

    if let sessionCookie = sessionCookie {
      Logger.debug("Session cookie: \(sessionCookie)")
    }

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
      Logger.info("⚠️ Origin (\(origin)) and rpId (\(rpId)) are different.")
    }

    Logger.debug("Challenge (Base64): \(challengeBase64Url)")

    // Decode and sign the challenge using the provided signer
    let challengeBytes = Data(challengeBase64Url.utf8) // Pass the base64URL string as bytes, signer will decode

    let signature = try await challengeSigner.signLiquidAuthChallenge(challengeBytes)

    Logger.debug("Signature: \(signature.base64URLEncodedString())")

    // Create the Liquid extension JSON object
    let liquidExt = [
      "type": "algorand",
      "requestId": requestId,
      "address": algorandAddress,
      "signature": signature.base64URLEncodedString(),
      "device": getDeviceModel(),
    ]

    Logger.debug("Created liquidExt JSON object: \(liquidExt)")

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
    Logger.debug("Created clientDataJSON: \(clientDataJSONBase64Url)")

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

    Logger.debug("Created assertion response: \(assertionResponse)")

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
    Logger.info("Assertion result posted: \(responseString)")

    // Parse the response to check for errors
    if let responseJSON = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
       let errorReason = responseJSON["error"] as? String
    {
      Logger.error("Authentication failed: \(errorReason)")
      return LiquidAuthResult(success: false, errorMessage: "Authentication failed: \(errorReason)")
    } else {
      Logger.info("Authentication completed successfully.")
      return LiquidAuthResult(success: true)
    }
  }

  /// Start signaling - will also move to SDK
  internal static func startSignaling(
    origin: String,
    requestId: String,
    messageHandler: LiquidAuthMessageHandler
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
        Logger.info("💬 Received message: \(message)")

        Task {
          if let response = await messageHandler.handleMessage(message) {
            signalService.sendMessage(response)
          }
        }
      },
      onStateChange: { state in
        if state == "open" {
          Logger.info("✅ Data channel is OPEN")
          signalService.sendMessage("ping")
        }
      }
    )
  }
}

@available(iOS 17.0, macOS 14.0, *)
private func savePasskeyIdentity(
  relyingPartyIdentifier: String,
  userName: String,
  credentialID: Data
) {
  let passkeyIdentity = ASPasskeyCredentialIdentity(
    relyingPartyIdentifier: relyingPartyIdentifier,
    userName: userName,
    credentialID: credentialID,
    userHandle: Data(SHA256.hash(data: Data(userName.utf8)))
  )

  ASCredentialIdentityStore.shared.saveCredentialIdentities([passkeyIdentity]) { success, error in
    if success {
      Logger.info("✅ Passkey identity saved to identity store!")
    } else if let error = error {
      Logger.error("❌ Failed to save passkey identity: \(error)")
    }
  }
}
