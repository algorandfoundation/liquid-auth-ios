import Foundation

struct AssertionAuthData: Codable {
    let rpIdHash: Data
    let userPresent: Bool
    let userVerified: Bool
    let backupEligible: Bool
    let backupState: Bool

    // Define these as static constants for the flags
    static let upMask: UInt8 = 1      // User present result (bit 0)
    static let uvMask: UInt8 = 1 << 2 // User verified result (bit 2)
    static let beMask: UInt8 = 1 << 3 // Backup eligible result (bit 3)
    static let bsMask: UInt8 = 1 << 4 // Backup state result (bit 4)

    init(
        rpIdHash: Data,
        userPresent: Bool,
        userVerified: Bool,
        backupEligible: Bool,
        backupState: Bool
    ) {
        self.rpIdHash = rpIdHash
        self.userPresent = userPresent
        self.userVerified = userVerified
        self.backupEligible = backupEligible
        self.backupState = backupState
    }

    /// Generates the flags byte based on user presence, verification, and backup state.
    private func createFlags() -> UInt8 {
        var flags: UInt8 = 0
        if userPresent { flags |= AssertionAuthData.upMask }
        if userVerified { flags |= AssertionAuthData.uvMask }
        if backupEligible { flags |= AssertionAuthData.beMask }
        if backupState { flags |= AssertionAuthData.bsMask }
        return flags
    }

    /// Converts the `AssertionAuthData` into a `Data` object.
    func toData() -> Data {
        let flags = createFlags()
        let flagsData = Data([flags])
        let zeroCounter = Data([0, 0, 0, 0]) // 4 zero bytes for the signature counter
        return rpIdHash + flagsData + zeroCounter
    }
}
