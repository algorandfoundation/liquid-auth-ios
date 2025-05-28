import Foundation

enum LogLevel: Int {
    case error = 0
    case info = 1
    case debug = 2
}

public class Logger {
    static var currentLevel: LogLevel = .info

    static func error(_ message: String) {
        if currentLevel.rawValue >= LogLevel.error.rawValue {
            print("❌ [ERROR] \(message)")
        }
    }

    static func info(_ message: String) {
        if currentLevel.rawValue >= LogLevel.info.rawValue {
            print("ℹ️ [INFO] \(message)")
        }
    }

    static func debug(_ message: String) {
        if currentLevel.rawValue >= LogLevel.debug.rawValue {
            print("🐞 [DEBUG] \(message)")
        }
    }
}
