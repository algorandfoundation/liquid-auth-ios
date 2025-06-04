import AuthenticationServices
import UIKit

class CredentialProviderViewController: ASCredentialProviderViewController {
    // Called for passkey creation (registration)
    override func prepareInterface(forPasskeyRegistration request: ASCredentialRequest) {
        let alert = UIAlertController(title: "Liquid Auth", message: "Passkey Registration UI", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            // You would create your passkey credential here and call completeRegistrationRequest
            self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
        })
        self.present(alert, animated: true, completion: nil)
    }

    // Called for passkey assertion (sign-in)
    override func prepareInterfaceToProvideCredential(for request: ASCredentialRequest) {
        let alert = UIAlertController(title: "Liquid Auth", message: "Passkey Sign-in UI", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            // You would provide your passkey credential here and call completeRequest
            self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
        })
        self.present(alert, animated: true, completion: nil)
    }
}
// foundation.algorand.liquid-auth.Liquid-Auth