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

import XCTest
@testable import LiquidAuthSDK

final class AuthenticatorDataTests: XCTestCase {
    // MARK: - Attestation Tests

    func testAttestationCreation() {
        // Given
        let rpIdHash = Data(repeating: 1, count: 32)
        let attestedCredData = Data([1, 2, 3, 4])

        // When
        let authData = AuthenticatorData.attestation(
            rpIdHash: rpIdHash,
            userPresent: true,
            userVerified: true,
            backupEligible: false,
            backupState: false,
            signCount: 0,
            attestedCredentialData: attestedCredData,
            extensions: nil
        )

        // Then
        let data = authData.toData()
        XCTAssertFalse(data.isEmpty)
        XCTAssertGreaterThanOrEqual(data.count, 37) // Minimum size for authenticator data
    }

    func testAttestationWithExtensions() {
        // Given
        let rpIdHash = Data(repeating: 1, count: 32)
        let attestedCredData = Data([1, 2, 3, 4])
        let extensions = Data([0x01, 0x02]) // Simple CBOR extensions

        // When
        let authData = AuthenticatorData.attestation(
            rpIdHash: rpIdHash,
            userPresent: true,
            userVerified: false,
            backupEligible: true,
            backupState: true,
            signCount: 42,
            attestedCredentialData: attestedCredData,
            extensions: extensions
        )

        // Then
        let data = authData.toData()
        XCTAssertFalse(data.isEmpty)
        XCTAssertGreaterThan(data.count, 37) // Should be larger due to extensions
    }

    func testAttestationFlags() {
        // Given
        let rpIdHash = Data(repeating: 1, count: 32)
        let attestedCredData = Data([1, 2, 3, 4])

        // Test different flag combinations
        struct FlagTestCase {
            let userPresent: Bool
            let userVerified: Bool
            let backupEligible: Bool
            let backupState: Bool
        }

        let testCases = [
            FlagTestCase(userPresent: true, userVerified: true, backupEligible: true, backupState: true),
            FlagTestCase(userPresent: true, userVerified: false, backupEligible: false, backupState: false),
            FlagTestCase(userPresent: false, userVerified: true, backupEligible: true, backupState: false),
            FlagTestCase(userPresent: false, userVerified: false, backupEligible: false, backupState: true),
        ]

        for testCase in testCases {
            // When
            let authData = AuthenticatorData.attestation(
                rpIdHash: rpIdHash,
                userPresent: testCase.userPresent,
                userVerified: testCase.userVerified,
                backupEligible: testCase.backupEligible,
                backupState: testCase.backupState,
                signCount: 0,
                attestedCredentialData: attestedCredData,
                extensions: nil
            )

            // Then
            let data = authData.toData()
            XCTAssertFalse(data.isEmpty)

            // Check that the flags byte is set correctly (byte 32, after rpIdHash)
            XCTAssertGreaterThan(data.count, 32)
            let flagsByte = data[32]

            // UP (User Present) = bit 0
            if testCase.userPresent {
                XCTAssertTrue((flagsByte & 0x01) != 0, "User Present flag should be set")
            } else {
                XCTAssertTrue((flagsByte & 0x01) == 0, "User Present flag should not be set")
            }

            // UV (User Verified) = bit 2
            if testCase.userVerified {
                XCTAssertTrue((flagsByte & 0x04) != 0, "User Verified flag should be set")
            } else {
                XCTAssertTrue((flagsByte & 0x04) == 0, "User Verified flag should not be set")
            }

            // AT (Attested credential data) = bit 6 (should always be set for attestation)
            XCTAssertTrue((flagsByte & 0x40) != 0, "Attested credential data flag should be set")
        }
    }

    // MARK: - Assertion Tests

    func testAssertionCreation() {
        // Given
        let rpIdHash = Data(repeating: 2, count: 32)

        // When
        let authData = AuthenticatorData.assertion(
            rpIdHash: rpIdHash,
            userPresent: true,
            userVerified: true,
            backupEligible: false,
            backupState: false,
            signCount: 1
        )

        // Then
        let data = authData.toData()
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(data.count, 37) // Fixed size for assertion without extensions
    }

