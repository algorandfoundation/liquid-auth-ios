import Foundation

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
     */
    func postAttestationOptions(
        origin: String,
        userAgent: String,
        options: [String: Any],
        completion: @escaping (Result<(Data, HTTPCookie?), Error>) -> Void
    ) {
        // TODO: We are assuming the origin is an HTTPS URL. This should be validated.
        let path = "https://\(origin)/attestation/request"
        guard let url = URL(string: path) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
            return
        }

        // Convert options dictionary to JSON data
        guard let body = try? JSONSerialization.data(withJSONObject: options, options: []) else {
            completion(.failure(NSError(domain: "Invalid JSON", code: -1, userInfo: nil)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        // Perform the request
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  let data = data else {
                completion(.failure(NSError(domain: "Invalid response", code: -1, userInfo: nil)))
                return
            }

            // Extract cookies from the response
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: httpResponse.allHeaderFields as! [String: String], for: url)
            let sessionCookie = cookies.first(where: { $0.name == "session" })

            completion(.success((data, sessionCookie)))
        }

        task.resume()
    }

    /**
     * POST request to register a PublicKeyCredential
     *
     * @param origin - Base URL for the service
     * @param userAgent - User Agent for FIDO Server parsing
     * @param credential - PublicKeyCredential from Authenticator Response
     * @param liquidExt - Optional Liquid extension data
     */
    func postAttestationResult(
        origin: String,
        userAgent: String,
        credential: [String: Any],
        liquidExt: [String: Any]? = nil,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        let path = "\(origin)/attestation/response"
        guard let url = URL(string: path) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
            return
        }

        // Construct the payload
        var payload = credential
        if let liquidExt = liquidExt {
            payload["clientExtensionResults"] = ["liquid": liquidExt]
        }

        guard let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            completion(.failure(NSError(domain: "Invalid JSON", code: -1, userInfo: nil)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        // Perform the request
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "Invalid response", code: -1, userInfo: nil)))
                return
            }

            completion(.success(data))
        }

        task.resume()
    }
}