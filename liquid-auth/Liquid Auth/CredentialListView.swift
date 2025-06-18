import SwiftUI
import AuthenticationServices

struct CredentialListView: View {
    let serviceIdentifiers: [ASCredentialServiceIdentifier]
    let credentials: [Credential]
    let onCancel: () -> Void
    let onProvide: (Credential) -> Void

    var body: some View {
        NavigationView {
            VStack {
                Text("Select a Credential")
                    .font(.title)
                    .padding(.top)
                if credentials.isEmpty {
                    Text("No credentials available.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(credentials) { credential in
                        Button(action: {
                            onProvide(credential)
                        }) {
                            VStack(alignment: .leading) {
                                Text(credential.username)
                                    .font(.headline)
                            }
                        }
                    }
                }
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .padding()
            }
            .navigationTitle("Liquid Auth")
        }
    }
}

struct Credential: Identifiable {
    let id: UUID = UUID()
    let username: String
    let password: String
}