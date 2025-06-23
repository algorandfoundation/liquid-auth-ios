import Foundation
import UIKit

class AttestationApi {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /**
     * POST request to retrieve PublicKeyCredentialCreationOptions
     *
     * @param origin - Base URL for the service
     * @param userAgent - User Agent for FIDO Server parsing
     * @param options - PublicKeyCredentialCreationOptions in JSON
     * @return A tuple containing the response data and an optional session cookie
     */
    func postAttestationOptions(
        origin: String,
        userAgent: String,
        options: [String: Any]
    ) async throws -> (Data, HTTPCookie?) {
        // Construct the URL
        let path = "https://\(origin)/attestation/request"
        Logger.debug("AttestationApi: POST \(path)")
        Logger.debug("AttestationApi: Request options: \(options)")
        guard let url = URL(string: path) else {
            throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
        }

        // Serialize the options into JSON
        guard let body = try? JSONSerialization.data(withJSONObject: options, options: []) else {
            throw NSError(domain: "Invalid JSON", code: -1, userInfo: nil)
        }

        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        Logger.debug("AttestationApi: Request body (raw): \(String(data: body, encoding: .utf8) ?? "nil")")

        // Perform the request
        let (data, response) = try await session.data(for: request)
        Logger.debug("AttestationApi: Response data: \(String(data: data, encoding: .utf8) ?? "nil")")

        // Ensure the response is an HTTPURLResponse
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid response", code: -1, userInfo: nil)
        }
        Logger.debug("AttestationApi: Response headers: \(httpResponse.allHeaderFields)")

        // Extract the session cookie
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: httpResponse.allHeaderFields as! [String: String], for: url)
        let sessionCookie = cookies.first(where: { $0.name == "connect.sid" })
        Logger.debug("AttestationApi: Session cookie: \(String(describing: sessionCookie))")

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
    func postAttestationResult(
        origin: String,
        userAgent: String,
        credential: [String: Any],
        liquidExt: [String: Any]? = nil
    ) async throws -> Data {
        // Construct the URL
        let path = "https://\(origin)/attestation/response"
        Logger.debug("AttestationApi: POST \(path)")
        Logger.debug("AttestationApi: Credential: \(credential)")
        if let liquidExt = liquidExt {
            Logger.debug("AttestationApi: Liquid extension: \(liquidExt)")
        }
        guard let url = URL(string: path) else {
            throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
        }

        // Construct the payload
        var payload = credential
        if let liquidExt = liquidExt {
            let clientExtensionResults: [String: Any] = ["liquid": liquidExt]
            payload["clientExtensionResults"] = clientExtensionResults
        }

        // Add device information
        payload["device"] = await UIDevice.current.model

        Logger.debug("AttestationApi: Full payload: \(payload)")

        // Serialize the payload into JSON
        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            throw NSError(domain: "Invalid JSON", code: -1, userInfo: nil)
        }

        Logger.debug("AttestationApi: Request body (raw): \(String(data: body, encoding: .utf8) ?? "nil")")

        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        // Perform the request
        let (data, _) = try await session.data(for: request)
        Logger.debug("AttestationApi: Response data: \(String(data: data, encoding: .utf8) ?? "nil")")

        return data
    }
}
