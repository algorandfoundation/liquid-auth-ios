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

// MARK: - LogLevel

public enum LogLevel: Int {
    case error = 0
    case info = 1
    case debug = 2
}

// MARK: - Logger

public enum Logger {
    public static var currentLevel: LogLevel = .info

    /// Logs an error message
    ///
    /// - Parameter message: The error message to log
    public static func error(_ message: String) {
        if currentLevel.rawValue >= LogLevel.error.rawValue {
            NSLog("❌ [ERROR] %@", message)
        }
    }

    /// Logs an informational message
    ///
    /// - Parameter message: The info message to log
    public static func info(_ message: String) {
        if currentLevel.rawValue >= LogLevel.info.rawValue {
            NSLog("ℹ️ [INFO] %@", message)
        }
    }

    /// Logs a debug message
    ///
    /// - Parameter message: The debug message to log
    public static func debug(_ message: String) {
        if currentLevel.rawValue >= LogLevel.debug.rawValue {
            NSLog("🐞 [DEBUG] %@", message)
        }
    }
}
