import Base32
import CryptoKit
import Foundation
import SwiftCBOR

public enum Utility {
    /// Extracts the origin and request ID from a Liquid Auth URI.
    public static func extractOriginAndRequestId(from uri: String) -> (origin: String, requestId: String)? {
        guard let url = URL(string: uri),
              url.scheme == "liquid",
              let host = url.host,
              let queryItems = URLComponents(string: uri)?.queryItems,
              let requestId = queryItems.first(where: { $0.name == "requestId" })?.value
        else {
            return nil
        }
        return (origin: host, requestId: requestId)
    }

    /// Constructs a user agent string based on the app and device information.
    public static func getUserAgent() -> String {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "UnknownApp"
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "UnknownVersion"
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        
        return "\(appName)/\(appVersion) (\(systemVersion))"
    }
    
    /// Constructs a user agent string with custom device information.
    public static func getUserAgent(deviceModel: String, systemName: String, systemVersion: String) -> String {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "UnknownApp"
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "UnknownVersion"
        
        return "\(appName)/\(appVersion) (\(deviceModel); \(systemName) \(systemVersion))"
    }

    public static func sha512_256(data: Data) -> Data {
        Data(SHA512_256().hash([UInt8](data)))
    }

    /// Encode an Ed25519 public key into an Algorand Base32 address with the checksum.
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

    /// Decodes a Base64Url string into bytes.
    public static func decodeBase64Url(_ base64Url: String) -> Data? {
        // Replace Base64Url characters with Base64 equivalents
        var base64 = base64Url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if necessary
        let paddingLength = 4 - (base64.count % 4)
        if paddingLength < 4 {
            base64.append(String(repeating: "=", count: paddingLength))
        }

        // Decode the Base64 string
        return Data(base64Encoded: base64)
    }

    /// Decodes a Base64Url string into a JSON representation of bytes.
    public static func decodeBase64UrlToJSON(_ base64Url: String) -> String? {
        // Decode the Base64Url string into Data
        guard let decodedData = decodeBase64Url(base64Url) else {
            return nil
        }

        // Convert Data to [UInt8]
        let decodedBytes = [UInt8](decodedData)

        // Create a dictionary where each byte is represented as a key-value pair
        let byteDictionary = decodedBytes.enumerated().reduce(into: [String: UInt8]()) { dict, pair in
            dict["\(pair.offset)"] = pair.element
        }

        // Convert the dictionary to a JSON string
        if let jsonData = try? JSONSerialization.data(withJSONObject: byteDictionary, options: [.prettyPrinted]),
           let jsonString = String(data: jsonData, encoding: .utf8)
        {
            return jsonString
        }

        return nil
    }

    public static func decodeBase64UrlCBORIfPossible(_ message: String) -> String? {
        // 1. Convert Base64URL to Data
        var base64 = message
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - base64.count % 4
        if padding < 4 {
            base64 += String(repeating: "=", count: padding)
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        // 2. Try to decode as CBOR
        do {
            let cbor = try CBOR.decode([UInt8](data))
            // Try to pretty-print as JSON if possible
            if let dict = cbor?.asSwiftObject() {
                let jsonData = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
                return String(data: jsonData, encoding: .utf8)
            }
            return String(describing: cbor)
        } catch {
            return nil
        }
    }

    public static func encodePKToEC2COSEKey(_ publicKey: Data) -> [UInt8] {
        var adjustedPublicKey = publicKey

        // Check if the public key is 64 bytes long
        if publicKey.count == 64 {
            // Prepend the 0x04 byte to indicate an uncompressed public key
            adjustedPublicKey = Data([0x04]) + publicKey
        }

        // Ensure the public key is in uncompressed format and 65 bytes long
        guard adjustedPublicKey.count == 65, adjustedPublicKey[0] == 4 else {
            fatalError("Public key must be in uncompressed format and 65 bytes long.")
        }

        // Extract x and y coordinates
        let x = adjustedPublicKey[1 ..< 33]
        let y = adjustedPublicKey[33 ..< 65]

        // Construct the EC2 COSE Key map
        let ec2COSEKey: [Int: Any] = [
            1: 2, // kty: EC2 key type
            3: -7, // alg: ES256 signature algorithm
            -1: 1, // crv: P-256 curve
            -2: x, // x-coordinate
            -3: y, // y-coordinate
        ]

        // Encode the map into CBOR format
        do {
            let cbor = try CBOR.encodeMap(ec2COSEKey)
            return [UInt8](cbor)
        } catch {
            fatalError("Failed to encode EC2 COSE Key to CBOR: \(error)")
        }
    }

    public static func getAttestedCredentialData(aaguid: UUID, credentialId: Data, publicKey: Data) -> Data {
        // Encode the public key into CBOR format
        let cborPublicKey = encodePKToEC2COSEKey(publicKey)
        let credentialIdLengthData = UInt16(credentialId.count).toDataBigEndian()
        let attestedCredentialData = aaguid.toData() + credentialIdLengthData + credentialId + cborPublicKey
        return attestedCredentialData
    }

    public static func hashSHA256(_ input: Data) -> Data {
        return Data(SHA256.hash(data: input))
    }
}

extension UInt8 {
    public func toData() -> Data {
        return Data([self])
    }
}

extension UInt16 {
    public func toDataBigEndian() -> Data {
        var value = bigEndian
        return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
    }
}

extension UInt32 {
    public func toDataBigEndian() -> Data {
        var value = bigEndian
        return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
    }
}

extension UUID {
    public func toData() -> Data {
        var uuid = self.uuid
        return Data(bytes: &uuid, count: MemoryLayout.size(ofValue: uuid))
    }
}

private extension String {
    var isPrintable: Bool {
        // Checks if the string contains mostly printable characters
        let printable = filter { $0.isASCII && $0.isPrintable }
        return Double(printable.count) / Double(count) > 0.8
    }
}

private extension Character {
    var isPrintable: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.isASCII && scalar.value >= 32 && scalar.value < 127
    }
}

extension CBOR {
    public func asSwiftObject() -> Any? {
        switch self {
        case let .map(map):
            var dict = [String: Any]()
            for (k, v) in map {
                if let key = k.asStringOrNumber() {
                    dict[key] = v.asSwiftObject()
                }
            }
            return dict
        case let .array(arr):
            return arr.map { $0.asSwiftObject() }
        case let .utf8String(str):
            return str
        case let .unsignedInt(n):
            return n
        case let .negativeInt(n):
            return -1 - Int64(n)
        case let .boolean(b):
            return b
        case .null:
            return NSNull()
        case let .double(d):
            return d
        default:
            return String(describing: self)
        }
    }

    public func asStringOrNumber() -> String? {
        switch self {
        case let .utf8String(str): return str
        case let .unsignedInt(n): return String(n)
        case let .negativeInt(n): return String(-1 - Int64(n))
        default: return nil
        }
    }
}
