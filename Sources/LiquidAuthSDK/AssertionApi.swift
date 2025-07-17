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

class AssertionApi {
    private let session: URLSessionProtocol

    init(session: URLSessionProtocol = URLSession.shared) {
        self.session = session
    }

    /**
     * POST request to retrieve PublicKeyCredentialRequestOptions
     *
     * - Parameters:
     *   - origin: Base URL for the service
     *   - userAgent: User Agent for FIDO Server parsing
     *   - credentialId: Credential ID for the request
     *   - liquidExt: Optional Liquid extension flag
     * - Returns: A tuple containing the response data and an optional session cookie
     */
    func postAssertionOptions(
        origin: String,
        userAgent: String,
        credentialId: String,
        liquidExt: Bool? = true
    ) async throws -> (Data, HTTPCookie?) {
        guard !origin.isEmpty else {
            throw LiquidAuthError.invalidURL("Origin cannot be empty")
        }
        
        let path = "https://\(origin)/assertion/request/\(credentialId)"
        Logger.debug("AssertionApi: POST \(path)")
        Logger.debug("AssertionApi: credentialId: \(credentialId)")
        Logger.debug("AssertionApi: liquidExt: \(String(describing: liquidExt))")

        guard let url = URL(string: path) else {
            throw LiquidAuthError.invalidURL(path)
        }

        // Construct the payload
        var payload: [String: Any] = [:]
        if let liquidExt {
            payload["extensions"] = liquidExt
        }
        Logger.debug("AssertionApi: Request payload: \(payload)")

        // Serialize the payload into JSON
        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            throw LiquidAuthError.invalidJSON("Failed to serialize assertion options")
        }
        Logger.debug("AssertionApi: Request body (raw): \(String(data: body, encoding: .utf8) ?? "nil")")

        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        do {
            // Perform the request
            let (data, response) = try await session.data(for: request)
            Logger.debug("AssertionApi: Response data: \(String(data: data, encoding: .utf8) ?? "nil")")

            // Ensure the response is an HTTPURLResponse
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LiquidAuthError.networkError(URLError(.badServerResponse))
            }
            Logger.debug("AssertionApi: Response headers: \(httpResponse.allHeaderFields)")

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
            Logger.debug("AssertionApi: Session cookie: \(String(describing: sessionCookie))")

            return (data, sessionCookie)
        } catch {
            if error is LiquidAuthError {
                throw error
            }
            throw LiquidAuthError.networkError(error)
        }
    }

    /**
     * POST request to send the PublicKeyCredential in response to assertion
     *
     * - Parameters:
     *   - origin: Base URL for the service
     *   - userAgent: User Agent for FIDO Server parsing
     *   - credential: PublicKeyCredential from Authenticator Response (JSON string)
     *   - liquidExt: Optional Liquid extension data
     * - Returns: The response data
     */
    func postAssertionResult(
        origin: String,
        userAgent: String,
        credential: String,
        liquidExt: [String: Any]? = nil
    ) async throws -> Data {
        guard !origin.isEmpty else {
            throw LiquidAuthError.invalidURL("Origin cannot be empty")
        }
        
        let path = "https://\(origin)/assertion/response"
        Logger.debug("AssertionApi: POST \(path)")
        Logger.debug("AssertionApi: credential: \(credential)")
        if let liquidExt {
            Logger.debug("AssertionApi: Liquid extension: \(liquidExt)")
        }

        guard let url = URL(string: path) else {
            throw LiquidAuthError.invalidURL(path)
        }

        guard let credentialData = credential.data(using: .utf8),
              var payload = try? JSONSerialization.jsonObject(with: credentialData, options: []) as? [String: Any]
        else {
            throw LiquidAuthError.invalidJSON("Invalid credential JSON")
        }

        if let liquidExt {
            payload["clientExtensionResults"] = ["liquid": liquidExt]
        }
        Logger.debug("AssertionApi: Full payload: \(payload)")

        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            throw LiquidAuthError.invalidJSON("Failed to serialize assertion result")
        }
        Logger.debug("AssertionApi: Request body (raw): \(String(data: body, encoding: .utf8) ?? "nil")")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        do {
            let (data, _) = try await session.data(for: request)
            Logger.debug("AssertionApi: Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
            return data
        } catch {
            throw LiquidAuthError.networkError(error)
        }
    }
}
