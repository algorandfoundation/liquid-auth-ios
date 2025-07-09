import Foundation
import WebRTC

public class PeerApi {
    private let peerConnectionFactory: RTCPeerConnectionFactory
    var peerConnection: RTCPeerConnection?
    private var peerConnectionDelegate: PeerConnectionDelegate?
    private var dataChannel: RTCDataChannel?
    private let onDataChannel: (RTCDataChannel) -> Void
    private var dataChannelDelegates: [RTCDataChannel: DataChannelDelegate] = [:]
    private weak var signalService: SignalService?


    public init(
        iceServers: [RTCIceServer],
        poolSize: Int,
        signalService: SignalService?,
        onDataChannel: @escaping (RTCDataChannel) -> Void,
        onIceCandidate: @escaping (RTCIceCandidate) -> Void
        ){
        self.signalService = signalService
        self.onDataChannel = onDataChannel
        // Initialize the PeerConnectionFactory
        RTCPeerConnectionFactory.initialize()
        self.peerConnectionFactory = RTCPeerConnectionFactory()

        // Create the PeerConnection configuration
        let configuration = RTCConfiguration()
        configuration.iceServers = iceServers
        configuration.iceCandidatePoolSize = Int32(poolSize)
        configuration.sdpSemantics = .unifiedPlan
        configuration.continualGatheringPolicy = .gatherContinually

        let delegate = PeerConnectionDelegate(
                onIceCandidate: onIceCandidate,
                onDataChannel: onDataChannel,
                onConnectionStateChange: { state in
                    Logger.debug("PeerAPI: Peer connection state changed: \(state.rawValue)")
                }
            )

        // Create the PeerConnection
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "false", "OfferToReceiveVideo": "false"],
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )

        self.peerConnectionDelegate = delegate
        self.peerConnection = peerConnectionFactory.peerConnection(
            with: configuration,
            constraints: constraints,
            delegate: delegate
        )
    }

    // Create a new Peer Connection
    public func createPeerConnection(
        onIceCandidate: @escaping (RTCIceCandidate) -> Void,
        onDataChannel: @escaping (RTCDataChannel) -> Void,
        onConnectionStateChange: @escaping (RTCPeerConnectionState) -> Void,
        iceServers: [RTCIceServer]
    ) {
        let configuration = RTCConfiguration()
        configuration.iceServers = iceServers
        configuration.sdpSemantics = .unifiedPlan
        configuration.continualGatheringPolicy = .gatherContinually

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "false", "OfferToReceiveVideo": "false"],
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        peerConnection = peerConnectionFactory.peerConnection(with: configuration, constraints: constraints, delegate: PeerConnectionDelegate(
            onIceCandidate: onIceCandidate,
            onDataChannel: onDataChannel,
            onConnectionStateChange: onConnectionStateChange
        ))
    }

    // Add an ICE Candidate
    public func addIceCandidate(_ candidate: RTCIceCandidate) throws {
        guard let peerConnection = peerConnection else {
            throw NSError(domain: "PeerApi", code: -1, userInfo: [NSLocalizedDescriptionKey: "PeerConnection is null, ensure you are connected"])
        }
        peerConnection.add(candidate, completionHandler: { error in
            if let error = error {
                Logger.error("PeerAPI: addIceCandidate: Failed to add ICE candidate: \(error)")
            } else {
                Logger.debug("PeerAPI: addIceCandidate: ICE candidate added successfully.")
            }
        })
    }

    // Set the Local Description
    public func setLocalDescription(_ description: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        guard let peerConnection = peerConnection else {
            Logger.error("PeerAPI: PeerConnection is null, ensure you are connected")
            return
        }
        Logger.debug("PeerAPI: Setting local description: \(description.type.rawValue)")
        peerConnection.setLocalDescription(description, completionHandler: completion)
    }

    public func setRemoteDescription(_ description: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        guard let peerConnection = peerConnection else {
            Logger.error("PeerAPI: PeerConnection is null, ensure you are connected")
            return
        }

        if peerConnection.signalingState == .haveLocalOffer && description.type == .offer {
            Logger.error("PeerAPI: PeerAPI setRemoteDescription: Cannot set remote offer while in have-local-offer state")
            return
        }

        Logger.debug("PeerAPI: Setting remote description: \(description.type.rawValue)")
        peerConnection.setRemoteDescription(description, completionHandler: completion)
    }

    // Create an Offer
    public func createOffer(completion: @escaping (RTCSessionDescription?) -> Void) {
        guard let peerConnection = peerConnection else {
            Logger.error("PeerAPI: PeerConnection is null, ensure you are connected")
            completion(nil)
            return
        }
        peerConnection.offer(for: RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": "false", "OfferToReceiveVideo": "false"], optionalConstraints: ["DtlsSrtpKeyAgreement": "true"])) { sdp, error in
            if let error = error {
                Logger.error("PeerAPI: Failed to create offer: \(error)")
                completion(nil)
            } else {
                completion(sdp)
            }
        }
    }

    // Create an Answer
    public func createAnswer(completion: @escaping (RTCSessionDescription?) -> Void) {
        guard let peerConnection = peerConnection else {
            Logger.error("PeerAPI: PeerConnection is null, ensure you are connected")
            return
        }
        peerConnection.answer(for: RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": "false", "OfferToReceiveVideo": "false"], optionalConstraints: ["DtlsSrtpKeyAgreement": "true"])) { sdp, error in
            if let error = error {
                Logger.error("PeerAPI: Failed to create answer: \(error)")
                completion(nil)
            } else {
                completion(sdp)
            }
        }
    }

    // Create a Data Channel
    public func createDataChannel(
        label: String,
        onMessage: @escaping (String) -> Void,
        onStateChange: @escaping (String?) -> Void
    ) -> RTCDataChannel? {
        let config = RTCDataChannelConfiguration()
        Logger.debug("PeerAPI: Creating data channel with label: \(label)")
        self.dataChannel = peerConnection?.dataChannel(forLabel: label, configuration: config)

        if let dataChannel = self.dataChannel {
            let delegate = DataChannelDelegate(
                signalService: signalService,
                onMessage: onMessage,
                onStateChange: onStateChange
            )
            dataChannel.delegate = delegate
            dataChannelDelegates[dataChannel] = delegate
            Logger.debug("PeerApi: DataChannelDelegate assigned to data channel: \(dataChannel.label)")
        }

        return self.dataChannel
    }

    // Send a message through the Data Channel
    public func send(_ message: String) {
        guard let dataChannel = dataChannel else {
            Logger.error("PeerAPI: peerApi: Data channel is not available.")
            return
        }

        let buffer = RTCDataBuffer(data: message.data(using: .utf8)!, isBinary: false)
        dataChannel.sendData(buffer)
    }

    // Close the Peer Connection
    public func close() {
        dataChannel?.close()
        peerConnection?.close()
        dataChannel = nil
        peerConnection = nil
    }
}

