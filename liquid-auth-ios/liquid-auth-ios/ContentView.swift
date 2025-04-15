import SwiftUI
import AVFoundation

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
    }
}

#Preview {
    ContentView()
}
