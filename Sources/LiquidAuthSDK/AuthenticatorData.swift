import Foundation

internal struct AuthenticatorData: Codable {
    internal let rpIdHash: Data
    internal let userPresent: Bool
    internal let userVerified: Bool
    internal let backupEligible: Bool
    internal let backupState: Bool
    internal let attestedCredentialData: Data?
    internal let extensions: Data?
    internal var signCount: UInt32

    // Flag masks (WebAuthn spec)
    internal static let upMask: UInt8 = 1 // User present (bit 0)
    internal static let uvMask: UInt8 = 1 << 2 // User verified (bit 2)
    internal static let beMask: UInt8 = 1 << 3 // Backup eligible (bit 3)
    internal static let bsMask: UInt8 = 1 << 4 // Backup state (bit 4)
    internal static let atMask: UInt8 = 1 << 6 // Attested credential data included (bit 6)
    internal static let edMask: UInt8 = 1 << 7 // Extension data included (bit 7)

    // General initializer
    internal init(
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

    // Convenience for attestation
    internal static func attestation(
        rpIdHash: Data,
        userPresent: Bool,
        userVerified: Bool,
        backupEligible: Bool,
        backupState: Bool,
        signCount: UInt32,
        attestedCredentialData: Data,
        extensions: Data? = nil
    ) -> AuthenticatorData {
        return AuthenticatorData(
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

    // Convenience for assertion
    internal static func assertion(
        rpIdHash: Data,
        userPresent: Bool,
        userVerified: Bool,
        backupEligible: Bool,
        backupState: Bool,
        signCount: UInt32 = 0
    ) -> AuthenticatorData {
        return AuthenticatorData(
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

    // Flag byte builder
    internal func createFlags() -> UInt8 {
        var flags: UInt8 = 0
        if userPresent { flags |= Self.upMask }
        if userVerified { flags |= Self.uvMask }
        if backupEligible { flags |= Self.beMask }
        if backupState { flags |= Self.bsMask }
        if attestedCredentialData != nil { flags |= Self.atMask }
        if extensions != nil { flags |= Self.edMask }
        return flags
    }

    internal func toData() -> Data {
        let flags = createFlags()
        let flagsData = Data([flags])
        let signCountData = signCount.toDataBigEndian()
        var data = rpIdHash + flagsData + signCountData
        if let attestedCredentialData = attestedCredentialData {
            data += attestedCredentialData
        }
        if let extensions = extensions {
            data += extensions
        }
        return data
    }
}
