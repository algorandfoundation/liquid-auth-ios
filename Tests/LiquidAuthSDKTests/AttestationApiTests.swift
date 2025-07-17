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

// MARK: - AttestationApiTests

final class AttestationApiTests: XCTestCase {
    var attestationApi: AttestationApi!
    var mockSession: MockURLSession!

    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        attestationApi = AttestationApi(session: mockSession)
    }

    override func tearDown() {
        attestationApi = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - postAttestationOptions Tests

    func testPostAttestationOptionsSuccess() async throws {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let options = ["username": "test@example.com", "displayName": "Test User"]

        let responseData = """
        {
            "challenge": "dGVzdC1jaGFsbGVuZ2U",
            "rp": {
                "id": "example.com",
                "name": "Example Corp"
            },
            "user": {
                "id": "dGVzdC11c2VyLWlk",
                "name": "test@example.com",
                "displayName": "Test User"
            }
        }
        """.data(using: .utf8)!

        let cookie = HTTPCookie(properties: [
            .domain: "example.com",
            .path: "/",
            .name: "connect.sid",
            .value: "test-session-id",
        ])!

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com/attestation/request")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Set-Cookie": "connect.sid=test-session-id; Path=/; HttpOnly"]
        )
        mockSession.mockData = responseData

        // When
        let (data, sessionCookie) = try await attestationApi.postAttestationOptions(
            origin: origin,
            userAgent: userAgent,
            options: options
        )

        // Then
        XCTAssertEqual(data, responseData)
        XCTAssertNotNil(sessionCookie)
        XCTAssertEqual(sessionCookie?.name, "connect.sid")
        XCTAssertEqual(sessionCookie?.value, "test-session-id")

        // Verify request was made correctly
        XCTAssertEqual(mockSession.lastRequest?.url?.absoluteString, "https://example.com/attestation/request")
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "User-Agent"), userAgent)

        // Verify request body
        if let body = mockSession.lastRequest?.httpBody,
           let jsonObject = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            XCTAssertEqual(jsonObject["username"] as? String, "test@example.com")
            XCTAssertEqual(jsonObject["displayName"] as? String, "Test User")
        } else {
            XCTFail("Request body should contain valid JSON")
        }
    }

    func testPostAttestationOptionsInvalidURL() async {
        // Given
        let origin = ""
        let userAgent = "liquid-auth/1.0"
        let options = ["username": "test@example.com"]

        // When & Then
        do {
            _ = try await attestationApi.postAttestationOptions(
                origin: origin,
                userAgent: userAgent,
                options: options
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

    func testPostAttestationOptionsServerError() async {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let options = ["username": "test@example.com"]

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com/attestation/request")!,
            statusCode: 500,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        mockSession.mockData = Data()

        // When & Then
        do {
            _ = try await attestationApi.postAttestationOptions(
                origin: origin,
                userAgent: userAgent,
                options: options
            )
            XCTFail("Should have thrown serverError")
        } catch let error as LiquidAuthError {
            if case let .serverError(message) = error {
                XCTAssertEqual(message, "HTTP 500")
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        } catch {
            XCTFail("Expected LiquidAuthError, got \(error)")
        }
    }

    func testPostAttestationOptionsNetworkError() async {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let options = ["username": "test@example.com"]

        mockSession.mockError = URLError(.notConnectedToInternet)

        // When & Then
        do {
            _ = try await attestationApi.postAttestationOptions(
                origin: origin,
                userAgent: userAgent,
                options: options
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

    func testPostAttestationOptionsBadServerResponse() async {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let options = ["username": "test@example.com"]

        // Mock a URLResponse that's not HTTPURLResponse
        mockSession.mockResponse = URLResponse(
            url: URL(string: "https://example.com/attestation/request")!,
            mimeType: "application/json",
            expectedContentLength: 0,
            textEncodingName: "utf-8"
        )
        mockSession.mockData = Data()

        // When & Then
        do {
            _ = try await attestationApi.postAttestationOptions(
                origin: origin,
                userAgent: userAgent,
                options: options
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

    // MARK: - postAttestationResult Tests

    func testPostAttestationResultSuccess() async throws {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let credential: [String: Any] = [
            "id": "test-credential-id",
            "type": "public-key",
            "response": [
                "clientDataJSON": "eyJ0eXBlIjoid2ViYXV0aG4uY3JlYXRlIn0",
                "attestationObject": "o2NmbXRkbm9uZWdhdHRTdG10oGhhdXRoRGF0YVikSZYN5YgOjGh0NBcPZHZgW4_krrmihjLHmVzzuoMdl2NFAAAAAA",
            ],
        ]
        let liquidExt = ["type": "algorand", "address": "test-address"]
        let device = "iPhone"

        let responseData = """
        {
            "verified": true,
            "registrationInfo": {
                "credentialID": "test-credential-id"
            }
        }
        """.data(using: .utf8)!

        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com/attestation/response")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        mockSession.mockData = responseData

        // When
        let data = try await attestationApi.postAttestationResult(
            origin: origin,
            userAgent: userAgent,
            credential: credential,
            liquidExt: liquidExt,
            device: device
        )

        // Then
        XCTAssertEqual(data, responseData)

        // Verify request was made correctly
        XCTAssertEqual(mockSession.lastRequest?.url?.absoluteString, "https://example.com/attestation/response")
        XCTAssertEqual(mockSession.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(mockSession.lastRequest?.value(forHTTPHeaderField: "User-Agent"), userAgent)

        // Verify request body contains credential, liquid extension, and device
        if let body = mockSession.lastRequest?.httpBody,
           let jsonObject = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            XCTAssertEqual(jsonObject["id"] as? String, "test-credential-id")
            XCTAssertEqual(jsonObject["type"] as? String, "public-key")
            XCTAssertEqual(jsonObject["device"] as? String, "iPhone")

            if let clientExtensionResults = jsonObject["clientExtensionResults"] as? [String: Any],
               let liquid = clientExtensionResults["liquid"] as? [String: Any] {
                XCTAssertEqual(liquid["type"] as? String, "algorand")
                XCTAssertEqual(liquid["address"] as? String, "test-address")
            } else {
                XCTFail("Request body should contain clientExtensionResults.liquid")
            }
        } else {
            XCTFail("Request body should contain valid JSON")
        }
    }

    func testPostAttestationResultWithoutLiquidExt() async throws {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let credential: [String: String] = ["id": "test-credential-id", "type": "public-key"]
        let device = "iPhone"

        let responseData = Data()
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://example.com/attestation/response")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )
        mockSession.mockData = responseData

        // When
        let data = try await attestationApi.postAttestationResult(
            origin: origin,
            userAgent: userAgent,
            credential: credential,
            liquidExt: nil,
            device: device
        )

        // Then
        XCTAssertEqual(data, responseData)

        // Verify request body doesn't contain clientExtensionResults
        if let body = mockSession.lastRequest?.httpBody,
           let jsonObject = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            XCTAssertEqual(jsonObject["device"] as? String, "iPhone")
            XCTAssertNil(jsonObject["clientExtensionResults"])
        } else {
            XCTFail("Request body should contain valid JSON")
        }
    }

    func testPostAttestationResultInvalidURL() async {
        // Given
        let origin = ""
        let userAgent = "liquid-auth/1.0"
        let credential: [String: String] = ["id": "test"]
        let device = "iPhone"

        // When & Then
        do {
            _ = try await attestationApi.postAttestationResult(
                origin: origin,
                userAgent: userAgent,
                credential: credential,
                device: device
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

    func testPostAttestationResultNetworkError() async {
        // Given
        let origin = "example.com"
        let userAgent = "liquid-auth/1.0"
        let credential: [String: String] = ["id": "test"]
        let device = "iPhone"

        mockSession.mockError = URLError(.timedOut)

        // When & Then
        do {
            _ = try await attestationApi.postAttestationResult(
                origin: origin,
                userAgent: userAgent,
                credential: credential,
                device: device
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
}


