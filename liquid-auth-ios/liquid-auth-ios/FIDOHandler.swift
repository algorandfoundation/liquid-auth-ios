import Foundation
import SwiftCBOR

struct FIDOHandler {
    /// Decodes a FIDO URI and returns a `FIDORequest` instance.
    static func decodeFIDOURI(_ uri: String) -> FIDORequest? {
        guard uri.starts(with: "FIDO:/") else {
            Logger.error("Invalid FIDO URI.")
            return nil
        }

        // Extract the base10-encoded string
        let base10String = String(uri.dropFirst("FIDO:/".count))

        // Decode the base10 string into bytes
        guard let decodedBytes = decodeBase10String(base10String) else {
            Logger.error("Failed to decode base10 string.")
            return nil
        }

        // Decode the bytes into a CBOR object
        guard let cborObject = decodeCBOR(from: decodedBytes) else {
            Logger.error("Failed to decode CBOR.")
            return nil
        }

        // Ensure the CBOR object is a map
        guard case let CBOR.map(cborMap) = cborObject else {
            Logger.error("Invalid CBOR structure. Expected a map but got: \(cborObject)")
            return nil
        }

        // Extract relevant fields from the CBOR map
        guard let publicKeyBytes = cborMap[CBOR.unsignedInt(0)]?.byteStringValue,
              let qrSecret = cborMap[CBOR.unsignedInt(1)]?.byteStringValue,
              let tunnelServerCount = cborMap[CBOR.unsignedInt(2)]?.unsignedIntValue else {
            Logger.error("Missing required fields in CBOR.")
            return nil
        }

        // Optional fields
        let currentTime = cborMap[CBOR.unsignedInt(3)]?.unsignedIntValue
        let stateAssisted = cborMap[CBOR.unsignedInt(4)]?.booleanValue
        let hint = cborMap[CBOR.unsignedInt(5)]?.stringValue

        // Create and return a FIDORequest instance
        return FIDORequest(
            publicKey: publicKeyBytes,
            qrSecret: qrSecret,
            tunnelServerCount: tunnelServerCount,
            currentTime: currentTime,
            stateAssisted: stateAssisted,
            hint: hint
        )
    }

    /// Decodes a base10-encoded string into bytes.
    private static func decodeBase10String(_ input: String) -> [UInt8]? {
        var bytes: [UInt8] = []

        // Split the input into chunks of up to 17 digits
        let chunks = stride(from: 0, to: input.count, by: 17).map {
            let start = input.index(input.startIndex, offsetBy: $0)
            let end = input.index(start, offsetBy: min(17, input.count - $0))
            return String(input[start..<end])
        }

        for chunk in chunks {
            guard let number = UInt64(chunk) else {
                Logger.error("Invalid chunk: \(chunk)")
                return nil
            }

            // Determine the number of bytes in the chunk
            let byteCount: Int
            switch chunk.count {
            case 3: byteCount = 1
            case 5: byteCount = 2
            case 8: byteCount = 3
            case 10: byteCount = 4
            case 13: byteCount = 5
            case 15: byteCount = 6
            case 17: byteCount = 7
            default:
                Logger.error("Invalid chunk length: \(chunk.count)")
                return nil
            }

            // Convert the number to bytes and append the relevant bytes
            let chunkBytes = withUnsafeBytes(of: number.littleEndian) { Array($0) }
            bytes.append(contentsOf: chunkBytes.prefix(byteCount))
        }

        return bytes
    }

    /// Decodes a byte array into a CBOR object.
    private static func decodeCBOR(from bytes: [UInt8]) -> Any? {
        do {
            let cborObject = try CBORDecoder(input: bytes).decodeItem()
            return cborObject
        } catch {
            Logger.error("CBOR decoding failed: \(error)")
            return nil
        }
    }
}

private extension CBOR {
    var byteStringValue: [UInt8]? {
        if case let .byteString(value) = self {
            return value
        }
        return nil
    }

    var unsignedIntValue: UInt64? {
        if case let .unsignedInt(value) = self {
            return value
        }
        return nil
    }

    var booleanValue: Bool? {
        if case let .boolean(value) = self {
            return value
        }
        return nil
    }

    var stringValue: String? {
        if case let .utf8String(value) = self {
            return value
        }
        return nil
    }
}
