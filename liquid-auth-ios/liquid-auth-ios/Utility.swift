import Foundation
import UIKit
import Base32

struct Utility {
    /// Extracts the origin and request ID from a Liquid Auth URI.
    static func extractOriginAndRequestId(from uri: String) -> (origin: String, requestId: String)? {
        guard let url = URL(string: uri),
              url.scheme == "liquid",
              let host = url.host,
              let queryItems = URLComponents(string: uri)?.queryItems,
              let requestId = queryItems.first(where: { $0.name == "requestId" })?.value else {
            print("Invalid Liquid Auth URI format.")
            return nil
        }
        return (origin: host, requestId: requestId)
    }

    /// Constructs a user agent string based on the app and device information.
    static func getUserAgent() -> String {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "UnknownApp"
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "UnknownVersion"
        let deviceModel = UIDevice.current.model
        let systemName = UIDevice.current.systemName
        let systemVersion = UIDevice.current.systemVersion

        return "\(appName)/\(appVersion) (\(deviceModel); \(systemName) \(systemVersion))"
    }
    public static func sha512_256(data: Data) -> Data {
        Data(SHA512_256().hash([UInt8](data)))
    }
    
    public static func encodeAddress(bytes: Data) throws -> String {
        let lenBytes = 32
        let checksumLenBytes = 4
        let expectedStrEncodedLen = 58

        // compute sha512/256 checksum
        let hash = sha512_256(data: bytes)
        let hashedAddr = hash[..<lenBytes] // Take the first 32 bytes

        // take the last 4 bytes of the hashed address, and append to original bytes
        let checksum = hashedAddr[(hashedAddr.count - checksumLenBytes)...]
        let checksumAddr = bytes + checksum

        // encodeToMsgPack addr+checksum as base32 and return. Strip padding.
        let res = Base32.base32Encode(checksumAddr).trimmingCharacters(in: ["="])
        if res.count != expectedStrEncodedLen {
         throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "unexpected address length \(res.count)"])
        }
        return res
    }
}
