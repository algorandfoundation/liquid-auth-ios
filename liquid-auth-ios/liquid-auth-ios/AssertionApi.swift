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
        guard let url = URL(string: path) else {
            throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
        }

        // Construct the payload
        var payload: [String: Any] = [:]
        if let liquidExt = liquidExt {
            payload["extensions"] = liquidExt
        }

        // Serialize the payload into JSON
        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            throw NSError(domain: "Invalid JSON", code: -1, userInfo: nil)
        }

        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        // Perform the request
        let (data, response) = try await session.data(for: request)

        // Ensure the response is an HTTPURLResponse
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "Invalid response", code: -1, userInfo: nil)
        }

        // Extract the session cookie
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: httpResponse.allHeaderFields as! [String: String], for: url)
        let sessionCookie = cookies.first(where: { $0.name == "connect.sid" })

        return (data, sessionCookie)
    }

    // /**
    //  * POST request to verify a PublicKeyCredential assertion
    //  *
    //  * @param origin - Base URL for the service
    //  * @param userAgent - User Agent for FIDO Server parsing
    //  * @param credential - PublicKeyCredential assertion as a JSON string
    //  * @param liquidExt - Optional Liquid extension data
    //  * @return The response data
    //  */
    // func postAssertionResult(
    //     origin: String,
    //     userAgent: String,
    //     credential: String,
    //     liquidExt: Bool
    // ) async throws -> Data {
    //     // Assuming HTTPS
    //     let path = "https://\(origin)/assertion/response"
    //     guard let url = URL(string: path) else {
    //         throw NSError(domain: "Invalid URL", code: -1, userInfo: nil)
    //     }

    //     // Parse the credential JSON string into a dictionary
    //     guard let credentialData = credential.data(using: .utf8),
    //           var payload = try? JSONSerialization.jsonObject(with: credentialData, options: []) as? [String: Any] else {
    //         throw NSError(domain: "Invalid Credential JSON", code: -1, userInfo: nil)
    //     }

    //     // Add Liquid extension data if provided
    //     if let liquidExt = liquidExt {
    //         payload["clientExtensionResults"] = ["liquid": liquidExt]
    //     }

    //     // Serialize the payload into JSON
    //     guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
    //         throw NSError(domain: "Invalid JSON", code: -1, userInfo: nil)
    //     }

    //     // Create the request
    //     var request = URLRequest(url: url)
    //     request.httpMethod = "POST"
    //     request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    //     request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    //     request.httpBody = body

    //     // Perform the request
    //     let (data, _) = try await session.data(for: request)

    //     return data
    // }

    // /**
    //  * POST request to verify a PublicKeyCredential assertion (overloaded)
    //  *
    //  * @param origin - Base URL for the service
    //  * @param userAgent - User Agent for FIDO Server parsing
    //  * @param credential - PublicKeyCredential object
    //  * @param liquidExt - Optional Liquid extension data
    //  * @return The response data
    //  */
    // func postAssertionResult(
    //     origin: String,
    //     userAgent: String,
    //     credential: String,
    //     liquidExt: [String: Any]? = nil
    // ) async throws -> Data {
    //     // Extract data from the PublicKeyCredential
    //     let rawId = credential.rawId.base64URLEncodedString()
    //     guard let response = credential.response as? AuthenticatorAssertionResponse else {
    //         throw NSError(domain: "Invalid Credential Response", code: -1, userInfo: nil)
    //     }

    //     // Construct the payload
    //     var payload: [String: Any] = [
    //         "id": rawId,
    //         "type": "public-key",
    //         "rawId": rawId,
    //         "response": [
    //             "clientDataJSON": response.clientDataJSON.base64URLEncodedString(),
    //             "authenticatorData": response.authenticatorData.base64URLEncodedString(),
    //             "signature": response.signature.base64URLEncodedString(),
    //             "userHandle": response.userHandle?.base64URLEncodedString() ?? NSNull()
    //         ]
    //     ]

    //     // Add Liquid extension data if provided
    //     if let liquidExt = liquidExt {
    //         payload["clientExtensionResults"] = ["liquid": liquidExt]
    //     }

    //     // Serialize the payload into JSON
    //     guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
    //         throw NSError(domain: "Invalid JSON", code: -1, userInfo: nil)
    //     }

    //     // Create the request
    //     var request = URLRequest(url: URL(string: "\(origin)/assertion/response")!)
    //     request.httpMethod = "POST"
    //     request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    //     request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    //     request.httpBody = body

    //     // Perform the request
    //     let (data, _) = try await session.data(for: request)

    //     return data
    // }
}
