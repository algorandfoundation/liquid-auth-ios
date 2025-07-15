/*
 * Copyright 2025 Algorand Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import WebRTC

// MARK: - PeerApi

class PeerApi {
    private let peerConnectionFactory: RTCPeerConnectionFactory
    var peerConnection: RTCPeerConnection?
    private var peerConnectionDelegate: PeerConnectionDelegate?
    private var dataChannel: RTCDataChannel?
    private let onDataChannel: (RTCDataChannel) -> Void
    private var dataChannelDelegates: [RTCDataChannel: DataChannelDelegate] = [:]
    private weak var signalService: SignalService?

    init(
        iceServers: [RTCIceServer],
        poolSize: Int,
        signalService: SignalService?,
        onDataChannel: @escaping (RTCDataChannel) -> Void,
        onIceCandidate: @escaping (RTCIceCandidate) -> Void
    ) {
        self.signalService = signalService
        self.onDataChannel = onDataChannel
        // Initialize the PeerConnectionFactory
        RTCPeerConnectionFactory.initialize()
        peerConnectionFactory = RTCPeerConnectionFactory()

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

        peerConnectionDelegate = delegate
        peerConnection = peerConnectionFactory.peerConnection(
            with: configuration,
            constraints: constraints,
            delegate: delegate
        )
    }

    // Create a new Peer Connection
    func createPeerConnection(
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
        peerConnection = peerConnectionFactory.peerConnection(
            with: configuration,
            constraints: constraints,
            delegate: PeerConnectionDelegate(
                onIceCandidate: onIceCandidate,
                onDataChannel: onDataChannel,
                onConnectionStateChange: onConnectionStateChange
            )
        )
    }

    // Add an ICE Candidate
    func addIceCandidate(_ candidate: RTCIceCandidate) throws {
        guard let peerConnection else {
            throw NSError(
                domain: "PeerApi",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "PeerConnection is null, ensure you are connected"]
            )
        }
        peerConnection.add(candidate, completionHandler: { error in
            if let error {
                Logger.error("PeerAPI: addIceCandidate: Failed to add ICE candidate: \(error)")
            } else {
                Logger.debug("PeerAPI: addIceCandidate: ICE candidate added successfully.")
            }
        })
    }

    // Set the Local Description
    func setLocalDescription(_ description: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        guard let peerConnection else {
            Logger.error("PeerAPI: PeerConnection is null, ensure you are connected")
            return
        }
        Logger.debug("PeerAPI: Setting local description: \(description.type.rawValue)")
        peerConnection.setLocalDescription(description, completionHandler: completion)
    }

    func setRemoteDescription(_ description: RTCSessionDescription, completion: @escaping (Error?) -> Void) {
        guard let peerConnection else {
            Logger.error("PeerAPI: PeerConnection is null, ensure you are connected")
            return
        }

        if peerConnection.signalingState == .haveLocalOffer && description.type == .offer {
            Logger
                .error("PeerAPI: PeerAPI setRemoteDescription: Cannot set remote offer while in have-local-offer state")
            return
        }

        Logger.debug("PeerAPI: Setting remote description: \(description.type.rawValue)")
        peerConnection.setRemoteDescription(description, completionHandler: completion)
    }

    // Create an Offer
    func createOffer(completion: @escaping (RTCSessionDescription?) -> Void) {
        guard let peerConnection else {
            Logger.error("PeerAPI: PeerConnection is null, ensure you are connected")
            completion(nil)
            return
        }
        peerConnection.offer(for: RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "false", "OfferToReceiveVideo": "false"],
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )) { sdp, error in
            if let error {
                Logger.error("PeerAPI: Failed to create offer: \(error)")
                completion(nil)
            } else {
                completion(sdp)
            }
        }
    }

    // Create an Answer
    func createAnswer(completion: @escaping (RTCSessionDescription?) -> Void) {
        guard let peerConnection else {
            Logger.error("PeerAPI: PeerConnection is null, ensure you are connected")
            return
        }
        peerConnection.answer(for: RTCMediaConstraints(
            mandatoryConstraints: ["OfferToReceiveAudio": "false", "OfferToReceiveVideo": "false"],
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )) { sdp, error in
            if let error {
                Logger.error("PeerAPI: Failed to create answer: \(error)")
                completion(nil)
            } else {
                completion(sdp)
            }
        }
    }

    // Create a Data Channel
    func createDataChannel(
        label: String,
        onMessage: @escaping (String) -> Void,
        onStateChange: @escaping (String?) -> Void
    ) -> RTCDataChannel? {
        let config = RTCDataChannelConfiguration()
        Logger.debug("PeerAPI: Creating data channel with label: \(label)")
        dataChannel = peerConnection?.dataChannel(forLabel: label, configuration: config)

        if let dataChannel {
            let delegate = DataChannelDelegate(
                signalService: signalService,
                onMessage: onMessage,
                onStateChange: onStateChange
            )
            dataChannel.delegate = delegate
            dataChannelDelegates[dataChannel] = delegate
            Logger.debug("PeerApi: DataChannelDelegate assigned to data channel: \(dataChannel.label)")
        }

        return dataChannel
    }

    // Send a message through the Data Channel
    func send(_ message: String) {
        guard let dataChannel else {
            Logger.error("PeerAPI: peerApi: Data channel is not available.")
            return
        }

        let buffer = RTCDataBuffer(data: message.data(using: .utf8)!, isBinary: false)
        dataChannel.sendData(buffer)
    }

    // Close the Peer Connection
    func close() {
        dataChannel?.close()
        peerConnection?.close()
        dataChannel = nil
        peerConnection = nil
    }
}

// MARK: - PeerConnectionDelegate

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

    func peerConnection(_: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        Logger.debug("PeerAPI: Data channel opened: \(dataChannel.label)")
        onDataChannel(dataChannel)
    }

    func peerConnection(_: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        Logger.debug("PeerAPI: Media stream added: \(stream)")
    }

    func peerConnection(_: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        Logger.debug("PeerAPI: Media stream removed: \(stream)")
    }

    func peerConnectionShouldNegotiate(_: RTCPeerConnection) {
        Logger.debug("PeerAPI: Renegotiation needed")
    }

    func peerConnection(_: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        Logger.debug("PeerAPI: ICE connection state changed: \(newState)")
    }

    func peerConnection(_: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        Logger.debug("PeerAPI: ICE gathering state changed: \(newState)")
    }

    func peerConnection(_: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        Logger.debug("PeerAPI: ICE signaling state changed: \(stateChanged)")
    }

    func peerConnection(_: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        Logger.debug("PeerAPI: ICE candidate: \(candidate)")
        onIceCandidate(candidate)
    }

    func peerConnection(_: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        Logger.debug("PeerAPI: ICE candidates removed: \(candidates)")
    }

    func peerConnection(_: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        Logger.debug("PeerAPI: Peer connection state changed: \(newState.rawValue)")
        onConnectionStateChange(newState)
    }
}
