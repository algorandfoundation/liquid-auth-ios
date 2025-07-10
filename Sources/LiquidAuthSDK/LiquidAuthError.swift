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
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidJSON(let context):
            return "Invalid JSON: \(context)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .signingFailed(let error):
            return "Signing failed: \(error.localizedDescription)"
        case .invalidChallenge:
            return "Invalid challenge received"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .userCanceled:
            return "Operation was canceled by user"
        }
    }
}
