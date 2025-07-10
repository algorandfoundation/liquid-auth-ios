import CryptoKit
import Foundation

// MARK: - LiquidAuthSDK Public Interface

// 🚀 These protocols and classes will move to the LiquidAuthSDK package

/// Protocol for signing Liquid Auth challenges in the FIDO2 flow
/// Each wallet implements this to handle challenge signing with their specific key management
public protocol LiquidAuthChallengeSigner {
  /// Sign a challenge received from the Liquid Auth FIDO2 flow
  /// - Parameter challenge: The raw challenge bytes to sign
  /// - Returns: The signature bytes
  func signLiquidAuthChallenge(_ challenge: Data) async throws -> Data
}

/// Protocol for handling incoming messages during signaling
/// Wallets implement this to handle ARC27 transactions and other message types
public protocol LiquidAuthMessageHandler {
  /// Handle an incoming message and optionally return a response
  /// - Parameter message: The incoming message (base64URL encoded)
  /// - Returns: Optional response message (base64URL encoded) or nil if no response
  func handleMessage(_ message: String) async -> String?
}

// MARK: - SDK API Types

public struct LiquidAuthResult {
  public let success: Bool
  public let errorMessage: String?

  public init(success: Bool, errorMessage: String? = nil) {
    self.success = success
    self.errorMessage = errorMessage
  }

  public static func success() -> LiquidAuthResult {
    return LiquidAuthResult(success: true)
  }

  public static func failure(_ message: String) -> LiquidAuthResult {
    return LiquidAuthResult(success: false, errorMessage: message)
  }
}

/// Main client for Liquid Auth operations
/// This is the primary entry point for the LiquidAuthSDK
public class LiquidAuthClient {
  public init() {}

  /// Register a new credential with Liquid Auth
  public func register(
    origin: String,
    requestId: String,
    algorandAddress: String,
    challengeSigner: LiquidAuthChallengeSigner,
    p256KeyPair: P256.Signing.PrivateKey,
    messageHandler: LiquidAuthMessageHandler
  ) async throws -> LiquidAuthResult {
    // Use the implementation from LiquidAuthImplementation
    let result = try await LiquidAuthImplementation.performRegistration(
      origin: origin,
      requestId: requestId,
      algorandAddress: algorandAddress,
      challengeSigner: challengeSigner,
      p256KeyPair: p256KeyPair
    )

    if result.success {
      // Start signaling after successful registration
      try await LiquidAuthImplementation.startSignaling(
        origin: origin,
        requestId: requestId,
        messageHandler: messageHandler
      )
    }

    return result
  }

  /// Authenticate with an existing credential
  public func authenticate(
    origin: String,
    requestId: String,
    algorandAddress: String,
    challengeSigner: LiquidAuthChallengeSigner,
    p256KeyPair: P256.Signing.PrivateKey,
    messageHandler: LiquidAuthMessageHandler
  ) async throws -> LiquidAuthResult {
    // Use the implementation from LiquidAuthImplementation
    let result = try await LiquidAuthImplementation.performAuthentication(
      origin: origin,
      requestId: requestId,
      algorandAddress: algorandAddress,
      challengeSigner: challengeSigner,
      p256KeyPair: p256KeyPair
    )

    if result.success {
      // Start signaling after successful authentication
      try await LiquidAuthImplementation.startSignaling(
        origin: origin,
        requestId: requestId,
        messageHandler: messageHandler
      )
    }

    return result
  }
}
