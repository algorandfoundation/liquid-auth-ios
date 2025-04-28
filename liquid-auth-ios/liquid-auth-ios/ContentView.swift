import SwiftUI
import AVFoundation
import x_hd_wallet_api
import MnemonicSwift


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
            let seed = try Mnemonic.deterministicSeedString(from: "salon zoo engage submit smile frost later decide wing sight chaos renew lizard rely canal coral scene hobby scare step bus leaf tobacco slice")
            
            let wallet = XHDWalletAPI(seed: seed)
            
            guard let pk = try wallet?.keyGen(context: KeyContext.Address, account: 0, change: 0, keyIndex: 0) else {
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
                        let challengeBase64 = json["challenge"] as? String {
                            print("Challenge (Base64): \(challengeBase64)")
                            
                            do {
                                let schema = try Schema(filePath: "liquid-auth-ios/liquid-auth-ios/auth.request.json")
                                
                                let sig = try wallet?.signData(
                                    context: KeyContext.Address,
                                    account: 0,
                                    change: 0,
                                    keyIndex: 0,
                                    data: Utility.decodeBase64Url(challengeBase64)!,
                                    metadata: SignMetadata(customEncoding: Encoding.base64, customSchema: schema)
                                )
                                
                                print("Signature: " + "\(sig?.base64EncodedString() ?? "nil")")
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

#Preview {
    ContentView()
}
