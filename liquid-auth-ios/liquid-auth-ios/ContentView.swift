import SwiftUI
import SwiftCBOR
import AVFoundation
import x_hd_wallet_api
import MnemonicSwift
import CryptoKit
import deterministicP256_swift
import WebRTC


struct ContentView: View {
    @State private var isScanning = false
    @State private var isLoading = false
    @State private var scannedMessage: String? = nil
    @State private var errorMessage: String? = nil

    @State private var showActionSheet = false
    @State private var actionSheetOrigin: String?
    @State private var actionSheetRequestId: String?

    var body: some View {
        ZStack {
            NavigationStack {
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
                    .navigationDestination(isPresented: $isScanning) {
                        QRCodeScannerView { scannedCode in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                handleScannedCode(scannedCode)
                            }
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
                .actionSheet(isPresented: $showActionSheet) {
                    actionSheet
                }
                .navigationTitle("Liquid Auth")
                .onDisappear {
                    // Reset state when navigating back
                    resetState()
                }
            }

            // Show the processing pop-up only when isLoading is true
            if isLoading {
                VStack {
                    ProgressView("Processing...")
                        .padding()
                        .background(Color.black)
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.5))
                .edgesIgnoringSafeArea(.all)
            }
        }
    }

    private var actionSheet: ActionSheet {
        ActionSheet(
            title: Text("Choose Action"),
            message: Text("Would you like to register or authenticate?"),
            buttons: [
                .default(Text("Register")) {
                    startProcessing {
                        Task {
                            if let origin = actionSheetOrigin, let requestId = actionSheetRequestId {
                                await register(origin: origin, requestId: requestId)
                            }
                        }
                    }
                },
                .default(Text("Authenticate")) {
                    startProcessing {
                        Task {
                            if let origin = actionSheetOrigin, let requestId = actionSheetRequestId {
                                await authenticate(origin: origin, requestId: requestId)
                            }
                        }
                    }
                },
                .cancel {
                    resetState() // Reset state when "Cancel" is pressed
                }
            ]
        )
    }

    private func resetState() {
        // Reset all states
        isLoading = false
        scannedMessage = nil
        errorMessage = nil
        showActionSheet = false
        actionSheetOrigin = nil
        actionSheetRequestId = nil
    }


    private func handleScannedCode(_ code: String) {

        isScanning = false // Dismiss the QR code scanner
        isLoading = false // Ensure progress bar is hidden
        showActionSheet = false // Ensure action sheet is hidden

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
        Task {
            // Update the UI to show the scanned message
            scannedMessage = "Liquid Auth URI: \(uri)"
            errorMessage = nil
            print("Handling Liquid Auth URI: \(uri)")

            // Extract origin and request ID from the URI
            guard let (origin, requestId) = Utility.extractOriginAndRequestId(from: uri) else {
                print("Failed to extract origin and request ID.")
                errorMessage = "Invalid Liquid Auth URI."
                isLoading = false
                return
            }

            print("Origin: \(origin), Request ID: \(requestId)")


            // Prompt the user to choose between registration and authentication
            DispatchQueue.main.async {
                actionSheetOrigin = origin
                actionSheetRequestId = requestId
                showActionSheet = true
                }
            }
        }

