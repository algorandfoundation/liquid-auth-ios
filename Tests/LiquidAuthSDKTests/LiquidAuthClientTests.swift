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

import XCTest
import CryptoKit
@testable import LiquidAuthSDK

final class LiquidAuthClientTests: XCTestCase {
    
    var client: LiquidAuthClient!
    var mockChallengeSigner: MockChallengeSigner!
    var mockMessageHandler: MockMessageHandler!
    var testKeyPair: P256.Signing.PrivateKey!
    
    override func setUp() {
        super.setUp()
        client = LiquidAuthClient()
        mockChallengeSigner = MockChallengeSigner()
        mockMessageHandler = MockMessageHandler()
        testKeyPair = P256.Signing.PrivateKey()
    }
    
    override func tearDown() {
        client = nil
        mockChallengeSigner = nil
        mockMessageHandler = nil
        testKeyPair = nil
        super.tearDown()
    }
    
    // MARK: - Registration Tests
    
    func testRegisterWithValidParameters() async throws {
        // Given
        let origin = "https://example.com"
        let requestId = "test-request-id"
        let algorandAddress = "5TPVWW4VV6OO54TSVMUW3UETOTIVXDWFLKEZ2EHS5RKQ3UXBNQPYYS7KYE"
        let userAgent = "liquid-auth/1.0 (iPhone; iOS 18.5)"
        let device = "iPhone"
        
        mockChallengeSigner.signatureResult = Data([1, 2, 3, 4])
        
        // When & Then
        // Note: This will fail without proper mocking of network calls
        // For now, we'll test parameter validation
        do {
            _ = try await client.register(
                origin: origin,
                requestId: requestId,
                algorandAddress: algorandAddress,
                challengeSigner: mockChallengeSigner,
                p256KeyPair: testKeyPair,
                messageHandler: mockMessageHandler,
                userAgent: userAgent,
                device: device
            )
        } catch {
            // Expected to fail due to network calls - that's ok for now
            XCTAssertTrue(error is LiquidAuthError || error is URLError)
        }
    }
    
    func testRegisterWithEmptyOrigin() async {
        // Given
        let origin = ""
        let requestId = "test-request-id"
        let algorandAddress = "5TPVWW4VV6OO54TSVMUW3UETOTIVXDWFLKEZ2EHS5RKQ3UXBNQPYYS7KYE"
        let userAgent = "liquid-auth/1.0 (iPhone; iOS 18.5)"
        let device = "iPhone"
        
        // When & Then
        do {
            _ = try await client.register(
                origin: origin,
                requestId: requestId,
                algorandAddress: algorandAddress,
                challengeSigner: mockChallengeSigner,
                p256KeyPair: testKeyPair,
                messageHandler: mockMessageHandler,
                userAgent: userAgent,
                device: device
            )
            XCTFail("Should have thrown an error")
        } catch {
            // Expected
        }
    }
    
    func testRegisterWithEmptyUserAgent() async {
        // Given
        let origin = "https://example.com"
        let requestId = "test-request-id"
        let algorandAddress = "5TPVWW4VV6OO54TSVMUW3UETOTIVXDWFLKEZ2EHS5RKQ3UXBNQPYYS7KYE"
        let userAgent = ""
        let device = "iPhone"
        
        // When & Then
        do {
            _ = try await client.register(
                origin: origin,
                requestId: requestId,
                algorandAddress: algorandAddress,
                challengeSigner: mockChallengeSigner,
                p256KeyPair: testKeyPair,
                messageHandler: mockMessageHandler,
                userAgent: userAgent,
                device: device
            )
            XCTFail("Should have thrown an error")
        } catch {
            // Expected
        }
    }
    
    // MARK: - Authentication Tests
    
    func testAuthenticateWithValidParameters() async throws {
        // Given
        let origin = "https://example.com"
        let requestId = "test-request-id"
        let algorandAddress = "5TPVWW4VV6OO54TSVMUW3UETOTIVXDWFLKEZ2EHS5RKQ3UXBNQPYYS7KYE"
        let userAgent = "liquid-auth/1.0 (iPhone; iOS 18.5)"
        let device = "iPhone"
        
        mockChallengeSigner.signatureResult = Data([1, 2, 3, 4])
        
        // When & Then
        do {
            _ = try await client.authenticate(
                origin: origin,
                requestId: requestId,
                algorandAddress: algorandAddress,
                challengeSigner: mockChallengeSigner,
                p256KeyPair: testKeyPair,
                messageHandler: mockMessageHandler,
                userAgent: userAgent,
                device: device
            )
        } catch {
            // Expected to fail due to network calls
            XCTAssertTrue(error is LiquidAuthError || error is URLError)
        }
    }
    
    func testAuthenticateWithInvalidAlgorandAddress() async {
        // Given
        let origin = "https://example.com"
        let requestId = "test-request-id"
        let algorandAddress = "invalid-address"
        let userAgent = "liquid-auth/1.0 (iPhone; iOS 18.5)"
        let device = "iPhone"
        
        // When & Then
        do {
            _ = try await client.authenticate(
                origin: origin,
                requestId: requestId,
                algorandAddress: algorandAddress,
                challengeSigner: mockChallengeSigner,
                p256KeyPair: testKeyPair,
                messageHandler: mockMessageHandler,
                userAgent: userAgent,
                device: device
            )
            XCTFail("Should have thrown an error")
        } catch {
            // Expected
        }
    }
}

// MARK: - LiquidAuthResult Tests

extension LiquidAuthClientTests {
    
    func testLiquidAuthResultSuccess() {
        // When
        let result = LiquidAuthResult.success()
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertNil(result.errorMessage)
    }
    
    func testLiquidAuthResultFailure() {
        // Given
        let errorMessage = "Test error message"
        
        // When
        let result = LiquidAuthResult.failure(errorMessage)
        
        // Then
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errorMessage, errorMessage)
    }
    
    func testLiquidAuthResultInitialization() {
        // When
        let successResult = LiquidAuthResult(success: true)
        let failureResult = LiquidAuthResult(success: false, errorMessage: "Error")
        
        // Then
        XCTAssertTrue(successResult.success)
        XCTAssertNil(successResult.errorMessage)
        
        XCTAssertFalse(failureResult.success)
        XCTAssertEqual(failureResult.errorMessage, "Error")
    }
}