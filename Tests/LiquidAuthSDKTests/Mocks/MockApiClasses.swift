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
@testable import LiquidAuthSDK

// Mock for testing LiquidAuthImplementation without network calls
class MockAttestationApi: AttestationApi {
    var shouldSucceed = true
    var mockResponseData: Data?
    var mockCookie: HTTPCookie?
    
    override func postAttestationOptions(
        origin: String,
        userAgent: String,
        options: [String: Any]
    ) async throws -> (Data, HTTPCookie?) {
        if !shouldSucceed {
            throw LiquidAuthError.networkError(URLError(.timedOut))
        }
        
        let response: [String: Any] = [
            "challenge": "dGVzdC1jaGFsbGVuZ2U",
            "rp": ["id": origin],
            "user": [
                "id": "dGVzdC11c2Vy",
                "name": "test@example.com",
                "displayName": "Test User"
            ]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: response)
        return (data, mockCookie)
    }
    
    override func postAttestationResult(
        origin: String,
        userAgent: String,
        credential: [String: Any],
        liquidExt: [String: Any]?,
        device: String
    ) async throws -> Data {
        if !shouldSucceed {
            throw LiquidAuthError.serverError("Registration failed")
        }
        
        return mockResponseData ?? "{ \"success\": true }".data(using: .utf8)!
    }
}

class MockAssertionApi: AssertionApi {
    var shouldSucceed = true
    var mockResponseData: Data?
    var mockCookie: HTTPCookie?
    
    override func postAssertionOptions(
        origin: String,
        userAgent: String,
        credentialId: String,
        liquidExt: Bool?
    ) async throws -> (Data, HTTPCookie?) {
        if !shouldSucceed {
            throw LiquidAuthError.networkError(URLError(.timedOut))
        }
        
        let response: [String: Any] = [
            "challenge": "dGVzdC1jaGFsbGVuZ2U",
            "rpId": origin,
            "allowCredentials": [
                [
                    "id": credentialId,
                    "type": "public-key"
                ]
            ]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: response)
        return (data, mockCookie)
    }
    
    override func postAssertionResult(
        origin: String,
        userAgent: String,
        credential: String,
        liquidExt: [String: Any]?
    ) async throws -> Data {
        if !shouldSucceed {
            throw LiquidAuthError.serverError("Authentication failed")
        }
        
        return mockResponseData ?? "{ \"verified\": true }".data(using: .utf8)!
    }
}
