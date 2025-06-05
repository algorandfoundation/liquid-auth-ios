import SwiftUI
import AuthenticationServices

struct CredentialListView: View {
    let serviceIdentifiers: [ASCredentialServiceIdentifier]
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack {
                Text("Credential Request")
                    .font(.title)
                    .padding(.top)
                if serviceIdentifiers.isEmpty {
                    Text("No service identifiers received.")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(serviceIdentifiers, id: \.identifier) { identifier in
                        VStack(alignment: .leading) {
                            Text(identifier.identifier)
                                .font(.headline)
                            Text("Type: \(identifier.type.rawValue)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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