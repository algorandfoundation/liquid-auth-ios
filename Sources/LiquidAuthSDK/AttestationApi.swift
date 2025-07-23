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

import Foundation

#if canImport(UIKit)
import UIKit
#endif

// MARK: - AttestationApi

public class AttestationApi {
    public let session: URLSessionProtocol

    public init(session: URLSessionProtocol = URLSession.shared) {
        self.session = session
    }

    /**
     * POST request to retrieve PublicKeyCredentialCreationOptions
     *
     * - Parameters:
     *   - origin: Base URL for the service
     *   - userAgent: User Agent for FIDO Server parsing
     *   - options: PublicKeyCredentialCreationOptions in JSON
     * - Returns: A tuple containing the response data and an optional session cookie
     */
    public func postAttestationOptions(
        origin: String,
        userAgent: String,
        options: [String: Any]
    ) async throws -> (Data, HTTPCookie?) {
        guard !origin.isEmpty else {
            throw LiquidAuthError.invalidURL("Origin cannot be empty")
        }

        // Construct the URL
        let path = "https://\(origin)/attestation/request"
        Logger.debug("AttestationApi: POST \(path)")
        Logger.debug("AttestationApi: Request options: \(options)")
        guard let url = URL(string: path) else {
            throw LiquidAuthError.invalidURL(path)
        }

        // Serialize the options into JSON
        guard let body = try? JSONSerialization.data(withJSONObject: options, options: []) else {
            throw LiquidAuthError.invalidJSON("Failed to serialize attestation options")
        }

        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        Logger.debug("AttestationApi: Request body (raw): \(String(data: body, encoding: .utf8) ?? "nil")")

        do {
            // Perform the request
            let (data, response) = try await session.data(for: request)
            Logger.debug("AttestationApi: Response data: \(String(data: data, encoding: .utf8) ?? "nil")")

            // Ensure the response is an HTTPURLResponse
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LiquidAuthError.networkError(URLError(.badServerResponse))
            }

            Logger.debug("AttestationApi: Response headers: \(httpResponse.allHeaderFields)")

            // Check for HTTP errors
            guard 200 ... 299 ~= httpResponse.statusCode else {
                throw LiquidAuthError.serverError("HTTP \(httpResponse.statusCode)")
            }

            // Extract the session cookie
            let cookies = HTTPCookie.cookies(
                withResponseHeaderFields: httpResponse.allHeaderFields as? [String: String] ?? [:],
                for: url
            )
            let sessionCookie = cookies.first(where: { $0.name == "connect.sid" })
            Logger.debug("AttestationApi: Session cookie: \(String(describing: sessionCookie))")

            return (data, sessionCookie)
        } catch {
            if error is LiquidAuthError {
                throw error
            }
            throw LiquidAuthError.networkError(error)
        }
    }

    /**
     * POST request to send the PublicKeyCredential in response to attestation
     *
     * - Parameters:
     *   - origin: Base URL for the service
     *   - userAgent: User Agent for FIDO Server parsing
     *   - credential: PublicKeyCredential from Authenticator Response
     *   - liquidExt: Optional Liquid extension data
     *   - device: Device identifier string
     * - Returns: The response data
     */
    public func postAttestationResult(
        origin: String,
        userAgent: String,
        credential: [String: Any],
        liquidExt: [String: Any]? = nil,
        device: String
    ) async throws -> Data {
        guard !origin.isEmpty else {
            throw LiquidAuthError.invalidURL("Origin cannot be empty")
        }

        // Construct the URL
        let path = "https://\(origin)/attestation/response"
        Logger.debug("AttestationApi: POST \(path)")
        Logger.debug("AttestationApi: Credential: \(credential)")
        if let liquidExt {
            Logger.debug("AttestationApi: Liquid extension: \(liquidExt)")
        }

        guard let url = URL(string: path) else {
            throw LiquidAuthError.invalidURL(path)
        }

        var payload = credential
        if let liquidExt {
            let clientExtensionResults: [String: Any] = ["liquid": liquidExt]
            payload["clientExtensionResults"] = clientExtensionResults
        }

        // Add device information
        payload["device"] = device

        Logger.debug("AttestationApi: Full payload: \(payload)")

        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            throw LiquidAuthError.invalidJSON("Failed to serialize attestation result")
        }
        Logger.debug("AttestationApi: Request body (raw): \(String(data: body, encoding: .utf8) ?? "nil")")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        do {
            let (data, _) = try await session.data(for: request)
            Logger.debug("AttestationApi: Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            return data
        } catch {
            throw LiquidAuthError.networkError(error)
        }
    }
}
