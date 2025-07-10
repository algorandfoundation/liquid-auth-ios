//
//  CredentialProviderViewController.swift
//  Liquid Auth
//
//  Created by Algorand Foundation on 2025-05-27.
//

import AuthenticationServices
import SwiftUI

class CredentialProviderViewController: ASCredentialProviderViewController {
    // Store the incoming service identifiers for use in SwiftUI
    var serviceIdentifiers: [ASCredentialServiceIdentifier] = []

    // The SwiftUI view controller
    private var hostingController: UIHostingController<CredentialListView>?

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        self.serviceIdentifiers = serviceIdentifiers

        // Print out the incoming credential requests
        for identifier in serviceIdentifiers {
            print("Credential request for: \(identifier.identifier) (type: \(identifier.type.rawValue))")
        }

        // Show the SwiftUI view
        let view = CredentialListView(serviceIdentifiers: serviceIdentifiers, onCancel: { [weak self] in
            self?.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
        })
        if let hostingController = hostingController {
            hostingController.rootView = view
        } else {
            let hc = UIHostingController(rootView: view)
            self.hostingController = hc
            self.present(hc, animated: true, completion: nil)
        }
    }

    // Required for QuickType bar (not used in MVP)
    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        // No credentials to provide in MVP
        self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
    }

    // Optional: handle cancel from UI
    @IBAction func cancel(_ sender: AnyObject?) {
        self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
    }
}
