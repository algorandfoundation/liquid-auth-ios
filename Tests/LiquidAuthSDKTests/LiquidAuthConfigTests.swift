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

import WebRTC
import XCTest
@testable import LiquidAuthSDK

final class LiquidAuthConfigTests: XCTestCase {
    func testDefaultConfig() {
        // Given & When
        let config = LiquidAuthConfig.default

        // Then
        XCTAssertFalse(config.iceServers.isEmpty)
        XCTAssertNil(config.userAgent)
        XCTAssertEqual(config.timeout, 30.0)
        XCTAssertFalse(config.enableLogging)
    }

    func testCustomConfig() {
        // Given
        let customIceServers = [RTCIceServer(urlStrings: ["stun:example.com:3478"])]
        let customUserAgent = "TestAgent/1.0"
        let customTimeout: TimeInterval = 60.0
        let customLogging = true

        // When
        let config = LiquidAuthConfig(
            iceServers: customIceServers,
            userAgent: customUserAgent,
            timeout: customTimeout,
            enableLogging: customLogging
        )

        // Then
        XCTAssertEqual(config.iceServers.count, 1)
        XCTAssertEqual(config.iceServers.first?.urlStrings.first, "stun:example.com:3478")
        XCTAssertEqual(config.userAgent, customUserAgent)
        XCTAssertEqual(config.timeout, customTimeout)
        XCTAssertEqual(config.enableLogging, customLogging)
    }

    func testDefaultIceServers() {
        // Given & When
        let config = LiquidAuthConfig()

        // Then
        XCTAssertGreaterThanOrEqual(config.iceServers.count, 2)

        // Check for STUN servers
        let stunServers = config.iceServers.filter { server in
            server.urlStrings.contains { $0.hasPrefix("stun:") }
        }
        XCTAssertFalse(stunServers.isEmpty)

        // Check for TURN servers
        let turnServers = config.iceServers.filter { server in
            server.urlStrings.contains { $0.hasPrefix("turn:") || $0.hasPrefix("turns:") }
        }
        XCTAssertFalse(turnServers.isEmpty)
    }

    func testConfigWithNilIceServers() {
        // Given & When
        let config = LiquidAuthConfig(iceServers: nil)

        // Then
        XCTAssertFalse(config.iceServers.isEmpty) // Should use default servers
    }

    func testConfigWithEmptyIceServers() {
        // Given & When
        let config = LiquidAuthConfig(iceServers: [])

        // Then
        XCTAssertTrue(config.iceServers.isEmpty)
    }

    func testPartialConfig() {
        // Given & When
        let config = LiquidAuthConfig(
            userAgent: "CustomAgent/2.0",
            enableLogging: true
        )

        // Then
        XCTAssertFalse(config.iceServers.isEmpty) // Should use defaults
        XCTAssertEqual(config.userAgent, "CustomAgent/2.0")
        XCTAssertEqual(config.timeout, 30.0) // Should use default
        XCTAssertTrue(config.enableLogging)
    }
}
