import XCTest
@testable import liquid_auth_ios

final class FIDOHandlerTests: XCTestCase {
    func testDecodeFIDOURI() {
        // Example FIDO URI (base10-encoded string)
        let fidoURI = "FIDO:/674869333506131586293076724977443367731019628156292384354259529213161969518231792172611583034218375041007008870551213670082509686365434729312973136331522109321447142404"

        // Decode the FIDO URI
        guard let fidoRequest = FIDOHandler.decodeFIDOURI(fidoURI) else {
            XCTFail("Failed to decode FIDO URI.")
            return
        }

        // Assert required fields
        XCTAssertEqual(fidoRequest.publicKey, [3, 208, 203, 139, 207, 78, 251, 171, 28, 112, 129, 103, 121, 23, 114, 214, 106, 118, 131, 132, 215, 9, 50, 66, 93, 79, 106, 100, 41, 30, 178, 37, 157], "Public key does not match.")
        XCTAssertEqual(fidoRequest.qrSecret, [139, 59, 251, 214, 197, 13, 52, 93, 241, 58, 54, 187, 91, 163, 16, 199], "QR secret does not match.")
        XCTAssertEqual(fidoRequest.tunnelServerCount, 2, "Tunnel server count does not match.")

        // Assert optional fields
        XCTAssertEqual(fidoRequest.currentTime, 1744715214, "Current time does not match.")
        XCTAssertEqual(fidoRequest.stateAssisted, false, "State-assisted transactions flag does not match.")
        XCTAssertEqual(fidoRequest.hint, "mc", "Hint does not match.")

        // Assert flow type
        XCTAssertEqual(fidoRequest.flowType, "MakeCredential", "Flow type does not match.")
    }
}