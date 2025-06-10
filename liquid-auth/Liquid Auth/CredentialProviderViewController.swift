import AuthenticationServices
import UIKit
import CryptoKit
import deterministicP256_swift
import LocalAuthentication
import x_hd_wallet_api
import MnemonicSwift

class CredentialProviderViewController: ASCredentialProviderViewController {
    // Registration flow
    override func prepareInterface(forPasskeyRegistration request: ASCredentialRequest) {
        guard let passkeyRequest = request as? ASPasskeyCredentialRequest else { return }
        Task {
            do {
                let credential = try await createRegistrationCredential(for: passkeyRequest)
                self.completeRegistrationRequest(credential)
            } catch {
                self.extensionContext.cancelRequest(withError: error)
            }
        }
    }

    // Authentication flow
    override func prepareInterfaceToProvideCredential(for request: ASCredentialRequest) {
        guard let passkeyRequest = request as? ASPasskeyCredentialRequest else { return }
        Task {
            do {
                let credential = try await createAssertionCredential(for: passkeyRequest)
                self.completeAssertionRequest(credential)
            } catch {
                self.extensionContext.cancelRequest(withError: error)
            }
        }
    }

    func completeRegistrationRequest(_ credential: ASPasskeyRegistrationCredential) {
        extensionContext.completeRegistrationRequest(using: credential)
    }

    func completeAssertionRequest(_ credential: ASPasskeyAssertionCredential) {
        extensionContext.completeAssertionRequest(using: credential)
    }

    // Registration
    private func createRegistrationCredential(for request: ASPasskeyCredentialRequest) async throws -> ASPasskeyRegistrationCredential {
        guard let credentialIdentity = request.credentialIdentity as? ASPasskeyCredentialIdentity else {
            throw NSError(domain: "Missing credential identity", code: -1)
        }
        let origin = credentialIdentity.relyingPartyIdentifier

        let clientDataHash = request.clientDataHash

        let walletInfo = try getWalletInfo(origin: origin)
        let pubkey = walletInfo.p256KeyPair.publicKey.rawRepresentation
        let credentialID = Data(Utility.hashSHA256(pubkey))

        // Dummy attestation for demo
        let attestationObject = Data([0xA1, 0x01, 0x02])

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
        let userHandle = credentialIdentity.userHandle

        let walletInfo = try getWalletInfo(origin: origin)
        let credentialID = Data(Utility.hashSHA256(walletInfo.p256KeyPair.publicKey.rawRepresentation))
        let signature = try walletInfo.p256KeyPair.signature(for: request.clientDataHash)
        let sigData = signature.derRepresentation

        // Dummy authenticatorData for demo
        let authenticatorData = Data([0x01, 0x02, 0x03])

        return ASPasskeyAssertionCredential(
            userHandle: userHandle,
            relyingParty: origin,
            signature: sigData,
            clientDataHash: request.clientDataHash,
            authenticatorData: authenticatorData,
            credentialID: credentialID
        )
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
        let p256KeyPair = dp256.genDomainSpecificKeyPair(derivedMainKey: derivedMainKey, origin: "https://\(origin)", userHandle: address)

        return WalletInfo(
            ed25519Wallet: ed25519Wallet,
            dp256: dp256,
            derivedMainKey: derivedMainKey,
            p256KeyPair: p256KeyPair,
            address: address
        )
    }
}