    private func startProcessing(action: @escaping () -> Void) {
        // Ensure the progress bar only shows after the action sheet is dismissed
        showActionSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isLoading = true
            action()
        }
    }

    private func register(origin: String, requestId: String) async {
        do {
            defer { 
                isLoading = false
            }

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

            // Post attestation options
            let (data, sessionCookie) = try await attestationApi.postAttestationOptions(origin: origin, userAgent: userAgent, options: options)
            print("Response data: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
            if let cookie = sessionCookie {
                print("Session cookie: \(cookie)")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                let challengeBase64Url = json["challenge"] as? String else {
                throw NSError(domain: "com.liquidauth.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response JSON or find the challenge field."])
            }

            print("Challenge (Base64): \(challengeBase64Url)")
            print("Challenge Decoded: \([UInt8](Utility.decodeBase64Url(challengeBase64Url)!))")
            print("Challenge JSON: \(Utility.decodeBase64UrlToJSON(challengeBase64Url) ?? "nil")")

            // Validate and sign the challenge
            let schema = try Schema(filePath: Bundle.main.path(forResource: "auth.request", ofType: "json")!)
            let valid = try Ed25519Wallet?.validateData(data: Data(Utility.decodeBase64UrlToJSON(challengeBase64Url)!.utf8), metadata: SignMetadata(encoding: Encoding.none, schema: schema))

            guard valid == true else {
                throw NSError(domain: "com.liquidauth.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Data is not valid"])
            }

            guard let sig = try Ed25519Wallet?.rawSign(
                bip44Path: [UInt32(0x8000_0000) + 44, UInt32(0x8000_0000) + 283, UInt32(0x8000_0000) + 0, 0, 0],
                message: Data([UInt8](Utility.decodeBase64Url(challengeBase64Url)!)),
                derivationType: BIP32DerivationType.Peikert
            ) else {
                throw NSError(domain: "com.liquidauth.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create signature"])
            }

            print("Signature: \(sig.base64URLEncodedString())")
            print("Signature Length (Raw Bytes): \(sig.count)")

            // Create the Liquid extension JSON object
            let liquidExt = createLiquidExt(
                requestId: requestId,
                address: address,
                signature: sig.base64URLEncodedString()
            )
            print("Created liquidExt JSON object: \(liquidExt)")

            // Deterministic ID - derived from P256 Public Key
            let rawId = Data([UInt8](Utility.hashSHA256(P256KeyPair.publicKey.rawRepresentation)))
            print("Created rawId: \(rawId.map { String(format: "%02hhx", $0) }.joined())")

            // Create clientDataJSON
            let clientData: [String: Any] = [
                "type": "webauthn.create",
                "challenge": challengeBase64Url,
                "origin": "https://\(origin)"
            ]

            guard let clientDataJSONData = try? JSONSerialization.data(withJSONObject: clientData, options: []),
                  let _ = String(data: clientDataJSONData, encoding: .utf8) else {
                throw NSError(domain: "com.liquidauth.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create clientDataJSON"])
            }

            let clientDataJSONBase64Url = clientDataJSONData.base64URLEncodedString()
            print("Created clientDataJSON: \(clientDataJSONBase64Url)")

            // Create attestationObject
            let attestedCredData = Utility.getAttestedCredentialData(aaguid: UUID(uuidString: "5c7b7e9a-2b85-464e-9ea3-529582bb7e34")!, credentialId: rawId, publicKey: P256KeyPair.publicKey.rawRepresentation)
            print("created attestedCredData: \(attestedCredData.count)")

            let rpIdHash = Utility.hashSHA256(origin.data(using: .utf8)!)
            let authData = AttestationAuthData(
                rpIdHash,
                true,
                true,
                0,
                attestedCredData,
                nil
            )
            print("created authData: \(authData)")

            let attObj: [String: Any] = [
                "fmt": "none",
                "attStmt": [:],
                "authData": authData.toData()
            ]

            let cborEncoded = try CBOR.encodeMap(attObj)
            let attestationObject = Data(cborEncoded)
            print("Created attestationobject: \(attestationObject.base64URLEncodedString())")

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

            // Post attestation result
            let responseData = try await attestationApi.postAttestationResult(
                origin: origin,
                userAgent: Utility.getUserAgent(),
                credential: credential,
                liquidExt: liquidExt
            )

            // Handle the server response
            let responseString = String(data: responseData, encoding: .utf8) ?? "Invalid response"
            print("Attestation result posted: \(responseString)")

            // Parse the response to check for errors
            if let responseJSON = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
            let errorReason = responseJSON["error"] as? String {
                // If an error exists, propagate it
                errorMessage = "Registration failed: \(errorReason)"
                scannedMessage = nil
            } else {
                // If no error, handle success
                scannedMessage = "Attestation result successfully posted: \(responseString)"
                errorMessage = nil

                startSignaling(origin: origin, requestId: requestId)
            }

        } catch {
            print("Error in register: \(error)")
            errorMessage = "Failed to handle Liquid Auth URI Registration flow: \(error.localizedDescription)"
        }
    }


    private func authenticate(origin: String, requestId: String) async {
        do {

            defer { 
                isLoading = false
            }

            let userAgent = Utility.getUserAgent()
            
            let assertionApi = AssertionApi()
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

            let credentialId = Data([UInt8](Utility.hashSHA256(P256KeyPair.publicKey.rawRepresentation))).base64URLEncodedString()


            // Call postAssertionOptions
            let (data, sessionCookie) = try await assertionApi.postAssertionOptions(
                origin: origin,
                userAgent: userAgent,
                credentialId: credentialId
            )

            // Handle the response
            if let sessionCookie = sessionCookie {
                print("Session cookie: \(sessionCookie)")
                // Store or use the session cookie as needed
            }

                // Parse the response data
            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let challengeBase64Url = json["challenge"] as? String,
                  let _ = json["allowCredentials"] as? [[String: Any]],
                  let _ = json["rpId"] as? String else {
                throw NSError(domain: "Missing required fields in response", code: -1, userInfo: nil)
            }
            
            print("Response: \(String(describing: String(data: data, encoding: .utf8)))")

            print("Challenge (Base64): \(challengeBase64Url)")
            print("Challenge Decoded: \([UInt8](Utility.decodeBase64Url(challengeBase64Url)!))")
            print("Challenge JSON: \(Utility.decodeBase64UrlToJSON(challengeBase64Url) ?? "nil")")

            // Validate and sign the challenge
            let schema = try Schema(filePath: Bundle.main.path(forResource: "auth.request", ofType: "json")!)
            let valid = try Ed25519Wallet?.validateData(data: Data(Utility.decodeBase64UrlToJSON(challengeBase64Url)!.utf8), metadata: SignMetadata(encoding: Encoding.none, schema: schema))

            guard valid == true else {
                throw NSError(domain: "com.liquidauth.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Data is not valid"])
            }

            guard let sig = try Ed25519Wallet?.rawSign(
                bip44Path: [UInt32(0x8000_0000) + 44, UInt32(0x8000_0000) + 283, UInt32(0x8000_0000) + 0, 0, 0],
                message: Data([UInt8](Utility.decodeBase64Url(challengeBase64Url)!)),
                derivationType: BIP32DerivationType.Peikert
            ) else {
                throw NSError(domain: "com.liquidauth.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create signature"])
            }

            print("Signature: \(sig.base64URLEncodedString())")
            print("Signature Length (Raw Bytes): \(sig.count)")
            
            // Create the Liquid extension JSON object
            let liquidExt = createLiquidExt(
                requestId: requestId,
                address: address,
                signature: sig.base64URLEncodedString()
            )
            print("Created liquidExt JSON object: \(liquidExt)")

            // Create clientDataJSON
            let clientData: [String: Any] = [
                "type": "webauthn.get",
                "challenge": challengeBase64Url,
                "origin": "https://\(origin)"
            ]
            
            
            guard let clientDataJSONData = try? JSONSerialization.data(withJSONObject: clientData, options: []),
                  let _ = String(data: clientDataJSONData, encoding: .utf8) else {
                throw NSError(domain: "com.liquidauth.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create clientDataJSON"])
            }

            let clientDataJSONBase64Url = clientDataJSONData.base64URLEncodedString()
            print("Created clientDataJSON: \(clientDataJSONBase64Url)")

            let rpIdHash = Utility.hashSHA256(origin.data(using: .utf8)!)
            let authenticatorData = AssertionAuthData(
                rpIdHash: rpIdHash,
                userPresent: true,
                userVerified: true,
                backupEligible: false,
                backupState: false
            ).toData()


            let clientDataHash = Utility.hashSHA256(clientDataJSONData)
            let dataToSign = authenticatorData + clientDataHash

            let signature = try DP256.signWithDomainSpecificKeyPair(keyPair: P256KeyPair, payload: dataToSign)

            let assertionResponse: [String: Any] = [
                "id": credentialId,
                "type": "public-key",
                "userHandle": "tester",
                "rawId": credentialId,
                "response": [
                    "clientDataJSON": clientDataJSONData.base64URLEncodedString(),
                    "authenticatorData": authenticatorData.base64URLEncodedString(),
                    "signature": signature.derRepresentation.base64URLEncodedString()
                ]
            ]

            print("Created assertion response: \(assertionResponse)")

            // Serialize the assertion response into a JSON string
            guard let assertionResponseData = try? JSONSerialization.data(withJSONObject: assertionResponse, options: []),
                let assertionResponseJSON = String(data: assertionResponseData, encoding: .utf8) else {
                throw NSError(domain: "com.liquidauth.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize assertion response"])
            }                

            // Post the assertion result
            let responseData = try await assertionApi.postAssertionResult(
                origin: origin,
                userAgent: userAgent,
                credential: assertionResponseJSON,
                liquidExt: liquidExt
            )

            // Handle the server response
            let responseString = String(data: responseData, encoding: .utf8) ?? "Invalid response"
            print("Assertion result posted: \(responseString)")

            // Parse the response to check for errors
            if let responseJSON = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
            let errorReason = responseJSON["error"] as? String {
                // If an error exists, propagate it
                errorMessage = "Authentication failed: \(errorReason)"
                scannedMessage = nil
            } else {
                // If no error, handle success
                scannedMessage = "Authentication completed successfully."
                errorMessage = nil

                startSignaling(origin: origin, requestId: requestId)
            }



        // Next step
        } catch {
            print("Error in authenticate: \(error)")
            errorMessage = "Failed to retrieve authentication options: \(error.localizedDescription)"
        }
    }

    private func startSignaling(origin: String, requestId: String) {
        let signalService = SignalService.shared
        
        signalService.start(url: origin, httpClient: URLSession.shared)

        let iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
            RTCIceServer(urlStrings: ["stun:stun1.l.google.com:19302"]),
            RTCIceServer(urlStrings: ["stun:stun2.l.google.com:19302"]),
            RTCIceServer(urlStrings: ["turn:global.turn.nodely.network:80"], username: "liquid-auth", credential: "sqmcP4MiTKMT4TGEDSk9jgHY"),
            RTCIceServer(urlStrings: ["turns:global.turn.nodely.network:443"], username: "liquid-auth", credential: "sqmcP4MiTKMT4TGEDSk9jgHY"),
            RTCIceServer(urlStrings: ["turn:eu.turn.nodely.io:80"], username: "liquid-auth", credential: "sqmcP4MiTKMT4TGEDSk9jgHY"),
            RTCIceServer(urlStrings: ["turns:eu.turn.nodely.io:443"], username: "liquid-auth", credential: "sqmcP4MiTKMT4TGEDSk9jgHY"),
            RTCIceServer(urlStrings: ["turn:us.turn.nodely.io:80"], username: "liquid-auth", credential: "sqmcP4MiTKMT4TGEDSk9jgHY"),
            RTCIceServer(urlStrings: ["turns:us.turn.nodely.io:443"],  username: "liquid-auth", credential: "sqmcP4MiTKMT4TGEDSk9jgHY"),
        ]
        
        Task {
            signalService.connectToPeer(
                requestId: requestId,
                type: "answer",
                origin: origin,
                iceServers: iceServers,
                onMessage: { message in
                    print("ContentView: Received message: \(message)")
                    // Handle incoming messages here
                },
                onStateChange: { state in
                    print("ContentView: Data channel state changed: \(state ?? "unknown")")
                    // Handle state changes here
                    if state == "open" {
                        SignalService.shared.sendMessage("test")
                    }
                }
            )
            print("after signalService.connectToPeer")
        }
    }

    private func createLiquidExt(
        requestId: String,
        address: String,
        signature: String
    ) -> [String: Any] {
        return [
            "type": "algorand",
            "requestId": requestId,
            "address": address,
            "signature": signature,
            "device": UIDevice.current.model
        ]
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
