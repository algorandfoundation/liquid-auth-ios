import Foundation
import CryptoKit
import SwiftCBOR
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
        let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return nil
    }

    static func encodePKToEC2COSEKey(_ publicKey: Data) -> [UInt8] {
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
        let x = adjustedPublicKey[1..<33]
        let y = adjustedPublicKey[33..<65]

        // Construct the EC2 COSE Key map
        let ec2COSEKey: [Int: Any] = [
            1: 2,  // kty: EC2 key type
            3: -7, // alg: ES256 signature algorithm
            -1: 1, // crv: P-256 curve
            -2: x, // x-coordinate
            -3: y  // y-coordinate
        ]

        // Encode the map into CBOR format
        do {
            let cbor = try CBOR.encodeMap(ec2COSEKey)
            return [UInt8](cbor)
        } catch {
            fatalError("Failed to encode EC2 COSE Key to CBOR: \(error)")
        }
    }


    static func getAttestedCredentialData(aaguid: UUID, credentialId: Data, publicKey: Data) -> Data {
        // Encode the public key into CBOR format
        let cborPublicKey = encodePKToEC2COSEKey(publicKey)

        let credentialIdLengthData = UInt16(credentialId.count).toDataBigEndian()
        return aaguid.toData() + credentialIdLengthData + credentialId + cborPublicKey
    }

    static func hashSHA256(_ input: Data) -> Data {
        return Data(SHA256.hash(data: input))
    }

}

extension UInt8 {
    func toData() -> Data {
        return Data([self])
    }
}

extension UInt16 {
    func toDataBigEndian() -> Data {
        var value = self.bigEndian
        return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
    }
}

extension UInt32 {
    func toDataBigEndian() -> Data {
        var value = self.bigEndian
        return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
    }
}

extension UUID {
    func toData() -> Data {
        var uuid = self.uuid
        return Data(bytes: &uuid, count: MemoryLayout.size(ofValue: uuid))
    }
}