    func testAssertionSignCount() {
        // Given
        let rpIdHash = Data(repeating: 2, count: 32)
        let signCount: UInt32 = 0x1234_5678

        // When
        let authData = AuthenticatorData.assertion(
            rpIdHash: rpIdHash,
            userPresent: true,
            userVerified: true,
            backupEligible: false,
            backupState: false,
            signCount: signCount
        )

        // Then
        let data = authData.toData()
        XCTAssertEqual(data.count, 37)

        // Check sign count bytes (bytes 33-36, big-endian)
        XCTAssertEqual(data[33], 0x12)
        XCTAssertEqual(data[34], 0x34)
        XCTAssertEqual(data[35], 0x56)
        XCTAssertEqual(data[36], 0x78)
    }

    // MARK: - Data Consistency Tests

    func testDataConsistency() {
        // Given
        let rpIdHash = Data(repeating: 3, count: 32)
        let attestedCredData = Data([5, 6, 7, 8])

        // When
        let authData1 = AuthenticatorData.attestation(
            rpIdHash: rpIdHash,
            userPresent: true,
            userVerified: true,
            backupEligible: false,
            backupState: false,
            signCount: 0,
            attestedCredentialData: attestedCredData,
            extensions: nil
        )

        let authData2 = AuthenticatorData.attestation(
            rpIdHash: rpIdHash,
            userPresent: true,
            userVerified: true,
            backupEligible: false,
            backupState: false,
            signCount: 0,
            attestedCredentialData: attestedCredData,
            extensions: nil
        )

        // Then
        XCTAssertEqual(authData1.toData(), authData2.toData())
    }

    func testDifferentDataProducesDifferentOutput() {
        // Given
        let rpIdHash1 = Data(repeating: 1, count: 32)
        let rpIdHash2 = Data(repeating: 2, count: 32)
        let attestedCredData = Data([1, 2, 3, 4])

        // When
        let authData1 = AuthenticatorData.attestation(
            rpIdHash: rpIdHash1,
            userPresent: true,
            userVerified: true,
            backupEligible: false,
            backupState: false,
            signCount: 0,
            attestedCredentialData: attestedCredData,
            extensions: nil
        )

        let authData2 = AuthenticatorData.attestation(
            rpIdHash: rpIdHash2,
            userPresent: true,
            userVerified: true,
            backupEligible: false,
            backupState: false,
            signCount: 0,
            attestedCredentialData: attestedCredData,
            extensions: nil
        )

        // Then
        XCTAssertNotEqual(authData1.toData(), authData2.toData())
    }

    // MARK: - Edge Cases

    func testEmptyAttestedCredentialData() {
        // Given
        let rpIdHash = Data(repeating: 1, count: 32)
        let attestedCredData = Data() // Empty

        // When
        let authData = AuthenticatorData.attestation(
            rpIdHash: rpIdHash,
            userPresent: true,
            userVerified: true,
            backupEligible: false,
            backupState: false,
            signCount: 0,
            attestedCredentialData: attestedCredData,
            extensions: nil
        )

        // Then
        let data = authData.toData()
        XCTAssertFalse(data.isEmpty)
        // Should still work even with empty credential data
    }

    func testMaxSignCount() {
        // Given
        let rpIdHash = Data(repeating: 1, count: 32)
        let maxSignCount = UInt32.max

        // When
        let authData = AuthenticatorData.assertion(
            rpIdHash: rpIdHash,
            userPresent: true,
            userVerified: true,
            backupEligible: false,
            backupState: false,
            signCount: maxSignCount
        )

        // Then
        let data = authData.toData()
        XCTAssertEqual(data.count, 37)

        // Check that max value is encoded correctly
        XCTAssertEqual(data[33], 0xFF)
        XCTAssertEqual(data[34], 0xFF)
        XCTAssertEqual(data[35], 0xFF)
        XCTAssertEqual(data[36], 0xFF)
    }

    // MARK: - Initializer Tests

