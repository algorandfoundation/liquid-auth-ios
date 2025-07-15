/*
 * Copyright 2025 Algorand Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import CryptoKit
import Foundation

// MARK: - LiquidAuthChallengeSigner

// 🚀 These protocols and classes will move to the LiquidAuthSDK package

/// Protocol for signing Liquid Auth challenges in the FIDO2 flow
/// Each wallet implements this to handle challenge signing with their specific key management
public protocol LiquidAuthChallengeSigner {
    /// Sign a challenge received from the Liquid Auth FIDO2 flow
    /// - Parameter challenge: The raw challenge bytes to sign
    /// - Returns: The signature bytes
    func signLiquidAuthChallenge(_ challenge: Data) async throws -> Data
}

// MARK: - LiquidAuthMessageHandler

/// Protocol for handling incoming messages during signaling
/// Wallets implement this to handle ARC27 transactions and other message types
public protocol LiquidAuthMessageHandler {
    /// Handle an incoming message and optionally return a response
    /// - Parameter message: The incoming message (base64URL encoded)
    /// - Returns: Optional response message (base64URL encoded) or nil if no response
    func handleMessage(_ message: String) async -> String?
}

// MARK: - LiquidAuthResult

public struct LiquidAuthResult {
    public let success: Bool
    public let errorMessage: String?

    public init(success: Bool, errorMessage: String? = nil) {
        self.success = success
        self.errorMessage = errorMessage
    }

    public static func success() -> LiquidAuthResult {
        LiquidAuthResult(success: true)
    }

    public static func failure(_ message: String) -> LiquidAuthResult {
        LiquidAuthResult(success: false, errorMessage: message)
    }
}

// MARK: - LiquidAuthClient

/// Main client for Liquid Auth operations
/// This is the primary entry point for the LiquidAuthSDK
///
/// Important: Both userAgent and device parameters must be provided by the calling application.
/// - userAgent should be in a format compatible with ua-parser-js. For example:
///   "liquid-auth/1.0 (iPhone; iOS 18.5)" or similar valid user agent strings.
/// - device should be a device identifier string (e.g., "iPhone", "iPad", "Mac", etc.)
public class LiquidAuthClient {
    public init() { }

    /// Register a new credential with Liquid Auth
    /// - Parameters:
    ///   - origin: The origin domain for the WebAuthn ceremony
    ///   - requestId: Unique identifier for this registration request
    ///   - algorandAddress: The Algorand address to associate with this credential
    ///   - challengeSigner: Handler for signing the WebAuthn challenge
    ///   - p256KeyPair: The P256 key pair to use for the credential
    ///   - messageHandler: Handler for incoming messages during signaling
    ///   - userAgent: User agent string to send to the server (must be provided by the calling app)
    ///   - device: Device identifier string to send to the server (must be provided by the calling app)
    /// - Returns: Result indicating success or failure
    public func register(
        origin: String,
        requestId: String,
        algorandAddress: String,
        challengeSigner: LiquidAuthChallengeSigner,
        p256KeyPair: P256.Signing.PrivateKey,
        messageHandler: LiquidAuthMessageHandler,
        userAgent: String,
        device: String
    ) async throws -> LiquidAuthResult {
        // Use the implementation from LiquidAuthImplementation
        let result = try await LiquidAuthImplementation.performRegistration(
            origin: origin,
            requestId: requestId,
            algorandAddress: algorandAddress,
            challengeSigner: challengeSigner,
            p256KeyPair: p256KeyPair,
            userAgent: userAgent,
            device: device
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
    /// - Parameters:
    ///   - origin: The origin domain for the WebAuthn ceremony
    ///   - requestId: Unique identifier for this authentication request
    ///   - algorandAddress: The Algorand address associated with the credential
    ///   - challengeSigner: Handler for signing the WebAuthn challenge
    ///   - p256KeyPair: The P256 key pair associated with the credential
    ///   - messageHandler: Handler for incoming messages during signaling
    ///   - userAgent: User agent string to send to the server (must be provided by the calling app)
    ///   - device: Device identifier string to send to the server (must be provided by the calling app)
    /// - Returns: Result indicating success or failure
    public func authenticate(
        origin: String,
        requestId: String,
        algorandAddress: String,
        challengeSigner: LiquidAuthChallengeSigner,
        p256KeyPair: P256.Signing.PrivateKey,
        messageHandler: LiquidAuthMessageHandler,
        userAgent: String,
        device: String
    ) async throws -> LiquidAuthResult {
        // Use the implementation from LiquidAuthImplementation
        let result = try await LiquidAuthImplementation.performAuthentication(
            origin: origin,
            requestId: requestId,
            algorandAddress: algorandAddress,
            challengeSigner: challengeSigner,
            p256KeyPair: p256KeyPair,
            userAgent: userAgent,
            device: device
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
