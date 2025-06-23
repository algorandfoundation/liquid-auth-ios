import Foundation
import UIKit

class AssertionApi {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /**
     * POST request to retrieve PublicKeyCredentialRequestOptions
     *
     * @param origin - Base URL for the service
     * @param userAgent - User Agent for FIDO Server parsing
     * @param credentialId - Credential ID for the request
     * @param liquidExt - Optional Liquid extension flag
     * @return A tuple containing the response data and an optional session cookie
     */
    func postAssertionOptions(
        origin: String,
        userAgent: String,
        credentialId: String,
        liquidExt: Bool? = true
    ) async throws -> (Data, HTTPCookie?) {
        // Assuming HTTPS
        let path = "https://\(origin)/assertion/request/\(credentialId)"
        Logger.debug("AssertionApi: POST \(path)")
        Logger.debug("AssertionApi: credentialId: \(credentialId)")
        Logger.debug("AssertionApi: liquidExt: \(String(describing: liquidExt))")
        guard let url = URL(string: path) else {
            throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
        }

        // Construct the payload
        var payload: [String: Any] = [:]
        if let liquidExt = liquidExt {
            payload["extensions"] = liquidExt
        }
        Logger.debug("AssertionApi: Request payload: \(payload)")

        // Serialize the payload into JSON
        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            throw NSError(domain: "Invalid JSON", code: -1, userInfo: nil)
        }
        Logger.debug("AssertionApi: Request body (raw): \(String(data: body, encoding: .utf8) ?? "nil")")

        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        // Perform the request
        let (data, response) = try await session.data(for: request)
        Logger.debug("AssertionApi: Response data: \(String(data: data, encoding: .utf8) ?? "nil")")

        // Ensure the response is an HTTPURLResponse
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid response", code: -1, userInfo: nil)
        }
        Logger.debug("AssertionApi: Response headers: \(httpResponse.allHeaderFields)")

        // Extract the session cookie
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: httpResponse.allHeaderFields as! [String: String], for: url)
        let sessionCookie = cookies.first(where: { $0.name == "connect.sid" })
        Logger.debug("AssertionApi: Session cookie: \(String(describing: sessionCookie))")

        return (data, sessionCookie)
    }

    /**
     * POST request to register a PublicKeyCredential
     *
     * @param origin - Base URL for the service
     * @param userAgent - User Agent for FIDO Server parsing
     * @param credential - PublicKeyCredential from Authenticator Response
     * @param liquidExt - Optional Liquid extension data
     * @return The response data
     */
    func postAssertionResult(
        origin: String,
        userAgent: String,
        credential: String,
        liquidExt: [String: Any]? = nil
    ) async throws -> Data {
        // Construct the URL
        let path = "https://\(origin)/assertion/response"
        Logger.debug("AssertionApi: POST \(path)")
        Logger.debug("AssertionApi: credential: \(credential)")
        if let liquidExt = liquidExt {
            Logger.debug("AssertionApi: Liquid extension: \(liquidExt)")
        }
        guard let url = URL(string: path) else {
            throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
        }

        // Parse the credential JSON string into a dictionary
        guard let credentialData = credential.data(using: .utf8),
              var payload = try? JSONSerialization.jsonObject(with: credentialData, options: []) as? [String: Any]
        else {
            throw NSError(domain: "Invalid Credential JSON", code: -1, userInfo: nil)
        }

        // Add Liquid extension data if provided
        if let liquidExt = liquidExt {
            payload["clientExtensionResults"] = ["liquid": liquidExt]
        }
        Logger.debug("AssertionApi: Full payload: \(payload)")

        // Serialize the payload into JSON
        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            throw NSError(domain: "Invalid JSON", code: -1, userInfo: nil)
        }
        Logger.debug("AssertionApi: Request body (raw): \(String(data: body, encoding: .utf8) ?? "nil")")

        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        // Perform the request
        let (data, _) = try await session.data(for: request)
        Logger.debug("AssertionApi: Response data: \(String(data: data, encoding: .utf8) ?? "nil")")

        return data
    }
}
