//
//  ContentView.swift
//  liquid-auth-ios
//
//  Created by Yared Efrem Afework on 2025-04-11.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var isScanning = false

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
                    print("Scanned QR Code: \(scannedCode)")
                    isScanning = false
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
