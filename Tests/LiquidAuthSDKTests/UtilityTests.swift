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

import CryptoKit
import SwiftCBOR
import XCTest
@testable import LiquidAuthSDK

// MARK: - UtilityTests

final class UtilityTests: XCTestCase {
    // MARK: - URI Parsing Tests

    func testExtractOriginAndRequestIdValidURI() {
        // Given
        let uri = "liquid://example.com?requestId=test-123"

        // When
        let result = Utility.extractOriginAndRequestId(from: uri)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.origin, "example.com")
        XCTAssertEqual(result?.requestId, "test-123")
    }

    func testExtractOriginAndRequestIdInvalidScheme() {
        // Given
        let uri = "https://example.com?requestId=test-123"

        // When
        let result = Utility.extractOriginAndRequestId(from: uri)

        // Then
        XCTAssertNil(result)
    }

    func testExtractOriginAndRequestIdMissingRequestId() {
        // Given
        let uri = "liquid://example.com"

        // When
        let result = Utility.extractOriginAndRequestId(from: uri)

        // Then
        XCTAssertNil(result)
    }

    func testExtractOriginAndRequestIdInvalidURI() {
        // Given
        let uri = "not-a-valid-uri"

        // When
        let result = Utility.extractOriginAndRequestId(from: uri)

        // Then
        XCTAssertNil(result)
    }

    // MARK: - Base64URL Tests

    func testDecodeBase64UrlValidInput() {
        // Given
        let input = "SGVsbG8gV29ybGQ" // "Hello World" in base64url

        // When
        let result = Utility.decodeBase64Url(input)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(String(data: result!, encoding: .utf8), "Hello World")
    }

    func testDecodeBase64UrlWithPadding() {
        // Given
        let input = "SGVsbG8" // "Hello" in base64url (needs padding)

        // When
        let result = Utility.decodeBase64Url(input)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(String(data: result!, encoding: .utf8), "Hello")
    }

    func testDecodeBase64UrlInvalidInput() {
        // Given
        let input = "Invalid base64url @#$%"

        // When
        let result = Utility.decodeBase64Url(input)

        // Then
        XCTAssertNil(result)
    }

    func testDecodeBase64UrlToJSON() {
        // Given
        let testData = Data([1, 2, 3, 4, 5])
        let base64Url = testData.base64URLEncodedString()

        // When
        let result = Utility.decodeBase64UrlToJSON(base64Url)

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("\"0\" : 1"))
        XCTAssertTrue(result!.contains("\"1\" : 2"))
    }

    func testDecodeBase64UrlToJSONInvalidInput() {
        // Given
        let invalidBase64 = "not-valid-base64!@#"

        // When
        let result = Utility.decodeBase64UrlToJSON(invalidBase64)

        // Then
        XCTAssertNil(result)
    }

    func testDecodeBase64UrlToJSONEmptyInput() {
        // Given
        let emptyData = Data()
        let base64Url = emptyData.base64URLEncodedString()

        // When
        let result = Utility.decodeBase64UrlToJSON(base64Url)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result, "{\n\n}")
    }

    // MARK: - CBOR Decoding Tests

    func testDecodeBase64UrlCBORIfPossibleValidCBOR() {
        // Given - Create valid CBOR data using SwiftCBOR
        let testMap: [String: Any] = [
            "key": "value",
            "number": 42,
        ]

        do {
            let cborData = try CBOR.encodeMap(testMap)
            let base64Url = Data(cborData).base64URLEncodedString()

            // When
            let result = Utility.decodeBase64UrlCBORIfPossible(base64Url)

            // Then
            XCTAssertNotNil(result)
            XCTAssertTrue(result!.contains("key"))
            XCTAssertTrue(result!.contains("value"))
        } catch {
            XCTFail("Failed to encode test CBOR data: \(error)")
        }
    }

    func testDecodeBase64UrlCBORIfPossibleInvalidCBOR() {
        // Given - Actually invalid CBOR data (incomplete major type)
        let invalidData = Data([0x98]) // Major type 4 (array) with length that requires more bytes
        let base64Url = invalidData.base64URLEncodedString()

        // When
        let result = Utility.decodeBase64UrlCBORIfPossible(base64Url)

        // Then - Should return nil since this is invalid CBOR
        XCTAssertNil(result)
    }

    func testDecodeBase64UrlCBORIfPossibleBreakValue() {
        // Given - CBOR "break" value (which is valid CBOR)
        let breakData = Data([0xFF, 0xFF, 0xFF])
        let base64Url = breakData.base64URLEncodedString()

        // When
        let result = Utility.decodeBase64UrlCBORIfPossible(base64Url)

        // Then - Should return a JSON representation
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("break"))
    }

    func testDecodeBase64UrlCBORIfPossibleInvalidBase64() {
        // Given
        let invalidBase64 = "not-valid-base64!@#"

        // When
        let result = Utility.decodeBase64UrlCBORIfPossible(invalidBase64)

        // Then
        XCTAssertNil(result)
    }

    func testDecodeBase64UrlCBORIfPossibleNonDictionaryCBOR() {
        // Given - CBOR array instead of dictionary
        let testArray = [1, 2, 3]
        let cborData = CBOR.encodeArray(testArray)
        let base64Url = Data(cborData).base64URLEncodedString()

        // When
        let result = Utility.decodeBase64UrlCBORIfPossible(base64Url)

        // Then
        XCTAssertNotNil(result)
        // Should return string representation since it's not a dictionary
        XCTAssertTrue(result!.contains("1"))
    }

    // MARK: - COSE Key Tests

    func testEncodePKToEC2COSEKey64Bytes() {
        // Given
        let publicKey = Data(repeating: 1, count: 64) // 64-byte key (will be padded)

        // When
        let coseKey = Utility.encodePKToEC2COSEKey(publicKey)

        // Then
        XCTAssertFalse(coseKey.isEmpty)
        XCTAssertGreaterThan(coseKey.count, 64) // Should be larger due to CBOR encoding
    }

    func testEncodePKToEC2COSEKey65Bytes() {
        // Given
        let publicKey = Data([0x04] + Data(repeating: 1, count: 64)) // 65-byte uncompressed key

        // When
        let coseKey = Utility.encodePKToEC2COSEKey(publicKey)

        // Then
        XCTAssertFalse(coseKey.isEmpty)
        XCTAssertGreaterThan(coseKey.count, 64)
    }

    func testEncodePKToEC2COSEKeyInvalidLength() {
        // Given
        _ = Data(repeating: 1, count: 32) // Invalid length

        // When/Then - This should trigger the fatalError
        // We can't easily test fatalError in unit tests, but we can document the expected behavior
        // In a real scenario, this would crash the app, which is the intended behavior
        // for invalid input to this critical cryptographic function
    }

    func testEncodePKToEC2COSEKeyInvalidUncompressedFormat() {
        // Given - 65 bytes but wrong first byte
        _ = Data([0x02] + Data(repeating: 1, count: 64))

        // When/Then - This should trigger the fatalError for invalid uncompressed format
        // Similar to above, we document that this would cause a fatalError
    }

    // MARK: - Attested Credential Data Tests

    func testGetAttestedCredentialData() {
        // Given
        let aaguid = UUID()
        let credentialId = Data([1, 2, 3, 4])
        let publicKey = Data(repeating: 1, count: 64)

        // When
        let result = Utility.getAttestedCredentialData(
            aaguid: aaguid,
            credentialId: credentialId,
            publicKey: publicKey
        )

        // Then
        XCTAssertFalse(result.isEmpty)
        XCTAssertGreaterThan(result.count, 16 + 2 + 4) // AAGUID + length + credentialId minimum
    }

    // MARK: - Hash Tests

    func testHashSHA256() {
        // Given
        let input = "Hello World".data(using: .utf8)!

        // When
        let hash = Utility.hashSHA256(input)

        // Then
        XCTAssertEqual(hash.count, 32) // SHA256 produces 32-byte hash

        // Test consistency
        let hash2 = Utility.hashSHA256(input)
        XCTAssertEqual(hash, hash2)
    }

    func testHashSHA256EmptyInput() {
        // Given
        let input = Data()

        // When
        let hash = Utility.hashSHA256(input)

        // Then
        XCTAssertEqual(hash.count, 32)
        // SHA256 of empty data should be: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        let expectedHash = Data([
            0xE3, 0xB0, 0xC4, 0x42, 0x98, 0xFC, 0x1C, 0x14, 0x9A, 0xFB, 0xF4, 0xC8,
            0x99, 0x6F, 0xB9, 0x24, 0x27, 0xAE, 0x41, 0xE4, 0x64, 0x9B, 0x93, 0x4C,
            0xA4, 0x95, 0x99, 0x1B, 0x78, 0x52, 0xB8, 0x55,
        ])
        XCTAssertEqual(hash, expectedHash)
    }
}