    func testGeneralInitializer() {
        // Given
        let rpIdHash = Data(repeating: 1, count: 32)
        let attestedCredData = Data([1, 2, 3, 4])
        let extensions = Data([0x01, 0x02])

        // When
        let authData = AuthenticatorData(
            rpIdHash: rpIdHash,
            userPresent: true,
            userVerified: false,
            backupEligible: true,
            backupState: false,
            signCount: 42,
            attestedCredentialData: attestedCredData,
            extensions: extensions
        )

        // Then
        let data = authData.toData()
        XCTAssertFalse(data.isEmpty)
        XCTAssertEqual(authData.rpIdHash, rpIdHash)
        XCTAssertTrue(authData.userPresent)
        XCTAssertFalse(authData.userVerified)
        XCTAssertTrue(authData.backupEligible)
        XCTAssertFalse(authData.backupState)
        XCTAssertEqual(authData.signCount, 42)
        XCTAssertEqual(authData.attestedCredentialData, attestedCredData)
        XCTAssertEqual(authData.extensions, extensions)
    }

    func testGeneralInitializerWithDefaults() {
        // Given
        let rpIdHash = Data(repeating: 2, count: 32)

        // When - Use default values
        let authData = AuthenticatorData(
            rpIdHash: rpIdHash,
            userPresent: true,
            userVerified: true
        )

        // Then
        XCTAssertEqual(authData.rpIdHash, rpIdHash)
        XCTAssertTrue(authData.userPresent)
        XCTAssertTrue(authData.userVerified)
        XCTAssertFalse(authData.backupEligible) // Default
        XCTAssertFalse(authData.backupState) // Default
        XCTAssertEqual(authData.signCount, 0) // Default
        XCTAssertNil(authData.attestedCredentialData) // Default
        XCTAssertNil(authData.extensions) // Default
    }

    // MARK: - Flag Creation Tests

    func testCreateFlagsAllTrue() {
        // Given
        let rpIdHash = Data(repeating: 1, count: 32)
        let authData = AuthenticatorData(
            rpIdHash: rpIdHash,
            userPresent: true,
            userVerified: true,
            backupEligible: true,
            backupState: true,
            signCount: 0,
            attestedCredentialData: Data([1]),
            extensions: Data([2])
        )

        // When
        let flags = authData.createFlags()

        // Then
        // UP (bit 0) = 1, UV (bit 2) = 4, BE (bit 3) = 8, BS (bit 4) = 16, AT (bit 6) = 64, ED (bit 7) = 128
        let expectedFlags: UInt8 = 1 + 4 + 8 + 16 + 64 + 128 // = 221
        XCTAssertEqual(flags, expectedFlags)
    }

    func testCreateFlagsAllFalse() {
        // Given
        let rpIdHash = Data(repeating: 1, count: 32)
        let authData = AuthenticatorData(
            rpIdHash: rpIdHash,
            userPresent: false,
            userVerified: false,
            backupEligible: false,
            backupState: false,
            signCount: 0,
            attestedCredentialData: nil,
            extensions: nil
        )

        // When
        let flags = authData.createFlags()

        // Then
        XCTAssertEqual(flags, 0)
    }

    func testCreateFlagsIndividualBits() {
        // Given
        let rpIdHash = Data(repeating: 1, count: 32)

        // Test each flag individually
        let testCases = [
            (userPresent: true, userVerified: false, backupEligible: false, backupState: false,
             attestedCredData: nil, extensions: nil, expectedFlags: UInt8(1)), // UP only
            (userPresent: false, userVerified: true, backupEligible: false, backupState: false,
             attestedCredData: nil, extensions: nil, expectedFlags: UInt8(4)), // UV only
            (userPresent: false, userVerified: false, backupEligible: true, backupState: false,
             attestedCredData: nil, extensions: nil, expectedFlags: UInt8(8)), // BE only
            (userPresent: false, userVerified: false, backupEligible: false, backupState: true,
             attestedCredData: nil, extensions: nil, expectedFlags: UInt8(16)), // BS only
            (userPresent: false, userVerified: false, backupEligible: false, backupState: false,
             attestedCredData: Data([1]), extensions: nil, expectedFlags: UInt8(64)), // AT only
            (userPresent: false, userVerified: false, backupEligible: false, backupState: false,
             attestedCredData: nil, extensions: Data([1]), expectedFlags: UInt8(128)), // ED only
        ]

        for (index, testCase) in testCases.enumerated() {
            // When
            let authData = AuthenticatorData(
                rpIdHash: rpIdHash,
                userPresent: testCase.userPresent,
                userVerified: testCase.userVerified,
                backupEligible: testCase.backupEligible,
                backupState: testCase.backupState,
                signCount: 0,
                attestedCredentialData: testCase.attestedCredData,
                extensions: testCase.extensions
            )

            let flags = authData.createFlags()

            // Then
            XCTAssertEqual(flags, testCase.expectedFlags, "Test case \(index) failed")
        }
    }

