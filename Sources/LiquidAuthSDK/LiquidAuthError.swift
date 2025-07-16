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

public enum LiquidAuthError: Error, LocalizedError {
    case invalidURL(String)
    case invalidJSON(String)
    case networkError(Error)
    case authenticationFailed(String)
    case signingFailed(Error)
    case invalidChallenge
    case missingRequiredField(String)
    case serverError(String)
    case userCanceled

    public var errorDescription: String? {
        switch self {
        case let .invalidURL(url):
            "Invalid URL: \(url)"
        case let .invalidJSON(context):
            "Invalid JSON: \(context)"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case let .authenticationFailed(reason):
            "Authentication failed: \(reason)"
        case let .signingFailed(error):
            "Signing failed: \(error.localizedDescription)"
        case .invalidChallenge:
            "Invalid challenge received"
        case let .missingRequiredField(field):
            "Missing required field: \(field)"
        case let .serverError(message):
            "Server error: \(message)"
        case .userCanceled:
            "Operation was canceled by user"
        }
    }
}
