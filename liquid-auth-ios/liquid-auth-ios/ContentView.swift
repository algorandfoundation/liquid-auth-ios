import SwiftUI
import AVFoundation
import UIKit

struct ContentView: View {
    @State private var isScanning = false
    @State private var scannedMessage: String? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
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
                    handleScannedCode(scannedCode)
                    isScanning = false
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
                register(origin: origin, requestId: requestId)
            }
            // TODO: If yes, authenticate with the credential
            
        } else {
            print("Failed to extract origin and request ID.")
        }
    }

    private func register(origin: String, requestId: String) {
        // Get the appropriate Algorand wallet address
        let address = "ABC"

        // Construct the options JSON object
        
        let attestationApi = AttestationApi()
        let options: [String: Any] = [
            "username": address,
            "displayName": "Liquid Auth User",
            "authenticatorSelection": ["userVerification": "required"],
            "extensions": ["liquid": true]
        ]
        let userAgent = Utility.getUserAgent()

        attestationApi.postAttestationOptions(origin: origin, userAgent: userAgent, options: options) { result in
            switch result {
            case .success(let (data, sessionCookie)):
                print("Response data: \(String(data: data, encoding: .utf8) ?? "Invalid data")")
                if let cookie = sessionCookie {
                    print("Session cookie: \(cookie)")
                }
            case .failure(let error):
                print("Error: \(error)")
            }
        }
        
    }
}

#Preview {
    ContentView()
}