    // MARK: - Flag Mask Tests

    func testFlagMaskConstants() {
        // Test that flag mask constants have correct values
        XCTAssertEqual(AuthenticatorData.upMask, 1) // bit 0
        XCTAssertEqual(AuthenticatorData.uvMask, 4) // bit 2
        XCTAssertEqual(AuthenticatorData.beMask, 8) // bit 3
        XCTAssertEqual(AuthenticatorData.bsMask, 16) // bit 4
        XCTAssertEqual(AuthenticatorData.atMask, 64) // bit 6
        XCTAssertEqual(AuthenticatorData.edMask, 128) // bit 7
    }

    // MARK: - Codable Tests

    func testCodableEncoding() throws {
        // Given
        let rpIdHash = Data(repeating: 1, count: 32)
        let attestedCredData = Data([1, 2, 3, 4])
        let extensions = Data([5, 6])

        let authData = AuthenticatorData(
            rpIdHash: rpIdHash,
            userPresent: true,
            userVerified: false,
            backupEligible: true,
            backupState: false,
            signCount: 42,
            attestedCredentialData: attestedCredData,
            extensions: extensions
        )

        // When
        let encoded = try JSONEncoder().encode(authData)

        // Then
        XCTAssertFalse(encoded.isEmpty)

        // Verify we can decode it back
        let decoded = try JSONDecoder().decode(AuthenticatorData.self, from: encoded)
        XCTAssertEqual(decoded.rpIdHash, authData.rpIdHash)
        XCTAssertEqual(decoded.userPresent, authData.userPresent)
        XCTAssertEqual(decoded.userVerified, authData.userVerified)
        XCTAssertEqual(decoded.backupEligible, authData.backupEligible)
        XCTAssertEqual(decoded.backupState, authData.backupState)
        XCTAssertEqual(decoded.signCount, authData.signCount)
        XCTAssertEqual(decoded.attestedCredentialData, authData.attestedCredentialData)
        XCTAssertEqual(decoded.extensions, authData.extensions)
    }

    func testCodableEncodingWithNilValues() throws {
        // Given
        let rpIdHash = Data(repeating: 2, count: 32)
        let authData = AuthenticatorData(
            rpIdHash: rpIdHash,
            userPresent: false,
            userVerified: true
            // All other values use defaults (nil or false)
        )

        // When
        let encoded = try JSONEncoder().encode(authData)
        let decoded = try JSONDecoder().decode(AuthenticatorData.self, from: encoded)

        // Then
        XCTAssertEqual(decoded.rpIdHash, authData.rpIdHash)
        XCTAssertEqual(decoded.userPresent, authData.userPresent)
        XCTAssertEqual(decoded.userVerified, authData.userVerified)
        XCTAssertNil(decoded.attestedCredentialData)
        XCTAssertNil(decoded.extensions)
    }

    // MARK: - Mutability Tests

    func testSignCountMutability() {
        // Given
        let rpIdHash = Data(repeating: 1, count: 32)
        var authData = AuthenticatorData(
            rpIdHash: rpIdHash,
            userPresent: true,
            userVerified: true,
            signCount: 1
        )

        // When - signCount is var, so it should be mutable
        authData.signCount = 100

        // Then
        XCTAssertEqual(authData.signCount, 100)

        // Verify it affects the output
        let data = authData.toData()
        XCTAssertEqual(data[33], 0x00) // 100 = 0x00000064
        XCTAssertEqual(data[34], 0x00)
        XCTAssertEqual(data[35], 0x00)
        XCTAssertEqual(data[36], 0x64)
    }
}