// Delegate to handle PeerConnection events
class PeerConnectionDelegate: NSObject, RTCPeerConnectionDelegate {
    private let onIceCandidate: (RTCIceCandidate) -> Void
    private let onDataChannel: (RTCDataChannel) -> Void
    private let onConnectionStateChange: (RTCPeerConnectionState) -> Void

    init(
        onIceCandidate: @escaping (RTCIceCandidate) -> Void,
        onDataChannel: @escaping (RTCDataChannel) -> Void,
        onConnectionStateChange: @escaping (RTCPeerConnectionState) -> Void
    ) {
        Logger.debug("PeerAPI: PeerConnectionDelegate initialized")
        self.onIceCandidate = onIceCandidate
        self.onDataChannel = onDataChannel
        self.onConnectionStateChange = onConnectionStateChange
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        Logger.debug("PeerAPI: Data channel opened: \(dataChannel.label)")
        self.onDataChannel(dataChannel)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        Logger.debug("PeerAPI: Media stream added: \(stream)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        Logger.debug("PeerAPI: Media stream removed: \(stream)")
    }

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        Logger.debug("PeerAPI: Renegotiation needed")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Logger.debug("PeerAPI: ICE connection state changed: \(newState)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        Logger.debug("PeerAPI: ICE gathering state changed: \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        Logger.debug("PeerAPI: ICE signaling state changed: \(stateChanged)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Logger.debug("PeerAPI: ICE candidate: \(candidate)")
        onIceCandidate(candidate)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        Logger.debug("PeerAPI: ICE candidates removed: \(candidates)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        Logger.debug("PeerAPI: Peer connection state changed: \(newState.rawValue)")
        onConnectionStateChange(newState)
    }
}
