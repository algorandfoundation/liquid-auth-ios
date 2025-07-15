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

import Base32
import CryptoKit
import Foundation
import SwiftCBOR

// MARK: - Utility

public enum Utility {
    /// Extracts the origin and request ID from a Liquid Auth URI
    ///
    /// - Parameter uri: The liquid:// URI to parse
    /// - Returns: A tuple containing the origin and requestId, or nil if parsing fails
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

    /// Decodes a Base64URL string into bytes
    ///
    /// - Parameter base64Url: The Base64URL encoded string
    /// - Returns: Decoded data, or nil if decoding fails
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

    /// Decodes a Base64URL string into a JSON representation of bytes
    ///
    /// - Parameter base64Url: The Base64URL encoded string
    /// - Returns: JSON string representation of bytes, or nil if decoding fails
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

    /// Attempts to decode a Base64URL string as CBOR and convert to readable format
    ///
    /// - Parameter message: The Base64URL encoded string
    /// - Returns: Pretty-printed JSON string if CBOR decoding succeeds, nil otherwise
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

    /// Encodes a P256 public key into EC2 COSE Key format
    ///
    /// - Parameter publicKey: The P256 public key data (64 or 65 bytes)
    /// - Returns: CBOR-encoded EC2 COSE Key as byte array
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

    /// Creates attested credential data for WebAuthn attestation
    ///
    /// - Parameters:
    ///   - aaguid: Authenticator attestation GUID
    ///   - credentialId: The credential identifier
    ///   - publicKey: The credential public key
    /// - Returns: Formatted attested credential data
    public static func getAttestedCredentialData(aaguid: UUID, credentialId: Data, publicKey: Data) -> Data {
        // Encode the public key into CBOR format
        let cborPublicKey = encodePKToEC2COSEKey(publicKey)
        let credentialIdLengthData = UInt16(credentialId.count).toDataBigEndian()
        let attestedCredentialData = aaguid.toData() + credentialIdLengthData + credentialId + cborPublicKey
        return attestedCredentialData
    }

    /// Computes SHA-256 hash of the input data
    ///
    /// - Parameter input: Data to hash
    /// - Returns: SHA-256 hash as Data
    public static func hashSHA256(_ input: Data) -> Data {
        Data(SHA256.hash(data: input))
    }
}

public extension UInt8 {
    /// Converts UInt8 to Data
    ///
    /// - Returns: Data containing the byte value
    func toData() -> Data {
        Data([self])
    }
}

public extension UInt16 {
    /// Converts UInt16 to Data in big-endian format
    ///
    /// - Returns: Data containing the 16-bit value in big-endian byte order
    func toDataBigEndian() -> Data {
        var value = bigEndian
        return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
    }
}

public extension UInt32 {
    /// Converts UInt32 to Data in big-endian format
    ///
    /// - Returns: Data containing the 32-bit value in big-endian byte order
    func toDataBigEndian() -> Data {
        var value = bigEndian
        return Data(bytes: &value, count: MemoryLayout.size(ofValue: value))
    }
}

public extension UUID {
    /// Converts UUID to Data
    ///
    /// - Returns: Data containing the UUID bytes
    func toData() -> Data {
        var uuid = uuid
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

public extension CBOR {
    /// Converts CBOR object to Swift native types
    ///
    /// - Returns: Swift object (Dictionary, Array, String, Number, etc.) or nil if conversion fails
    func asSwiftObject() -> Any? {
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

    /// Converts CBOR object to String representation for use as dictionary key
    ///
    /// - Returns: String representation if the CBOR object is a string or number, nil otherwise
    func asStringOrNumber() -> String? {
        switch self {
        case let .utf8String(str): str
        case let .unsignedInt(n): String(n)
        case let .negativeInt(n): String(-1 - Int64(n))
        default: nil
        }
    }
}

// MARK: - Base64URL Extensions

public extension Data {
    /// Encode Data to Base64URL string
    ///
    /// - Returns: Base64URL encoded string (URL-safe, no padding)
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decode Base64URL string to Data
    ///
    /// - Parameter string: Base64URL encoded string
    init?(base64URLEncoded string: String) {
        let base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddedBase64 = base64 + String(repeating: "=", count: (4 - base64.count % 4) % 4)
        self.init(base64Encoded: paddedBase64)
    }
}
