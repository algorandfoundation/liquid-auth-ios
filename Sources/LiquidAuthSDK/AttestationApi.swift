import Foundation

#if canImport(UIKit)
import UIKit
#endif

internal class AttestationApi {
    private let session: URLSession

    internal init(session: URLSession = .shared) {
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
    internal func postAttestationOptions(
        origin: String,
        userAgent: String,
        options: [String: Any]
    ) async throws -> (Data, HTTPCookie?) {
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
            guard 200...299 ~= httpResponse.statusCode else {
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
     * POST request to register a PublicKeyCredential
     *
     * @param origin - Base URL for the service
     * @param userAgent - User Agent for FIDO Server parsing
     * @param credential - PublicKeyCredential from Authenticator Response
     * @param liquidExt - Optional Liquid extension data
     * @param deviceInfo - Optional device information string
     * @return The response data
     */
    internal func postAttestationResult(
        origin: String,
        userAgent: String,
        credential: [String: Any],
        liquidExt: [String: Any]? = nil,
        deviceInfo: String? = nil
    ) async throws -> Data {
        // Construct the URL
        let path = "https://\(origin)/attestation/response"
        Logger.debug("AttestationApi: POST \(path)")
        Logger.debug("AttestationApi: Credential: \(credential)")
        if let liquidExt = liquidExt {
            Logger.debug("AttestationApi: Liquid extension: \(liquidExt)")
        }
        
        guard let url = URL(string: path) else {
            throw LiquidAuthError.invalidURL(path)
        }

        var payload = credential
        if let liquidExt = liquidExt {
            let clientExtensionResults: [String: Any] = ["liquid": liquidExt]
            payload["clientExtensionResults"] = clientExtensionResults
        }
        
        if let deviceInfo = deviceInfo {
            payload["device"] = deviceInfo
        } else {
            #if canImport(UIKit) && !targetEnvironment(macCatalyst)
            payload["device"] = UIDevice.current.model
            #else
            payload["device"] = "Unknown Device"
            #endif
        }

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
