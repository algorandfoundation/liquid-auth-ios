import Foundation

public enum LogLevel: Int {
    case error = 0
    case info = 1
    case debug = 2
}

public class Logger {
    public static var currentLevel: LogLevel = .info

    public static func error(_ message: String) {
        if currentLevel.rawValue >= LogLevel.error.rawValue {
            print("❌ [ERROR] \(message)")
        }
    }

    public static func info(_ message: String) {
        if currentLevel.rawValue >= LogLevel.info.rawValue {
            print("ℹ️ [INFO] \(message)")
        }
    }

    public static func debug(_ message: String) {
        if currentLevel.rawValue >= LogLevel.debug.rawValue {
            print("🐞 [DEBUG] \(message)")
        }
    }
}
