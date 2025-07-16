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

import Foundation

public struct AuthenticatorData: Codable {
    let rpIdHash: Data
    let userPresent: Bool
    let userVerified: Bool
    let backupEligible: Bool
    let backupState: Bool
    let attestedCredentialData: Data?
    let extensions: Data?
    var signCount: UInt32

    // Flag masks (WebAuthn spec)
    static let upMask: UInt8 = 1 // User present (bit 0)
    static let uvMask: UInt8 = 1 << 2 // User verified (bit 2)
    static let beMask: UInt8 = 1 << 3 // Backup eligible (bit 3)
    static let bsMask: UInt8 = 1 << 4 // Backup state (bit 4)
    static let atMask: UInt8 = 1 << 6 // Attested credential data included (bit 6)
    static let edMask: UInt8 = 1 << 7 // Extension data included (bit 7)

    // General initializer
    init(
        rpIdHash: Data,
        userPresent: Bool,
        userVerified: Bool,
        backupEligible: Bool = false,
        backupState: Bool = false,
        signCount: UInt32 = 0,
        attestedCredentialData: Data? = nil,
        extensions: Data? = nil
    ) {
        self.rpIdHash = rpIdHash
        self.userPresent = userPresent
        self.userVerified = userVerified
        self.backupEligible = backupEligible
        self.backupState = backupState
        self.signCount = signCount
        self.attestedCredentialData = attestedCredentialData
        self.extensions = extensions
    }

    /// Creates AuthenticatorData for attestation (registration) ceremonies
    ///
    /// - Parameters:
    ///   - rpIdHash: SHA-256 hash of the relying party identifier
    ///   - userPresent: Whether user presence was verified
    ///   - userVerified: Whether user verification was performed
    ///   - backupEligible: Whether the authenticator is backup eligible
    ///   - backupState: Whether the authenticator is currently backed up
    ///   - signCount: Signature counter value
    ///   - attestedCredentialData: The attested credential data
    ///   - extensions: Optional extensions data
    /// - Returns: AuthenticatorData instance for attestation
    public static func attestation(
        rpIdHash: Data,
        userPresent: Bool,
        userVerified: Bool,
        backupEligible: Bool,
        backupState: Bool,
        signCount: UInt32,
        attestedCredentialData: Data,
        extensions: Data? = nil
    ) -> AuthenticatorData {
        AuthenticatorData(
            rpIdHash: rpIdHash,
            userPresent: userPresent,
            userVerified: userVerified,
            backupEligible: backupEligible,
            backupState: backupState,
            signCount: signCount,
            attestedCredentialData: attestedCredentialData,
            extensions: extensions
        )
    }

    /// Creates AuthenticatorData for assertion (authentication) ceremonies
    ///
    /// - Parameters:
    ///   - rpIdHash: SHA-256 hash of the relying party identifier
    ///   - userPresent: Whether user presence was verified
    ///   - userVerified: Whether user verification was performed
    ///   - backupEligible: Whether the authenticator is backup eligible
    ///   - backupState: Whether the authenticator is currently backed up
    ///   - signCount: Signature counter value (defaults to 0)
    /// - Returns: AuthenticatorData instance for assertion
    public static func assertion(
        rpIdHash: Data,
        userPresent: Bool,
        userVerified: Bool,
        backupEligible: Bool,
        backupState: Bool,
        signCount: UInt32 = 0
    ) -> AuthenticatorData {
        AuthenticatorData(
            rpIdHash: rpIdHash,
            userPresent: userPresent,
            userVerified: userVerified,
            backupEligible: backupEligible,
            backupState: backupState,
            signCount: signCount,
            attestedCredentialData: nil,
            extensions: nil
        )
    }

    /// Creates the flags byte for the authenticator data
    ///
    /// - Returns: UInt8 flags byte encoding user presence, verification, and backup state
    func createFlags() -> UInt8 {
        var flags: UInt8 = 0
        if userPresent { flags |= Self.upMask }
        if userVerified { flags |= Self.uvMask }
        if backupEligible { flags |= Self.beMask }
        if backupState { flags |= Self.bsMask }
        if attestedCredentialData != nil { flags |= Self.atMask }
        if extensions != nil { flags |= Self.edMask }
        return flags
    }

    /// Converts the AuthenticatorData to its binary representation
    ///
    /// - Returns: Data containing the encoded authenticator data
    public func toData() -> Data {
        let flags = createFlags()
        let flagsData = Data([flags])
        let signCountData = signCount.toDataBigEndian()
        var data = rpIdHash + flagsData + signCountData
        if let attestedCredentialData {
            data += attestedCredentialData
        }
        if let extensions {
            data += extensions
        }
        return data
    }
}
