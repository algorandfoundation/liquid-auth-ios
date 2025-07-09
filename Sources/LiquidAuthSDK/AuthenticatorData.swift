import Foundation

public struct AuthenticatorData: Codable {
    public let rpIdHash: Data
    public let userPresent: Bool
    public let userVerified: Bool
    public let backupEligible: Bool
    public let backupState: Bool
    public let attestedCredentialData: Data?
    public let extensions: Data?
    public var signCount: UInt32

    // Flag masks (WebAuthn spec)
    public static let upMask: UInt8 = 1 // User present (bit 0)
    public static let uvMask: UInt8 = 1 << 2 // User verified (bit 2)
    public static let beMask: UInt8 = 1 << 3 // Backup eligible (bit 3)
    public static let bsMask: UInt8 = 1 << 4 // Backup state (bit 4)
    public static let atMask: UInt8 = 1 << 6 // Attested credential data included (bit 6)
    public static let edMask: UInt8 = 1 << 7 // Extension data included (bit 7)

    // General initializer
    public init(
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
    public static func assertion(
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
    public func createFlags() -> UInt8 {
        var flags: UInt8 = 0
        if userPresent { flags |= Self.upMask }
        if userVerified { flags |= Self.uvMask }
        if backupEligible { flags |= Self.beMask }
        if backupState { flags |= Self.bsMask }
        if attestedCredentialData != nil { flags |= Self.atMask }
        if extensions != nil { flags |= Self.edMask }
        return flags
    }

    public func toData() -> Data {
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
