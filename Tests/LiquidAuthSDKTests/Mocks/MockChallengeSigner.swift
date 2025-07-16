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

class MockChallengeSigner: LiquidAuthChallengeSigner {
    var signatureResult = Data()
    var shouldThrowError = false
    var thrownError: Error = NSError(domain: "test", code: 1, userInfo: nil)

    // Track calls for verification
    var signChallengeCallCount = 0
    var lastChallengeData: Data?

    func signLiquidAuthChallenge(_ challengeData: Data) async throws -> Data {
        signChallengeCallCount += 1
        lastChallengeData = challengeData

        if shouldThrowError {
            throw thrownError
        }

        return signatureResult
    }

    // Test helpers
    func reset() {
        signChallengeCallCount = 0
        lastChallengeData = nil
        shouldThrowError = false
        signatureResult = Data()
    }
}
