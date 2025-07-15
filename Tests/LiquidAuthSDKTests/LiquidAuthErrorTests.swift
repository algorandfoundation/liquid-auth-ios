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
@testable import LiquidAuthSDK

final class LiquidAuthErrorTests: XCTestCase {
    
    func testInvalidURLError() {
        // Given
        let url = "invalid-url"
        let error = LiquidAuthError.invalidURL(url)
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertEqual(description, "Invalid URL: invalid-url")
    }
    
    func testInvalidJSONError() {
        // Given
        let context = "Failed to parse response"
        let error = LiquidAuthError.invalidJSON(context)
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertEqual(description, "Invalid JSON: Failed to parse response")
    }
    
    func testNetworkError() {
        // Given
        let underlyingError = URLError(.notConnectedToInternet)
        let error = LiquidAuthError.networkError(underlyingError)
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertTrue(description!.contains("Network error:"))
        XCTAssertTrue(description!.contains("NSURLErrorDomain error -1009"))
    }
    
    func testAuthenticationFailedError() {
        // Given
        let reason = "Invalid credentials"
        let error = LiquidAuthError.authenticationFailed(reason)
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertEqual(description, "Authentication failed: Invalid credentials")
    }
    
    func testSigningFailedError() {
        // Given
        let underlyingError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Signing failed"])
        let error = LiquidAuthError.signingFailed(underlyingError)
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertEqual(description, "Signing failed: Signing failed")
    }
    
    func testInvalidChallengeError() {
        // Given
        let error = LiquidAuthError.invalidChallenge
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertEqual(description, "Invalid challenge received")
    }
    
    func testMissingRequiredFieldError() {
        // Given
        let field = "requestId"
        let error = LiquidAuthError.missingRequiredField(field)
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertEqual(description, "Missing required field: requestId")
    }
    
    func testServerError() {
        // Given
        let message = "HTTP 500 Internal Server Error"
        let error = LiquidAuthError.serverError(message)
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertEqual(description, "Server error: HTTP 500 Internal Server Error")
    }
    
    func testUserCanceledError() {
        // Given
        let error = LiquidAuthError.userCanceled
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertEqual(description, "Operation was canceled by user")
    }
}
