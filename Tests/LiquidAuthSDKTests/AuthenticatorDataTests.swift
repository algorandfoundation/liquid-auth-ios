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
}