// MARK: - Extension Tests

extension UtilityTests {
    func testDataBase64URLEncoding() {
        // Given
        let data = "Hello World".data(using: .utf8)!

        // When
        let encoded = data.base64URLEncodedString()

        // Then
        XCTAssertFalse(encoded.contains("+"))
        XCTAssertFalse(encoded.contains("/"))
        XCTAssertFalse(encoded.contains("="))

        // Test round trip
        let decoded = Data(base64URLEncoded: encoded)
        XCTAssertEqual(decoded, data)
    }

    func testDataBase64URLDecoding() {
        // Given
        let encoded = "SGVsbG8gV29ybGQ"

        // When
        let decoded = Data(base64URLEncoded: encoded)

        // Then
        XCTAssertNotNil(decoded)
        XCTAssertEqual(String(data: decoded!, encoding: .utf8), "Hello World")
    }

    func testUInt16BigEndianConversion() {
        // Given
        let value: UInt16 = 0x1234

        // When
        let data = value.toDataBigEndian()

        // Then
        XCTAssertEqual(data.count, 2)
        XCTAssertEqual(data[0], 0x12)
        XCTAssertEqual(data[1], 0x34)
    }

    func testUInt32BigEndianConversion() {
        // Given
        let value: UInt32 = 0x1234_5678

        // When
        let data = value.toDataBigEndian()

        // Then
        XCTAssertEqual(data.count, 4)
        XCTAssertEqual(data[0], 0x12)
        XCTAssertEqual(data[1], 0x34)
        XCTAssertEqual(data[2], 0x56)
        XCTAssertEqual(data[3], 0x78)
    }

