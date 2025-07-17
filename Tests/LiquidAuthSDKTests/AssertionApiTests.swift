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
import XCTest
@testable import LiquidAuthSDK

// MARK: - AssertionApiTests

final class AssertionApiTests: XCTestCase {
    var assertionApi: AssertionApi!
    var mockSession: MockURLSession!

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        assertionApi = AssertionApi(session: mockSession)
    }

    override func tearDown() {
        assertionApi = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - postAssertionOptions Tests

    func testPostAssertionOptionsSuccess() async throws {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let credentialId = "test-credential-id"
        let liquidExt = true

        let responseData = """
        {
            "challenge": "dGVzdC1jaGFsbGVuZ2U",
            "allowCredentials": [
                {
                    "id": "test-credential-id",
                    "type": "public-key"
                }
            ],
            "rpId": "example.com"
        }
        """.data(using: .utf8)!

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com/assertion/request/test-credential-id")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Set-Cookie": "connect.sid=test-session-id; Path=/; HttpOnly"]
        )
        mockSession.mockData = responseData

        // When
        let (data, sessionCookie) = try await assertionApi.postAssertionOptions(
            origin: origin,
            userAgent: userAgent,
            credentialId: credentialId,
            liquidExt: liquidExt
        )

        // Then
        XCTAssertEqual(data, responseData)
        XCTAssertNotNil(sessionCookie)
        XCTAssertEqual(sessionCookie?.name, "connect.sid")
        XCTAssertEqual(sessionCookie?.value, "test-session-id")

        // Verify request was made correctly
        XCTAssertEqual(
            mockSession.lastRequest?.url?.absoluteString,
            "https://example.com/assertion/request/test-credential-id"
        )
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "User-Agent"), userAgent)

        // Verify request body
        if let body = mockSession.lastRequest?.httpBody,
           let jsonObject = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            XCTAssertEqual(jsonObject["extensions"] as? Bool, true)
        } else {
            XCTFail("Request body should contain valid JSON")
        }
    }

    func testPostAssertionOptionsWithoutLiquidExt() async throws {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let credentialId = "test-credential-id"

        let responseData = Data()
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com/assertion/request/test-credential-id")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        mockSession.mockData = responseData

        // When
        let (data, sessionCookie) = try await assertionApi.postAssertionOptions(
            origin: origin,
            userAgent: userAgent,
            credentialId: credentialId,
            liquidExt: nil
        )

        // Then
        XCTAssertEqual(data, responseData)
        XCTAssertNil(sessionCookie)

        // Verify request body is empty when liquidExt is nil
        if let body = mockSession.lastRequest?.httpBody,
           let jsonObject = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            XCTAssertTrue(jsonObject.isEmpty)
        } else {
            XCTFail("Request body should contain valid JSON")
        }
    }

    func testPostAssertionOptionsLiquidExtFalse() async throws {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let credentialId = "test-credential-id"
        let liquidExt = false

        let responseData = Data()
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com/assertion/request/test-credential-id")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        mockSession.mockData = responseData

        // When
        let (data, _) = try await assertionApi.postAssertionOptions(
            origin: origin,
            userAgent: userAgent,
            credentialId: credentialId,
            liquidExt: liquidExt
        )

        // Then
        XCTAssertEqual(data, responseData)

        // Verify request body contains extensions: false
        if let body = mockSession.lastRequest?.httpBody,
           let jsonObject = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            XCTAssertEqual(jsonObject["extensions"] as? Bool, false)
        } else {
            XCTFail("Request body should contain valid JSON")
        }
    }

    func testPostAssertionOptionsInvalidURL() async {
        // Given
        let origin = ""
        let userAgent = "liquid-auth/1.0"
        let credentialId = "test-credential-id"

        // When & Then
        do {
            _ = try await assertionApi.postAssertionOptions(
                origin: origin,
                userAgent: userAgent,
                credentialId: credentialId
            )
            XCTFail("Should have thrown invalidURL error")
        } catch let error as LiquidAuthError {
            if case .invalidURL = error {
                // Expected
            } else {
                XCTFail("Expected invalidURL error, got \(error)")
            }
        } catch {
            XCTFail("Expected LiquidAuthError, got \(error)")
        }
    }

    func testPostAssertionOptionsServerError() async {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let credentialId = "test-credential-id"

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com/assertion/request/test-credential-id")!,
            statusCode: 404,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        mockSession.mockData = Data()

        // When & Then
        do {
            _ = try await assertionApi.postAssertionOptions(
                origin: origin,
                userAgent: userAgent,
                credentialId: credentialId
            )
            XCTFail("Should have thrown serverError")
        } catch let error as LiquidAuthError {
            if case let .serverError(message) = error {
                XCTAssertEqual(message, "HTTP 404")
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        } catch {
            XCTFail("Expected LiquidAuthError, got \(error)")
        }
    }

    func testPostAssertionOptionsNetworkError() async {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let credentialId = "test-credential-id"

        mockSession.mockError = URLError(.networkConnectionLost)

        // When & Then
        do {
            _ = try await assertionApi.postAssertionOptions(
                origin: origin,
                userAgent: userAgent,
                credentialId: credentialId
            )
            XCTFail("Should have thrown networkError")
        } catch let error as LiquidAuthError {
            if case .networkError = error {
                // Expected
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        } catch {
            XCTFail("Expected LiquidAuthError, got \(error)")
        }
    }

    func testPostAssertionOptionsBadServerResponse() async {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let credentialId = "test-credential-id"

        // Mock a URLResponse that's not HTTPURLResponse
        mockSession.mockResponse = URLResponse(
            url: URL(string: "https://example.com/assertion/request/test-credential-id")!,
            mimeType: "application/json",
            expectedContentLength: 0,
            textEncodingName: "utf-8"
        )
        mockSession.mockData = Data()

        // When & Then
        do {
            _ = try await assertionApi.postAssertionOptions(
                origin: origin,
                userAgent: userAgent,
                credentialId: credentialId
            )
            XCTFail("Should have thrown networkError")
        } catch let error as LiquidAuthError {
            if case let .networkError(urlError) = error {
                XCTAssertEqual((urlError as? URLError)?.code, .badServerResponse)
            } else {
                XCTFail("Expected networkError with badServerResponse, got \(error)")
            }
        } catch {
            XCTFail("Expected LiquidAuthError, got \(error)")
        }
    }

    // MARK: - postAssertionResult Tests

    func testPostAssertionResultSuccess() async throws {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let credential = """
        {
            "id": "test-credential-id",
            "type": "public-key",
            "rawId": "dGVzdC1jcmVkZW50aWFsLWlk",
            "response": {
                "clientDataJSON": "eyJ0eXBlIjoid2ViYXV0aG4uZ2V0In0",
                "authenticatorData": "SZYN5YgOjGh0NBcPZHZgW4_krrmihjLHmVzzuoMdl2NFAAAAAA",
                "signature": "MEUCIQDTGVxhrfRPK4LrwZRONdwYWmP0CUG2pUH8GnH"
            }
        }
        """
        let liquidExt: [String: String] = ["type": "algorand", "address": "test-address", "signature": "test-sig"]

        let responseData = """
        {
            "verified": true,
            "authenticationInfo": {
                "credentialID": "test-credential-id"
            }
        }
        """.data(using: .utf8)!

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com/assertion/response")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        mockSession.mockData = responseData

        // When
        let data = try await assertionApi.postAssertionResult(
            origin: origin,
            userAgent: userAgent,
            credential: credential,
            liquidExt: liquidExt
        )

        // Then
        XCTAssertEqual(data, responseData)

        // Verify request was made correctly
        XCTAssertEqual(mockSession.lastRequest?.url?.absoluteString, "https://example.com/assertion/response")
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "User-Agent"), userAgent)

        // Verify request body contains credential and liquid extension
        if let body = mockSession.lastRequest?.httpBody,
           let jsonObject = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            XCTAssertEqual(jsonObject["id"] as? String, "test-credential-id")
            XCTAssertEqual(jsonObject["type"] as? String, "public-key")

            if let clientExtensionResults = jsonObject["clientExtensionResults"] as? [String: Any],
               let liquid = clientExtensionResults["liquid"] as? [String: Any] {
                XCTAssertEqual(liquid["type"] as? String, "algorand")
                XCTAssertEqual(liquid["address"] as? String, "test-address")
                XCTAssertEqual(liquid["signature"] as? String, "test-sig")
            } else {
                XCTFail("Request body should contain clientExtensionResults.liquid")
            }
        } else {
            XCTFail("Request body should contain valid JSON")
        }
    }

    func testPostAssertionResultWithoutLiquidExt() async throws {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let credential = """
        {
            "id": "test-credential-id",
            "type": "public-key"
        }
        """

        let responseData = Data()
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com/assertion/response")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        mockSession.mockData = responseData

        // When
        let data = try await assertionApi.postAssertionResult(
            origin: origin,
            userAgent: userAgent,
            credential: credential,
            liquidExt: nil
        )

        // Then
        XCTAssertEqual(data, responseData)

        // Verify request body doesn't contain clientExtensionResults
        if let body = mockSession.lastRequest?.httpBody,
           let jsonObject = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            XCTAssertEqual(jsonObject["id"] as? String, "test-credential-id")
            XCTAssertNil(jsonObject["clientExtensionResults"])
        } else {
            XCTFail("Request body should contain valid JSON")
        }
    }

    func testPostAssertionResultInvalidURL() async {
        // Given
        let origin = ""
        let userAgent = "liquid-auth/1.0"
        let credential = "{\"id\": \"test\"}"

        // When & Then
        do {
            _ = try await assertionApi.postAssertionResult(
                origin: origin,
                userAgent: userAgent,
                credential: credential
            )
            XCTFail("Should have thrown invalidURL error")
        } catch let error as LiquidAuthError {
            if case .invalidURL = error {
                // Expected
            } else {
                XCTFail("Expected invalidURL error, got \(error)")
            }
        } catch {
            XCTFail("Expected LiquidAuthError, got \(error)")
        }
    }

    func testPostAssertionResultInvalidCredentialJSON() async {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let credential = "invalid-json-string"

        // When & Then
        do {
            _ = try await assertionApi.postAssertionResult(
                origin: origin,
                userAgent: userAgent,
                credential: credential
            )
            XCTFail("Should have thrown invalidJSON error")
        } catch let error as LiquidAuthError {
            if case let .invalidJSON(message) = error {
                XCTAssertEqual(message, "Invalid credential JSON")
            } else {
                XCTFail("Expected invalidJSON error, got \(error)")
            }
        } catch {
            XCTFail("Expected LiquidAuthError, got \(error)")
        }
    }

    func testPostAssertionResultNetworkError() async {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let credential = "{\"id\": \"test\"}"

        mockSession.mockError = URLError(.cannotConnectToHost)

        // When & Then
        do {
            _ = try await assertionApi.postAssertionResult(
                origin: origin,
                userAgent: userAgent,
                credential: credential
            )
            XCTFail("Should have thrown networkError")
        } catch let error as LiquidAuthError {
            if case .networkError = error {
                // Expected
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        } catch {
            XCTFail("Expected LiquidAuthError, got \(error)")
        }
    }

    // MARK: - Edge Cases

    func testPostAssertionOptionsWithSpecialCharactersInCredentialId() async throws {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let credentialId = "test+credential/id=with+special-chars"

        let responseData = Data()
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com/assertion/request/test+credential/id=with+special-chars")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        mockSession.mockData = responseData

        // When
        let (data, _) = try await assertionApi.postAssertionOptions(
            origin: origin,
            userAgent: userAgent,
            credentialId: credentialId
        )

        // Then
        XCTAssertEqual(data, responseData)
        XCTAssertTrue(mockSession.lastRequest?.url?.absoluteString
            .contains("test+credential/id=with+special-chars") == true)
    }

    func testPostAssertionResultEmptyCredential() async {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let credential = "{}"

        let responseData = Data()
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com/assertion/response")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        mockSession.mockData = responseData

        // When & Then - Should not throw error for empty but valid JSON
        do {
            let data = try await assertionApi.postAssertionResult(
                origin: origin,
                userAgent: userAgent,
                credential: credential
            )
            XCTAssertEqual(data, responseData)
        } catch {
            XCTFail("Should not throw error for empty but valid JSON, got \(error)")
        }
    }
}
