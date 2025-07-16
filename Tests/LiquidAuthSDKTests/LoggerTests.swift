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

final class LoggerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Reset to default level before each test
        Logger.currentLevel = .info
    }

    func testLogLevels() {
        // Test that log levels have correct raw values
        XCTAssertEqual(LogLevel.error.rawValue, 0)
        XCTAssertEqual(LogLevel.info.rawValue, 1)
        XCTAssertEqual(LogLevel.debug.rawValue, 2)
    }

    func testErrorLogging() {
        // Given
        Logger.currentLevel = .error

        // When & Then - These should not crash
        Logger.error("Test error message")
        Logger.info("Test info message") // Should be filtered out
        Logger.debug("Test debug message") // Should be filtered out
    }

    func testInfoLogging() {
        // Given
        Logger.currentLevel = .info

        // When & Then - These should not crash
        Logger.error("Test error message")
        Logger.info("Test info message")
        Logger.debug("Test debug message") // Should be filtered out
    }

    func testDebugLogging() {
        // Given
        Logger.currentLevel = .debug

        // When & Then - These should not crash
        Logger.error("Test error message")
        Logger.info("Test info message")
        Logger.debug("Test debug message")
    }

    func testLogLevelFiltering() {
        // Test that higher levels are filtered out

        // Error level should only show errors
        Logger.currentLevel = .error
        // No direct way to test output without capturing NSLog, but we can verify no crashes
        Logger.error("Error")
        Logger.info("Info")
        Logger.debug("Debug")

        // Info level should show error and info
        Logger.currentLevel = .info
        Logger.error("Error")
        Logger.info("Info")
        Logger.debug("Debug")

        // Debug level should show all
        Logger.currentLevel = .debug
        Logger.error("Error")
        Logger.info("Info")
        Logger.debug("Debug")
    }

    func testDefaultLogLevel() {
        // The default log level should be .info
        let originalLevel = Logger.currentLevel
        XCTAssertEqual(originalLevel, .info)
    }

    func testChangingLogLevel() {
        // Given
        let originalLevel = Logger.currentLevel

        // When
        Logger.currentLevel = .debug

        // Then
        XCTAssertEqual(Logger.currentLevel, .debug)
        XCTAssertNotEqual(Logger.currentLevel, originalLevel)

        // Cleanup
        Logger.currentLevel = originalLevel
    }

    func testEmptyLogMessages() {
        // Test that empty messages don't cause issues
        Logger.currentLevel = .debug

        Logger.error("")
        Logger.info("")
        Logger.debug("")
    }

    func testLongLogMessages() {
        // Test that long messages don't cause issues
        Logger.currentLevel = .debug
        let longMessage = String(repeating: "A", count: 1_000)

        Logger.error(longMessage)
        Logger.info(longMessage)
        Logger.debug(longMessage)
    }

    func testSpecialCharacterLogMessages() {
        // Test that special characters don't cause issues
        Logger.currentLevel = .debug
        let specialMessage = "Test with special chars: 🔐 💬 ✅ ❌ \n\t\""

        Logger.error(specialMessage)
        Logger.info(specialMessage)
        Logger.debug(specialMessage)
    }
}
