import Foundation

// https://fidoalliance.org/specs/fido-v2.2-rd-20230321/fido-client-to-authenticator-protocol-v2.2-rd-20230321.html#hybrid-qr-initiated
struct FIDORequest {
    let publicKey: [UInt8]
    let qrSecret: [UInt8]
    let tunnelServerCount: UInt64
    let currentTime: UInt64?
    let stateAssisted: Bool?
    let hint: String?

    /// Determines if the flow is MakeCredential or GetAssertion based on the hint.
    var flowType: String {
        switch hint {
        case "mc":
            return "MakeCredential"
        case "ga":
            return "GetAssertion"
        default:
            return "Unknown"
        }
    }
}