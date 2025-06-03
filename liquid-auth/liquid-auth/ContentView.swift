import SwiftUI
import SwiftCBOR
import AVFoundation
import x_hd_wallet_api
import MnemonicSwift
import CryptoKit
import deterministicP256_swift
import WebRTC
import LocalAuthentication
import AuthenticationServices

import Foundation

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
                        ScrollView {
                            Text("Message: \(message)")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 300) 
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
                Logger.debug("Public Key: \(fidoRequest.publicKey)")
                Logger.debug("QR Secret: \(fidoRequest.qrSecret)")
                Logger.debug("Tunnel Server Count: \(fidoRequest.tunnelServerCount)")
                if let currentTime = fidoRequest.currentTime {
                    Logger.debug("Current Time: \(currentTime)")
                }
                if let stateAssisted = fidoRequest.stateAssisted {
                    Logger.debug("State-Assisted Transactions: \(stateAssisted)")
                }
                if let hint = fidoRequest.hint {
                    Logger.debug("Hint: \(hint)")
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
            Logger.error("Unsupported QR code format: \(code)")
            errorMessage = "Unsupported QR code format."
            scannedMessage = nil
        }
    }

    private func handleLiquidAuthURI(_ uri: String) {
        Task {
            // Update the UI to show the scanned message
            scannedMessage = "Liquid Auth URI: \(uri)"
            errorMessage = nil
            Logger.debug("Handling Liquid Auth URI: \(uri)")

            // Extract origin and request ID from the URI
            guard let (origin, requestId) = Utility.extractOriginAndRequestId(from: uri) else {
                Logger.error("Failed to extract origin and request ID.")
                errorMessage = "Invalid Liquid Auth URI."
                isLoading = false
                return
            }

            Logger.debug("Origin: \(origin), Request ID: \(requestId)")


            // Prompt the user to choose between registration and authentication
            DispatchQueue.main.async {
                actionSheetOrigin = origin
                actionSheetRequestId = requestId
                showActionSheet = true
                }
            }

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

            let state = await ASCredentialIdentityStore.shared.state()
            if !state.isEnabled {
                DispatchQueue.main.async {
                    self.scannedMessage = nil
                    self.errorMessage = "AutoFill Passwords & Passkeys is not enabled for Liquid Auth. Please enable it in Settings > General > AutoFill & Passwords."
                    self.isLoading = false
                }
                return
            }

            let verified = await requireUserVerification(reason: "Please verify your identity to continue")
            guard verified else {
                errorMessage = "User verification failed or was cancelled."
                isLoading = false
                return
            }

            let walletInfo = try getWalletInfo(origin: origin)
            let Ed25519Wallet = walletInfo.ed25519Wallet
            let DP256 = walletInfo.dp256
            let derivedMainKey = walletInfo.derivedMainKey
            let P256KeyPair = walletInfo.p256KeyPair
            let address = walletInfo.address

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
            Logger.debug("Response data: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
            if let cookie = sessionCookie {
                Logger.debug("Session cookie: \(cookie)")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                let challengeBase64Url = json["challenge"] as? String else {
                throw NSError(domain: "com.liquidauth.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response JSON or find the challenge field."])
            }

            Logger.debug("Challenge (Base64): \(challengeBase64Url)")
            Logger.debug("Challenge Decoded: \([UInt8](Utility.decodeBase64Url(challengeBase64Url)!))")
            Logger.debug("Challenge JSON: \(Utility.decodeBase64UrlToJSON(challengeBase64Url) ?? "nil")")

            // Validate and sign the challenge
            let schema = try Schema(filePath: Bundle.main.path(forResource: "auth.request", ofType: "json")!)
            let valid = try Ed25519Wallet.validateData(data: Data(Utility.decodeBase64UrlToJSON(challengeBase64Url)!.utf8), metadata: SignMetadata(encoding: Encoding.none, schema: schema))

            guard valid == true else {
                throw NSError(domain: "com.liquidauth.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Data is not valid"])
            }

            let sig = try Ed25519Wallet.rawSign(
                bip44Path: [UInt32(0x8000_0000) + 44, UInt32(0x8000_0000) + 283, UInt32(0x8000_0000) + 0, 0, 0],
                message: Data([UInt8](Utility.decodeBase64Url(challengeBase64Url)!)),
                derivationType: BIP32DerivationType.Peikert
            )

            Logger.debug("Signature: \(sig.base64URLEncodedString())")
            Logger.debug("Signature Length (Raw Bytes): \(sig.count)")

            // Create the Liquid extension JSON object
            let liquidExt = createLiquidExt(
                requestId: requestId,
                address: address,
                signature: sig.base64URLEncodedString()
            )
            Logger.debug("Created liquidExt JSON object: \(liquidExt)")

            // Deterministic ID - derived from P256 Public Key
            let rawId = Data([UInt8](Utility.hashSHA256(P256KeyPair.publicKey.rawRepresentation)))
            Logger.debug("Created rawId: \(rawId.map { String(format: "%02hhx", $0) }.joined())")

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
            Logger.debug("Created clientDataJSON: \(clientDataJSONBase64Url)")

            // Create attestationObject
            let attestedCredData = Utility.getAttestedCredentialData(aaguid: UUID(uuidString: "1F59713A-C021-4E63-9158-2CC5FDC14E52")!, credentialId: rawId, publicKey: P256KeyPair.publicKey.rawRepresentation)
            Logger.debug("created attestedCredData: \(attestedCredData.count)")

            let rpIdHash = Utility.hashSHA256(origin.data(using: .utf8)!)
            let authData = AuthenticatorData.attestation(
                rpIdHash: rpIdHash,
                userPresent: true,
                userVerified: true,
                signCount: 0,
                attestedCredentialData: attestedCredData,
                extensions: nil
            )
            Logger.debug("created authData: \(authData)")

            let attObj: [String: Any] = [
                "fmt": "none",
                "attStmt": [:],
                "authData": authData.toData()
            ]

            let cborEncoded = try CBOR.encodeMap(attObj)
            let attestationObject = Data(cborEncoded)
            Logger.debug("Created attestationobject: \(attestationObject.base64URLEncodedString())")

            let credential: [String: Any] = [
                "id": rawId.base64URLEncodedString(),
                "type": "public-key",
                "rawId": rawId.base64URLEncodedString(),
                "response": [
                    "clientDataJSON": clientDataJSONBase64Url,
                    "attestationObject": attestationObject.base64URLEncodedString()
                ]
            ]
            Logger.debug("Created credential: \(credential)")

            // Post attestation result
            let responseData = try await attestationApi.postAttestationResult(
                origin: origin,
                userAgent: Utility.getUserAgent(),
                credential: credential,
                liquidExt: liquidExt
            )

            // Handle the server response
            let responseString = String(data: responseData, encoding: .utf8) ?? "Invalid response"
            Logger.info("Attestation result posted: \(responseString)")

            // Parse the response to check for errors
            if let responseJSON = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
            let errorReason = responseJSON["error"] as? String {
                // If an error exists, propagate it
                Logger.error("Registration failed: \(errorReason)")
                errorMessage = "Registration failed: \(errorReason)"
                scannedMessage = nil
            } else {
                // If no error, handle success
                scannedMessage = "Registration completed successfully."
                Logger.info("Registration completed successfully.")
                errorMessage = nil

                // Passkey Identity Creation
                Logger.info("Creating passkey identity...")
                savePasskeyIdentity(
                    relyingPartyIdentifier: origin,
                    userName: address,
                    credentialID: rawId
                )

                startSignaling(origin: origin, requestId: requestId, walletInfo: walletInfo)
            }

        } catch {
            Logger.error("Error in register: \(error)")
            errorMessage = "Failed to handle Liquid Auth URI Registration flow: \(error.localizedDescription)"
        }
    }


    private func authenticate(origin: String, requestId: String) async {
        do {

            defer { 
                isLoading = false
            }

            let verified = await requireUserVerification(reason: "Please verify your identity to continue")
            guard verified else {
                errorMessage = "User verification failed or was cancelled."
                isLoading = false
                return
            }
            
            let walletInfo = try getWalletInfo(origin: origin)
            let Ed25519Wallet = walletInfo.ed25519Wallet
            let DP256 = walletInfo.dp256
            let derivedMainKey = walletInfo.derivedMainKey
            let P256KeyPair = walletInfo.p256KeyPair
            let address = walletInfo.address

            let userAgent = Utility.getUserAgent()
            
            let assertionApi = AssertionApi()

            let credentialId = Data([UInt8](Utility.hashSHA256(P256KeyPair.publicKey.rawRepresentation))).base64URLEncodedString()

            // Call postAssertionOptions
            let (data, sessionCookie) = try await assertionApi.postAssertionOptions(
                origin: origin,
                userAgent: userAgent,
                credentialId: credentialId
            )

            // Handle the response
            if let sessionCookie = sessionCookie {
                Logger.debug("Session cookie: \(sessionCookie)")
                // Store or use the session cookie as needed
            }

                // Parse the response data
            guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let challengeBase64Url = json["challenge"] as? String,
                  let _ = json["allowCredentials"] as? [[String: Any]],
                  let _ = json["rpId"] as? String else {
                throw NSError(domain: "Missing required fields in response", code: -1, userInfo: nil)
            }
            
            Logger.debug("Response: \(String(describing: String(data: data, encoding: .utf8)))")

            Logger.debug("Challenge (Base64): \(challengeBase64Url)")
            Logger.debug("Challenge Decoded: \([UInt8](Utility.decodeBase64Url(challengeBase64Url)!))")
            Logger.debug("Challenge JSON: \(Utility.decodeBase64UrlToJSON(challengeBase64Url) ?? "nil")")

            // Validate and sign the challenge
            let schema = try Schema(filePath: Bundle.main.path(forResource: "auth.request", ofType: "json")!)
            let valid = try Ed25519Wallet.validateData(data: Data(Utility.decodeBase64UrlToJSON(challengeBase64Url)!.utf8), metadata: SignMetadata(encoding: Encoding.none, schema: schema))

            guard valid == true else {
                throw NSError(domain: "com.liquidauth.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Data is not valid"])
            }

            let sig = try Ed25519Wallet.rawSign(
                bip44Path: [UInt32(0x8000_0000) + 44, UInt32(0x8000_0000) + 283, UInt32(0x8000_0000) + 0, 0, 0],
                message: Data([UInt8](Utility.decodeBase64Url(challengeBase64Url)!)),
                derivationType: BIP32DerivationType.Peikert
            )

            Logger.debug("Signature: \(sig.base64URLEncodedString())")
            Logger.debug("Signature Length (Raw Bytes): \(sig.count)")
            
            // Create the Liquid extension JSON object
            let liquidExt = createLiquidExt(
                requestId: requestId,
                address: address,
                signature: sig.base64URLEncodedString()
            )
            Logger.debug("Created liquidExt JSON object: \(liquidExt)")

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
            Logger.debug("Created clientDataJSON: \(clientDataJSONBase64Url)")

            let rpIdHash = Utility.hashSHA256(origin.data(using: .utf8)!)
            let authenticatorData = AuthenticatorData.assertion(
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

            Logger.debug("Created assertion response: \(assertionResponse)")

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
            Logger.info("Assertion result posted: \(responseString)")

            // Parse the response to check for errors
            if let responseJSON = try? JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
            let errorReason = responseJSON["error"] as? String {
                Logger.error("Authentication failed: \(errorReason)")
                errorMessage = "Authentication failed: \(errorReason)"
                scannedMessage = nil
            } else {
                scannedMessage = "Authentication completed successfully."
                Logger.info("Authentication completed successfully.")
                errorMessage = nil

                startSignaling(origin: origin, requestId: requestId, walletInfo: walletInfo)
            }

        } catch {
            Logger.error("Error in authenticate: \(error)")
            errorMessage = "Failed to retrieve authentication options: \(error.localizedDescription)"
        }
    }

    private func startSignaling(origin: String, requestId: String, walletInfo: WalletInfo) {
        let signalService = SignalService.shared
        
        signalService.start(url: origin, httpClient: URLSession.shared)

        let NODELY_TURN_USERNAME = "liquid-auth"
        let NODELY_TURN_CREDENTIAL = "sqmcP4MiTKMT4TGEDSk9jgHY"

        let iceServers = [
            RTCIceServer(
                urlStrings: [
                    "stun:stun.l.google.com:19302",
                    "stun:stun1.l.google.com:19302",
                    "stun:stun2.l.google.com:19302",
                    "stun:stun3.l.google.com:19302",
                    "stun:stun4.l.google.com:19302"
                ]
            ),
            RTCIceServer(
                urlStrings: [
                    "turn:global.turn.nodely.network:80?transport=tcp",
                    "turns:global.turn.nodely.network:443?transport=tcp",
                    "turn:eu.turn.nodely.io:80?transport=tcp",
                    "turns:eu.turn.nodely.io:443?transport=tcp",
                    "turn:us.turn.nodely.io:80?transport=tcp",
                    "turns:us.turn.nodely.io:443?transport=tcp"
                ],
                username: NODELY_TURN_USERNAME,
                credential: NODELY_TURN_CREDENTIAL
            ),
        ]
        
        Task {
            signalService.connectToPeer(
                requestId: requestId,
                type: "answer",
                origin: origin,
                iceServers: iceServers,
                onMessage: { message in
                    Logger.info("💬 Received message: \(message)")

                    var displayMessage: String
                    
                    if let decoded = Utility.decodeBase64UrlCBORIfPossible(message) {
                        displayMessage = "Decoded: \(decoded)"
                        Logger.info("Decoded message: \(decoded)")
                    } else {
                        displayMessage = message
                    }

                    if let arc27Response = handleArc27Message(message, ed25519Wallet: walletInfo.ed25519Wallet) {
                        signalService.sendMessage(arc27Response)
                    }

                    DispatchQueue.main.async {
                        self.scannedMessage = displayMessage
                    }
                },
                onStateChange: { state in
                    if state == "open" {
                        Logger.info("✅ Data channel is OPEN")
                        signalService.sendMessage("ping")
                    }
                }
            )
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

private struct WalletInfo {
    let ed25519Wallet: XHDWalletAPI
    let dp256: DeterministicP256
    let derivedMainKey: Data
    let p256KeyPair: P256.Signing.PrivateKey
    let address: String
}

private func getWalletInfo(origin: String) throws -> WalletInfo {
    let phrase = "salon zoo engage submit smile frost later decide wing sight chaos renew lizard rely canal coral scene hobby scare step bus leaf tobacco slice"
    let seed = try Mnemonic.deterministicSeedString(from: phrase)
    guard let ed25519Wallet = XHDWalletAPI(seed: seed) else {
        throw NSError(domain: "Wallet creation failed", code: -1, userInfo: nil)
    }

    let pk = try ed25519Wallet.keyGen(context: KeyContext.Address, account: 0, change: 0, keyIndex: 0)
    let address = try Utility.encodeAddress(bytes: pk)

    let dp256 = DeterministicP256()
    let derivedMainKey = try dp256.genDerivedMainKeyWithBIP39(phrase: phrase)
    let p256KeyPair = dp256.genDomainSpecificKeyPair(derivedMainKey: derivedMainKey, origin: "https://\(origin)", userHandle: address)

    return WalletInfo(
        ed25519Wallet: ed25519Wallet,
        dp256: dp256,
        derivedMainKey: derivedMainKey,
        p256KeyPair: p256KeyPair,
        address: address
    )
}

private func handleArc27Message(_ message: String, ed25519Wallet: XHDWalletAPI) -> String? {
    // 1. Decode base64url CBOR using Utility
    guard let cborData = Utility.decodeBase64Url(message),
          let cbor = try? CBOR.decode([UInt8](cborData)),
          let dict = (cbor.asSwiftObject() as? [String: Any]) else {
        Logger.error("Failed to decode CBOR or convert to dictionary")
        return nil
    }

    // 2. Check reference and extract fields
    guard let reference = dict["reference"] as? String,
          reference == "arc0027:sign_transactions:request",
          let params = dict["params"] as? [String: Any],
          let txns = params["txns"] as? [[String: Any]],
          let requestId = dict["id"] as? String else {
        Logger.error("Invalid ARC27 request format")
        return nil
    }

    // Verify user identity
    var userVerified = false
    let semaphore = DispatchSemaphore(value: 0)
    DispatchQueue.main.async {
        Task {
            userVerified = await requireUserVerification(reason: "Approve transaction signing")
            semaphore.signal()
        }
    }
    semaphore.wait()
    guard userVerified else {
        Logger.error("User verification failed or cancelled.")
        return nil
    }

    // 3. Sign each transaction
    var signedTxns: [String] = []
    for txnObj in txns {
        guard let txnBase64Url = txnObj["txn"] as? String,
              let txnBytes = Utility.decodeBase64Url(txnBase64Url) else {
            Logger.error("Failed to decode transaction base64url")
            continue
        }

        // TODO: Handle different transaction types if needed
        // Handle using a Swift-based Algorand SDK
        let prefix = Data([0x54, 0x58]) // "TX"
        let bytesToSign = prefix + txnBytes

        Logger.debug("Signing transaction: \(txnBase64Url)")
        Logger.debug("Signing transaction: \(bytesToSign.map { String(format: "%02hhx", $0) }.joined())")

        // Sign the transaction bytes with Ed25519
        guard let signature = try? ed25519Wallet.rawSign(
            bip44Path: [UInt32(0x8000_0000) + 44, UInt32(0x8000_0000) + 283, UInt32(0x8000_0000) + 0, 0, 0],
            message: bytesToSign,
            derivationType: BIP32DerivationType.Peikert
        ) else {
            Logger.error("Failed to sign transaction")
            continue
        }

        let sigBase64Url = signature.base64URLEncodedString()
        signedTxns.append(sigBase64Url)
    }

    // 4. Build response object
    let response: [String: Any] = [
        "id": UUID().uuidString,
        "reference": "arc0027:sign_transactions:response",
        "requestId": requestId,
        "result": [
            "providerId": params["providerId"] ?? "liquid-auth-ios",
            "stxns": signedTxns
        ]
    ]

    // 5. CBOR encode and base64url encode
    guard let cborResponse = try? CBOR.encodeMap(response) else {
        Logger.error("Failed to CBOR encode response")
        return nil
    }
    let base64urlResponse = Data(cborResponse).base64URLEncodedString()
    return base64urlResponse
}

private func savePasskeyIdentity(
    relyingPartyIdentifier: String,
    userName: String,
    credentialID: Data
) {
    let passkeyIdentity = ASPasskeyCredentialIdentity(
        relyingPartyIdentifier: relyingPartyIdentifier,
        userName: userName,
        credentialID: credentialID,
        userHandle: Data(SHA256.hash(data: Data(userName.utf8)))
    )

    ASCredentialIdentityStore.shared.saveCredentialIdentities([passkeyIdentity]) { success, error in
        if success {
            Logger.info("✅ Passkey identity saved to identity store!")
        } else if let error = error {
            Logger.error("❌ Failed to save passkey identity: \(error)")
        }
    }
}

func requireUserVerification(reason: String = "Authenticate to continue") async -> Bool {
    let context = LAContext()
    var error: NSError?
    let policy: LAPolicy = .deviceOwnerAuthentication // biometrics OR passcode

    if context.canEvaluatePolicy(policy, error: &error) {
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    } else {
        // Device does not support biometrics/passcode
        return false
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
