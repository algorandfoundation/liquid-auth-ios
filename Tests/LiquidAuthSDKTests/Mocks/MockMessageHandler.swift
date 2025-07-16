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

class MockMessageHandler: LiquidAuthMessageHandler {
    var shouldThrowError = false

    // Track calls for verification
    var handleMessageCallCount = 0
    var lastMessage: String?

    func handleMessage(_ message: String) async -> String? {
        handleMessageCallCount += 1
        lastMessage = message

        if shouldThrowError {
            // Simply return nil for error cases in handleMessage
            return nil
        }

        // Return a test response message or nil based on the test scenario
        return "response-" + message
    }

    // Test helpers
    func reset() {
        handleMessageCallCount = 0
        lastMessage = nil
        shouldThrowError = false
    }
}
