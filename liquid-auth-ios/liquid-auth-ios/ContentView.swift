import SwiftUI
import SwiftCBOR
import AVFoundation
import x_hd_wallet_api
import MnemonicSwift
import CryptoKit
import deterministicP256_swift


struct ContentView: View {
    @State private var isScanning = false
    @State private var isLoading = false
    @State private var scannedMessage: String? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Ready to scan?")
                
                Button(action: {
                    isScanning = true
                }) {
                    Text("Scan QR Code")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .sheet(isPresented: $isScanning) {
                    QRCodeScannerView { scannedCode in
                        isScanning = false // Dismiss the camera view immediately
                        handleScannedCode(scannedCode)
                    }
                }

                if let message = scannedMessage {
                    Text("Message: \(message)")
                        .padding()
                }

                if let error = errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()

            // Show a loading overlay when isLoading is true
            if isLoading {
                VStack {
                    ProgressView("Processing...")
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.5))
                .edgesIgnoringSafeArea(.all)
            }
        }
    }


    private func handleScannedCode(_ code: String) {
        if code.starts(with: "FIDO:/") {
            // Decode the FIDO URI

            // We need to look into hybrid transport for iOS to understand how to properly
            // handle the FIDO URI. The current implementation is a placeholder.
            scannedMessage = "FIDO URI detected. Processing..."
            errorMessage = nil

            // Attempt to open the URI using UIApplication
            
            /*
             guard let url = URL(string: code) else {
                errorMessage = "Invalid URI format."
                scannedMessage = nil
                return
            }
            
            UIApplication.shared.open(url, options: [:]) { success in
                    if success {
                        scannedMessage = "Opened URI: \(code)"
                        errorMessage = nil
                    } else {
                        errorMessage = "Failed to open URI: \(code)"
                        scannedMessage = nil
                    }
                } 
            */


            // This is how to decode the FIDO URI and extract the contents
            /*
             if let fidoRequest = FIDOHandler.decodeFIDOURI(code) {
                // Determine the flow type
                scannedMessage = "\(fidoRequest.flowType) flow detected. Ready to proceed."

                // Log the extracted fields
                print("Public Key: \(fidoRequest.publicKey)")
                print("QR Secret: \(fidoRequest.qrSecret)")
                print("Tunnel Server Count: \(fidoRequest.tunnelServerCount)")
                if let currentTime = fidoRequest.currentTime {
                    print("Current Time: \(currentTime)")
                }
                if let stateAssisted = fidoRequest.stateAssisted {
                    print("State-Assisted Transactions: \(stateAssisted)")
                }
                if let hint = fidoRequest.hint {
                    print("Hint: \(hint)")
                }

                errorMessage = nil
            } else {
                errorMessage = "Failed to process FIDO URI."
                scannedMessage = nil
            }
            */
        } else if code.starts(with: "liquid://") {
            // Handle Liquid Auth URI
            isLoading = true
            handleLiquidAuthURI(code)
        } else {
            errorMessage = "Unsupported QR code format."
            scannedMessage = nil
        }
    }

    private func handleLiquidAuthURI(_ uri: String) {
        // Example: Decode the Liquid Auth URI
        scannedMessage = "Liquid Auth URI: \(uri)"
        errorMessage = nil
        // Add logic to decode and process the Liquid Auth message
        print("Handling Liquid Auth URI: \(uri)")

        if let (origin, requestId) = Utility.extractOriginAndRequestId(from: uri) {
            print("Origin: \(origin), Request ID: \(requestId)")

            // TODO: check if credential for the specific origin already exists
            // For now, only register:

            if (true) {
                DispatchQueue.global().async {
                    register(origin: origin, requestId: requestId)
                    DispatchQueue.main.async {
                        isLoading = false // Stop loading
                    }
                }
            }
            // TODO: If yes, authenticate with the credential
            
        } else {
            print("Failed to extract origin and request ID.")
            isLoading = false
        }
    }

    private func register(origin: String, requestId: String) {

        do {
            // Get the appropriate Algorand Address
            let phrase = "salon zoo engage submit smile frost later decide wing sight chaos renew lizard rely canal coral scene hobby scare step bus leaf tobacco slice"
            
            let seed = try Mnemonic.deterministicSeedString(from: phrase)
            
            let Ed25519Wallet = XHDWalletAPI(seed: seed)
            
            let DP256 = DeterministicP256()
            let derivedMainKey = try DP256.genDerivedMainKeyWithBIP39(phrase: phrase)
            let P256KeyPair = DP256.genDomainSpecificKeyPair(derivedMainKey: derivedMainKey, origin: "https://\(origin)", userHandle: "tester")

            
            guard let pk = try Ed25519Wallet?.keyGen(context: KeyContext.Address, account: 0, change: 0, keyIndex: 0) else {
                throw NSError(domain: "Key generation failed", code: -1, userInfo: nil)
            }
            
            
            
            let address = try Utility.encodeAddress(bytes: pk)

            let attestationApi = AttestationApi()

            let options: [String: Any] = [
                "username": address,
                "displayName": "Liquid Auth User",
                "authenticatorSelection": ["userVerification": "required"],
                "extensions": ["liquid": true]
            ]

            let userAgent = Utility.getUserAgent()

            attestationApi.postAttestationOptions(origin: origin, userAgent: userAgent, options: options, completion: { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let (data, sessionCookie)):
                        print("Response data: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
                        if let cookie = sessionCookie {
                            print("Session cookie: \(cookie)")
                        }

                        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                        let challengeBase64Url = json["challenge"] as? String {
                            print("Challenge (Base64): \(challengeBase64Url)")
                            print("Challenge Decoded: \([UInt8](Utility.decodeBase64Url(challengeBase64Url)!))")
                            print("Challenge JSON: \(Utility.decodeBase64UrlToJSON(challengeBase64Url) ?? "nil")")
                            do {
                                let schema = try Schema(filePath: Bundle.main.path(forResource: "auth.request", ofType: "json")!)
                                
                                // TODO: Relates to the comments below 
                                // REPLACE WITH Ed25519Wallet.signData once fixed to ensure PROPER flow
//                                let sig = try Ed25519Wallet?.signData(
//                                    context: KeyContext.Address,
//                                    account: 0,
//                                    change: 0,
//                                    keyIndex: 0,
//                                    data: ...,
//                                    metadata: SignMetadata(encoding: Encoding.none, schema: schema)
//                                )

                                // For now we validateData and call rawSign separately.
                                let valid = try Ed25519Wallet?.validateData(data: Data(Utility.decodeBase64UrlToJSON(challengeBase64Url)!.utf8), metadata: SignMetadata(encoding: Encoding.none, schema: schema))

                                if !(valid ?? false) {
                                    throw NSError(domain: "com.liquidauth.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Data is not valid"])
                                }

                                // Dangerous to expose rawSign like this
                                if let sig = try Ed25519Wallet?.rawSign(
                                    bip44Path: [0x8000_0000 + 0, 0x8000_0000 + 283, 0x8000_0000 + 0, 0, 0],
                                    message: Data([UInt8](Utility.decodeBase64Url(challengeBase64Url)!)),
                                    derivationType: BIP32DerivationType.Peikert
                                ) {
                                    print("Signature: \(sig.base64URLEncodedString())")
                                    print("Signature Length (Raw Bytes): \(sig.count)")

                                    // <-- LIQUID EXTENSION: -->

                                    // Create the Liquid extension JSON object
                                    let liquidExt: [String: Any] = [
                                        "type": "algorand",
                                        "requestId": requestId,
                                        "address": address,
                                        "signature": sig.base64URLEncodedString(),
                                    ]
                                    print("Created liquidExt JSON object: \(liquidExt)")
                                    
                                    // <-- ID & RawID: -->
                                    // Deterministic ID - derived from P256 Public Key
                                    let rawId = Data([UInt8](Utility.hashSHA256(P256KeyPair.publicKey.rawRepresentation)))
                                    
                                    print("Created rawId: \(rawId.map { String(format: "%02hhx", $0) }.joined())")
                                    
                                    // <-- clientDataJSON: -->
                                    let clientData: [String: Any] = [
                                        "type": "webauthn.create",
                                        "challenge": challengeBase64Url,
                                        "origin": "https://\(origin)"
                                    ]

                                    guard let clientDataJSONData = try? JSONSerialization.data(withJSONObject: clientData, options: []),
                                        let clientDataJSON = String(data: clientDataJSONData, encoding: .utf8) else {
                                        throw NSError(domain: "com.liquidauth.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create clientDataJSON"])
                                    }

                                    let clientDataJSONBase64Url = clientDataJSONData.base64URLEncodedString()
                                    
                                    print("Created clientDataJSON: \(clientDataJSONBase64Url)")
                                    
                                    // <-- attestationObject: -->

                                    let attestedCredData = Utility.getAttestedCredentialData(aaguid: UUID.init(uuidString: "5c7b7e9a-2b85-464e-9ea3-529582bb7e34")!, credentialId: rawId, publicKey: P256KeyPair.publicKey.rawRepresentation)
                                    
                                    print("created attestedCredData: \(attestedCredData.count)")
                                    
                                    guard let originData = origin.data(using: .utf8) else {
                                        throw NSError(domain: "com.liquidauth.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode origin to UTF-8"])
                                    }

                                    let rpIdHash = Utility.hashSHA256(originData)
                                    
                                    let userPresent = true
                                    let userVerified = true
                                    let signCount: UInt32 = 0
                                    let attestedCredentialData = attestedCredData

                                    let authData = AuthenticatorData(
                                        rpIdHash,
                                        userPresent,
                                        userVerified,
                                        signCount,
                                        attestedCredentialData,
                                        nil
                                    )
                                    
                                    print("created authData: \(authData)")


                                    let attObj: [String: Any] = [
                                        "fmt": "none",
                                        "attStmt": [:], // when the format is "none", `attStmt` should be empty.
                                        "authData": authData.toData()
                                    ]

                                    let cborEncoded = try CBOR.encodeMap(attObj)
                                    let attestationObject = Data(cborEncoded)
                                    
                                    print("Created attestationobject: \(attestationObject)")
                                    
                                    print("Attestationobject in Base64Url: \(attestationObject.base64URLEncodedString())")

                                    let credential: [String: Any] = [
                                        "id": rawId.base64URLEncodedString(),
                                        "type": "public-key",
                                        "rawId": rawId.base64URLEncodedString(),
                                        "response": [
                                            "clientDataJSON": clientDataJSONBase64Url,
                                            "attestationObject": attestationObject.base64URLEncodedString()
                                        ]
                                    ]
                                    
                                    print("Created credential: \(credential)")

                                    // Send the attestation result
                                    attestationApi.postAttestationResult(
                                        origin: origin,
                                        userAgent: Utility.getUserAgent(),
                                        credential: credential,
                                        liquidExt: liquidExt
                                    ) { result in
                                        DispatchQueue.main.async {
                                            switch result {
                                            case .success(let data):
                                                print("Attestation result posted: \(String(data: data, encoding: .utf8) ?? "Invalid response")")
                                            case .failure(let error):
                                                print("Failed to post attestation result: \(error)")
                                                self.errorMessage = "Failed to post attestation result: \(error.localizedDescription)"
                                            }
                                        }
                                    }
                                } else {
                                    throw NSError(domain: "com.liquidauth.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create signature"])
                                }
                            } catch {
                                print("Failed to load schema: \(error)")
                            }
                        } else {
                            print("Failed to parse response JSON or find the challenge field.")
                        }
                        
                    case .failure(let error):
                        print("Error: \(error)")
                    }
                    isLoading = false
                }
            })
        } catch {
            print("Error in register: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to register: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}

extension Data {
    /// Converts the Data object to a Base64URL-encoded string.
    func base64URLEncodedString() -> String {
        let base64 = self.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "") // Remove padding
        return base64
    }
}

#Preview {
    ContentView()
}
