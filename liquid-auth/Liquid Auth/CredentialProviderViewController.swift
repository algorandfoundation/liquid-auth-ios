import AuthenticationServices
import UIKit
import CryptoKit
import deterministicP256_swift
import LocalAuthentication
import x_hd_wallet_api
import MnemonicSwift
import SwiftCBOR

class CredentialProviderViewController: ASCredentialProviderViewController {
    // Registration flow
    override func prepareInterface(forPasskeyRegistration request: ASCredentialRequest) {
        guard let passkeyRequest = request as? ASPasskeyCredentialRequest else { return }
        Task {
            // 1. Always get user consent first
            let consent = await presentUserConsentAlert(
                title: "Register Passkey",
                message: "Do you want to register a new passkey for this site?"
            )
            guard consent else {
                self.extensionContext.cancelRequest(withError: NSError(domain: "User cancelled", code: -1))
                return
            }
            do {
                // 2. Only after consent, check for excluded credentials
                let credential = try await createRegistrationCredential(for: passkeyRequest)
                self.completeRegistrationRequest(credential)//, userHandle: passkeyRequest.credentialIdentity.user)
            } catch let error as NSError {
                // 3. If error is due to excluded credential, delay before returning
                if error.domain == "Credential already exists for this site" {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                }
                self.extensionContext.cancelRequest(withError: error)
            }
        }
    }

    // Authentication flow
    override func prepareInterfaceToProvideCredential(for request: ASCredentialRequest) {
        guard let passkeyRequest = request as? ASPasskeyCredentialRequest else { return }
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
                let credential = try await createAssertionCredential(for: passkeyRequest)
                self.completeAssertionRequest(credential)
            } catch {
                self.extensionContext.cancelRequest(withError: error)
            }
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

    func completeRegistrationRequest(_ credential: ASPasskeyRegistrationCredential){//, userHandle: String) {
        extensionContext.completeRegistrationRequest(using: credential)
        // Save the credential identity after successful registration
        // savePasskeyIdentity(
        //     relyingPartyIdentifier: credential.relyingParty,
        //     userName: userHandle,
        //     credentialID: credential.credentialID,
        //     userHandle: Data(userHandle.utf8)
        // )
    }

    func completeAssertionRequest(_ credential: ASPasskeyAssertionCredential) {
        extensionContext.completeAssertionRequest(using: credential)
    }

    // Registration
    private func createRegistrationCredential(for request: ASPasskeyCredentialRequest) async throws -> ASPasskeyRegistrationCredential {
        guard let credentialIdentity = request.credentialIdentity as? ASPasskeyCredentialIdentity else {
            throw NSError(domain: "Missing credential identity", code: -1)
        }

        // --- DEBUG: Show all available WebAuthn request info ---
        let supportedAlgs = request.supportedAlgorithms.map { "\($0.rawValue)" }.joined(separator: ", ")
        let userVerification = request.userVerificationPreference.rawValue
        let clientDataHashHex = request.clientDataHash.map { String(format: "%02x", $0) }.joined()
        let rpId = credentialIdentity.relyingPartyIdentifier
        let userName = credentialIdentity.userName
        let userHandle = credentialIdentity.userHandle.base64EncodedString()
        let credentialIdentityID = credentialIdentity.credentialID.base64EncodedString()
        let excludeList = request.excludedCredentials?.map { $0.credentialID.base64EncodedString() }.joined(separator: ", ") ?? "none"

        // await presentDebugAlert(
        //     title: "Passkey Request Info",
        //     message: """
        //     supportedAlgorithms: \(supportedAlgs)
        //     userVerificationPreference: \(userVerification)
        //     clientDataHash: \(clientDataHashHex)
        //     relyingPartyIdentifier: \(rpId)
        //     userName: \(userName)
        //     userHandle: \(userHandle)
        //     credentialID(Identity): \(credentialIdentityID)
        //     excludedCredentials: \(excludeList)
        //     """
        //     )

        let origin = credentialIdentity.relyingPartyIdentifier
        let clientDataHash = request.clientDataHash
        //let userHandle = String(data: credentialIdentity.userHandle, encoding: .utf8) ?? ""

        let walletInfo = try getWalletInfo(origin: origin)//, userHandle: userHandle)
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
        // -------------------------------

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
            signCount: 0,
            attestedCredentialData: attestedCredData,
            extensions: nil
        ).toData()

        let attObj: [String: Any] = [
            "fmt": "none",
            "attStmt": [:],
            "authData": authData
        ]
        let cborEncoded = try CBOR.encodeMap(attObj)
        let attestationObject = Data(cborEncoded)
        // -------------------------------

        return ASPasskeyRegistrationCredential(
            relyingParty: origin,
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
        //let userHandle = String(data: userHandleData, encoding: .utf8) ?? ""

        let walletInfo = try getWalletInfo(origin: origin)//, userHandle: userHandle)
        let credentialID = Data(Utility.hashSHA256(walletInfo.p256KeyPair.publicKey.rawRepresentation))
        let signature = try walletInfo.p256KeyPair.signature(for: request.clientDataHash)
        let sigData = signature.derRepresentation

        // Dummy authenticatorData for demo
        let authenticatorData = Data([0x01, 0x02, 0x03])

        return ASPasskeyAssertionCredential(
            userHandle: userHandleData,
            relyingParty: origin,
            signature: sigData,
            clientDataHash: request.clientDataHash,
            authenticatorData: authenticatorData,
            credentialID: credentialID
        )
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
                print("✅ Passkey identity saved to identity store!")
            } else if let error = error {
                print("❌ Failed to save passkey identity: \(error)")
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
        let p256KeyPair = dp256.genDomainSpecificKeyPair(derivedMainKey: derivedMainKey, origin: "https://\(origin)", userHandle: address)//userHandle)

        return WalletInfo(
            ed25519Wallet: ed25519Wallet,
            dp256: dp256,
            derivedMainKey: derivedMainKey,
            p256KeyPair: p256KeyPair,
            address: address
        )
    }
}