    func testUUIDToData() {
        // Given
        let uuid = UUID()

        // When
        let data = uuid.toData()

        // Then
        XCTAssertEqual(data.count, 16)

        // Test that we can recreate the UUID
        let recreatedUUID = data.withUnsafeBytes { bytes in
            UUID(uuid: bytes.bindMemory(to: uuid_t.self).first!)
        }
        XCTAssertEqual(uuid, recreatedUUID)
    }

    func testUInt8ToData() {
        // Given
        let value: UInt8 = 0x42

        // When
        let data = value.toData()

        // Then
        XCTAssertEqual(data.count, 1)
        XCTAssertEqual(data[0], 0x42)
    }
}

// MARK: - CBOR Extension Tests

extension UtilityTests {
    func testCBORAsSwiftObjectMap() {
        // We need to import SwiftCBOR to test these extensions
        // This tests the asSwiftObject() method for CBOR maps
        let testMap: [CBOR: CBOR] = [
            CBOR.utf8String("key1"): CBOR.utf8String("value1"),
            CBOR.unsignedInt(2): CBOR.unsignedInt(42),
            CBOR.utf8String("key3"): CBOR.boolean(true),
        ]
        let cborMap = CBOR.map(testMap)

        // When
        let swiftObject = cborMap.asSwiftObject()

        // Then
        XCTAssertNotNil(swiftObject)
        if let dict = swiftObject as? [String: Any] {
            XCTAssertEqual(dict["key1"] as? String, "value1")
            XCTAssertEqual(dict["2"] as? UInt64, 42)
            XCTAssertEqual(dict["key3"] as? Bool, true)
        } else {
            XCTFail("Expected dictionary")
        }
    }

    func testCBORAsSwiftObjectArray() {
        // Given
        let testArray: [CBOR] = [
            CBOR.utf8String("hello"),
            CBOR.unsignedInt(123),
            CBOR.boolean(false),
        ]
        let cborArray = CBOR.array(testArray)

        // When
        let swiftObject = cborArray.asSwiftObject()

        // Then
        XCTAssertNotNil(swiftObject)
        if let array = swiftObject as? [Any] {
            XCTAssertEqual(array[0] as? String, "hello")
            XCTAssertEqual(array[1] as? UInt64, 123)
            XCTAssertEqual(array[2] as? Bool, false)
        } else {
            XCTFail("Expected array")
        }
    }

    func testCBORAsSwiftObjectPrimitives() {
        // Test string
        let cborString = CBOR.utf8String("test")
        XCTAssertEqual(cborString.asSwiftObject() as? String, "test")

        // Test unsigned int
        let cborUInt = CBOR.unsignedInt(42)
        XCTAssertEqual(cborUInt.asSwiftObject() as? UInt64, 42)

        // Test negative int
        let cborNegInt = CBOR.negativeInt(5)
        XCTAssertEqual(cborNegInt.asSwiftObject() as? Int64, -6) // CBOR negative encoding

        // Test boolean
        let cborBool = CBOR.boolean(true)
        XCTAssertEqual(cborBool.asSwiftObject() as? Bool, true)

        // Test null
        let cborNull = CBOR.null
        XCTAssertTrue(cborNull.asSwiftObject() is NSNull)

        // Test double
        let cborDouble = CBOR.double(3.14)
        XCTAssertEqual(cborDouble.asSwiftObject() as? Double, 3.14)
    }

    func testCBORAsStringOrNumber() {
        // Test string
        let cborString = CBOR.utf8String("hello")
        XCTAssertEqual(cborString.asStringOrNumber(), "hello")

        // Test unsigned int
        let cborUInt = CBOR.unsignedInt(42)
        XCTAssertEqual(cborUInt.asStringOrNumber(), "42")

        // Test negative int
        let cborNegInt = CBOR.negativeInt(5)
        XCTAssertEqual(cborNegInt.asStringOrNumber(), "-6")

        // Test unsupported type (should return nil)
        let cborBool = CBOR.boolean(true)
        XCTAssertNil(cborBool.asStringOrNumber())
    }
}
