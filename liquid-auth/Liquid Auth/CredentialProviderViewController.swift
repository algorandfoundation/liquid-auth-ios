import AuthenticationServices
import CryptoKit
import deterministicP256_swift
import LocalAuthentication
import MnemonicSwift
import SwiftCBOR
import UIKit
import x_hd_wallet_api

class CredentialProviderViewController: ASCredentialProviderViewController {
    private var tableDataSource: UITableViewDataSource?
    private var tableDelegate: UITableViewDelegate?

    // Registration flow
    override func prepareInterface(forPasskeyRegistration request: ASCredentialRequest) {
        if #available(iOSApplicationExtension 17.0, *) {
            guard let passkeyRequest = request as? ASPasskeyCredentialRequest else { return }
            Task {
                let consent = await presentUserConsentAlert(
                    title: "Register Passkey",
                    message: "Do you want to register a new passkey for this site?"
                )
                guard consent else {
                    self.extensionContext.cancelRequest(withError: NSError(domain: "User cancelled", code: -1))
                    return
                }
                do {
                    let credential = try await createRegistrationCredential(for: passkeyRequest)
                    // Save userHandle for this RP
                    if let passkeyIdentity = passkeyRequest.credentialIdentity as? ASPasskeyCredentialIdentity,
                       let userHandle = String(data: passkeyIdentity.userHandle, encoding: .utf8)
                    {
                        saveRegisteredUserHandle(userHandle, forRP: passkeyIdentity.relyingPartyIdentifier)
                    }
                    await extensionContext.completeRegistrationRequest(using: credential)
                } catch let error as NSError {
                    if error.domain == "Credential already exists for this site" {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                    }
                    self.extensionContext.cancelRequest(withError: error)
                }
            }
        } else {
            extensionContext.cancelRequest(withError: NSError(domain: "Passkeys require iOS 17+", code: -1))
        }
    }

    override func prepareCredentialList(
        for serviceIdentifiers: [ASCredentialServiceIdentifier],
        requestParameters: ASPasskeyCredentialRequestParameters
    ) {
        var credentials: [ASPasskeyAssertionCredential] = []

        if serviceIdentifiers.isEmpty {
            // Use relyingPartyIdentifier from requestParameters
            let origin = requestParameters.relyingPartyIdentifier
            if let walletInfo = try? getWalletInfo(origin: origin) {
                let credentialID = Data(Utility.hashSHA256(walletInfo.p256KeyPair.publicKey.rawRepresentation))
                let userHandleData = Data(walletInfo.address.utf8)
                let clientDataHash = requestParameters.clientDataHash

                // Authenticator data
                let rpIdHash = Utility.hashSHA256(origin.data(using: .utf8)!)
                let authenticatorData = AuthenticatorData.assertion(
                    rpIdHash: rpIdHash,
                    userPresent: true,
                    userVerified: true,
                    backupEligible: true,
                    backupState: true,
                    signCount: 0
                ).toData()

                // Signature: sign authenticatorData || clientDataHash
                let dataToSign = authenticatorData + clientDataHash
                let signature: Data
                do {
                    signature = try walletInfo.p256KeyPair.signature(for: dataToSign).derRepresentation
                } catch {
                    NSLog("Failed to sign assertion: \(error)")
                    signature = Data()
                }

                let credential = ASPasskeyAssertionCredential(
                    userHandle: userHandleData,
                    relyingParty: origin,
                    signature: signature,
                    clientDataHash: clientDataHash,
                    authenticatorData: authenticatorData,
                    credentialID: credentialID
                )
                credentials.append(credential)
            }
        } else {
            credentials = fetchCredentials(for: serviceIdentifiers)
        }

        presentCredentialSelectionUI(credentials: credentials) { [weak self] selectedCredential in
            Task {
                if let credential = selectedCredential {
                    await self?.extensionContext.completeAssertionRequest(using: credential)
                } else {
                    self?.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.Code.userCanceled.rawValue))
                }
            }
        }
    }

    // Authentication flow
    override func prepareInterfaceToProvideCredential(for request: ASCredentialRequest) {
        if #available(iOSApplicationExtension 17.0, *) {
            guard let passkeyRequest = request as? ASPasskeyCredentialRequest,
                  let credentialIdentity = passkeyRequest.credentialIdentity as? ASPasskeyCredentialIdentity else { return }
            Task {
                let consent = await presentUserConsentAlert(
                    title: "Use Passkey",
                    message: "Do you want to use your passkey to sign in?"
                )
                guard consent else {
                    self.extensionContext.cancelRequest(withError: NSError(domain: "User cancelled", code: -1))
                    return
                }
                do {
                    let credential: ASPasskeyAssertionCredential = try await createAssertionCredential(for: passkeyRequest)
                    await extensionContext.completeAssertionRequest(using: credential)
                } catch {
                    self.extensionContext.cancelRequest(withError: error)
                }
            }
        } else {
            extensionContext.cancelRequest(withError: NSError(domain: "Passkeys require iOS 17+", code: -1))
        }
    }

    func presentUserConsentAlert(title: String, message: String) async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
                continuation.resume(returning: true)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            // Present on the main thread
            DispatchQueue.main.async {
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    private func presentDebugAlert(title: String, message: String) async {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                continuation.resume()
            })
            DispatchQueue.main.async {
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    // Registration
    private func createRegistrationCredential(for request: ASPasskeyCredentialRequest) async throws -> ASPasskeyRegistrationCredential {
        guard let credentialIdentity = request.credentialIdentity as? ASPasskeyCredentialIdentity else {
            throw NSError(domain: "Missing credential identity", code: -1)
        }

        let origin = credentialIdentity.relyingPartyIdentifier
        let clientDataHash = request.clientDataHash

        let walletInfo = try getWalletInfo(origin: origin) // , userHandle: userHandle)
        let pubkey = walletInfo.p256KeyPair.publicKey.rawRepresentation
        let credentialID = Data([UInt8](Utility.hashSHA256(pubkey)))

        // --- ExcludeCredentials check ---
        if let excludedCredentials = request.excludedCredentials {
            for excluded in excludedCredentials {
                if excluded.credentialID == credentialID {
                    // Optionally show a UI to the user here
                    let shouldCancel = await presentCredentialExistsAlert()
                    if shouldCancel {
                        // Throw error as before; delay is handled in prepareInterface
                        throw NSError(domain: "Credential already exists for this site", code: -2)
                    }
                }
            }
        }

        // --- Build attestationObject ---
        let aaguid = UUID(uuidString: "1F59713A-C021-4E63-9158-2CC5FDC14E52")!
        let attestedCredData = Utility.getAttestedCredentialData(
            aaguid: aaguid,
            credentialId: credentialID,
            publicKey: pubkey
        )

        let rpIdHash = Utility.hashSHA256(origin.data(using: .utf8)!)

        let authData = AuthenticatorData.attestation(
            rpIdHash: rpIdHash,
            userPresent: true,
            userVerified: true,
            backupEligible: true,
            backupState: true,
            signCount: 0,
            attestedCredentialData: attestedCredData,
            extensions: nil
        ).toData()

        let attObj: [String: CBOR] = [
            "attStmt": CBOR.map([:]),
            "authData": CBOR.byteString([UInt8](authData)),
            "fmt": CBOR.utf8String("none"),
        ]
        let cborEncoded = try CBOR.encode(attObj)
        let attestationObject = Data(cborEncoded)

        return ASPasskeyRegistrationCredential(
            relyingParty: credentialIdentity.relyingPartyIdentifier,
            clientDataHash: clientDataHash,
            credentialID: credentialID,
            attestationObject: attestationObject
        )
    }

    // Authentication
    private func createAssertionCredential(for request: ASPasskeyCredentialRequest) async throws -> ASPasskeyAssertionCredential {
        guard let credentialIdentity = request.credentialIdentity as? ASPasskeyCredentialIdentity else {
            throw NSError(domain: "Missing credential identity", code: -1)
        }
        let origin = credentialIdentity.relyingPartyIdentifier
        let userHandleData = credentialIdentity.userHandle

        let walletInfo = try getWalletInfo(origin: origin)
        let derivedCredentialID = Data(Utility.hashSHA256(walletInfo.p256KeyPair.publicKey.rawRepresentation))

        // Only present if the credentialID matches what the system is asking for
        guard derivedCredentialID == credentialIdentity.credentialID else {
            throw NSError(domain: "No matching credential found", code: -1)
        }

        let signature = try walletInfo.p256KeyPair.signature(for: request.clientDataHash)
        let sigData = signature.derRepresentation

        // Proper authenticatorData for assertion
        let rpIdHash = Utility.hashSHA256(origin.data(using: .utf8)!)
        let authenticatorData = AuthenticatorData.assertion(
            rpIdHash: rpIdHash,
            userPresent: true,
            userVerified: true,
            backupEligible: true,
            backupState: true,
            signCount: 0
        ).toData()

        return ASPasskeyAssertionCredential(
            userHandle: userHandleData,
            relyingParty: origin,
            signature: sigData,
            clientDataHash: request.clientDataHash,
            authenticatorData: authenticatorData,
            credentialID: derivedCredentialID
        )
    }

    private func fetchCredentials(for serviceIdentifiers: [ASCredentialServiceIdentifier]) -> [ASPasskeyAssertionCredential] {
        var credentials: [ASPasskeyAssertionCredential] = []

        for serviceIdentifier in serviceIdentifiers {
            let origin = serviceIdentifier.identifier
            guard let walletInfo = try? getWalletInfo(origin: origin) else { continue }
            let credentialID = Data(Utility.hashSHA256(walletInfo.p256KeyPair.publicKey.rawRepresentation))
            let userHandleData = Data(walletInfo.address.utf8) // or any deterministic value

            // Dummy values for preview
            let dummyClientDataHash = Data(repeating: 0, count: 32)
            let rpIdHash = Utility.hashSHA256(origin.data(using: .utf8)!)
            let authenticatorData = AuthenticatorData.assertion(
                rpIdHash: rpIdHash,
                userPresent: true,
                userVerified: true,
                backupEligible: true,
                backupState: true,
                signCount: 0
            ).toData()
            let dummySignature = Data(repeating: 0, count: 64)

            let credential = ASPasskeyAssertionCredential(
                userHandle: userHandleData,
                relyingParty: origin,
                signature: dummySignature,
                clientDataHash: dummyClientDataHash,
                authenticatorData: authenticatorData,
                credentialID: credentialID
            )
            credentials.append(credential)
        }
        return credentials
    }

    private func isCredentialIdentityRegistered(_ identity: ASPasskeyCredentialIdentity) async -> Bool {
        let store = ASCredentialIdentityStore.shared
        let identities = await store.credentialIdentities(
            forService: ASCredentialServiceIdentifier(identifier: identity.relyingPartyIdentifier, type: .domain),
            credentialIdentityTypes: [.passkey]
        )
        return identities.contains { $0 is ASPasskeyCredentialIdentity && ($0 as! ASPasskeyCredentialIdentity).credentialID == identity.credentialID }
    }

    private func savePasskeyIdentity(
        relyingPartyIdentifier: String,
        userName: String,
        credentialID: Data,
        userHandle: Data
    ) {
        let passkeyIdentity = ASPasskeyCredentialIdentity(
            relyingPartyIdentifier: relyingPartyIdentifier,
            userName: userName,
            credentialID: credentialID,
            userHandle: userHandle
        )
        ASCredentialIdentityStore.shared.saveCredentialIdentities([passkeyIdentity]) { success, error in
            if success {
                NSLog("✅ Passkey identity saved to identity store!")
            } else if let error = error {
                NSLog("❌ Failed to save passkey identity: \(error)")
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

    private func presentCredentialExistsAlert() async -> Bool {
        await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: "Credential Already Exists",
                message: "A passkey for this site already exists. Do you want to cancel registration?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel Registration", style: .destructive) { _ in
                continuation.resume(returning: true) // Cancel
            })
            alert.addAction(UIAlertAction(title: "Continue Anyway", style: .default) { _ in
                continuation.resume(returning: false) // Continue
            })
            DispatchQueue.main.async {
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

    private func saveRegisteredUserHandle(_ userHandle: String, forRP rp: String) {
        var dict = UserDefaults.standard.dictionary(forKey: "registeredUserHandles") as? [String: [String]] ?? [:]
        var handles = dict[rp] ?? []
        if !handles.contains(userHandle) {
            handles.append(userHandle)
            dict[rp] = handles
            UserDefaults.standard.set(dict, forKey: "registeredUserHandles")
        }
    }

    private func presentCredentialSelectionUI(
        credentials: [ASPasskeyAssertionCredential],
        completion: @escaping (ASPasskeyAssertionCredential?) -> Void
    ) {
        // If only one credential, auto-select it
        if credentials.count == 1 {
            completion(credentials.first)
            return
        }

        // Otherwise, present a simple table view for selection
        let tableVC = UITableViewController(style: .plain)
        tableVC.title = "Select Passkey"
        tableVC.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CredentialCell")

        // Store credentials locally for the data source/selection
        var selectedCredential: ASPasskeyAssertionCredential?
        let creds = credentials

        let dataSource = SimpleTableDataSource(
            credentials: creds,
            configure: { cell, credential in
                cell.textLabel?.text = credential.userHandle.base64EncodedString()
                cell.detailTextLabel?.text = credential.relyingParty
            }
        )
        let delegate = SimpleTableDelegate(
            credentials: creds,
            onSelect: { credential in
                selectedCredential = credential
                tableVC.dismiss(animated: true) {
                    completion(selectedCredential)
                }
            }
        )

        tableVC.tableView.dataSource = dataSource
        tableVC.tableView.delegate = delegate

        tableDataSource = dataSource
        tableDelegate = delegate

        // Present the table view controller modally
        let nav = UINavigationController(rootViewController: tableVC)
        DispatchQueue.main.async {
            self.present(nav, animated: true, completion: nil)
        }
    }

    // Helper classes for table view data source and delegate
    private class SimpleTableDataSource: NSObject, UITableViewDataSource {
        let credentials: [ASPasskeyAssertionCredential]
        let configure: (UITableViewCell, ASPasskeyAssertionCredential) -> Void

        init(credentials: [ASPasskeyAssertionCredential], configure: @escaping (UITableViewCell, ASPasskeyAssertionCredential) -> Void) {
            self.credentials = credentials
            self.configure = configure
        }

        func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
            return credentials.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CredentialCell", for: indexPath)
            let credential = credentials[indexPath.row]
            configure(cell, credential)
            return cell
        }
    }

    private class SimpleTableDelegate: NSObject, UITableViewDelegate {
        let credentials: [ASPasskeyAssertionCredential]
        let onSelect: (ASPasskeyAssertionCredential) -> Void

        init(credentials: [ASPasskeyAssertionCredential], onSelect: @escaping (ASPasskeyAssertionCredential) -> Void) {
            self.credentials = credentials
            self.onSelect = onSelect
        }

        func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
            let credential = credentials[indexPath.row]
            onSelect(credential)
        }
    }

    // prepareInterfaceForExtensionConfiguration()
    // Prepares the interface to enable the user to configure the extension.
    // The system calls this method after the user enables your extension in Settings.
    // Use this method to prepare a user interface for configuring the extension.

    // MARK: - Wallet Logic

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
        let p256KeyPair = dp256.genDomainSpecificKeyPair(derivedMainKey: derivedMainKey, origin: origin, userHandle: address)

        return WalletInfo(
            ed25519Wallet: ed25519Wallet,
            dp256: dp256,
            derivedMainKey: derivedMainKey,
            p256KeyPair: p256KeyPair,
            address: address
        )
    }
}
