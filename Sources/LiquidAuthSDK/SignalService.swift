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

// MARK: - SignalServiceDelegate

protocol SignalServiceDelegate: AnyObject {
    func signalService(_ service: SignalService, didReceiveStatusUpdate title: String, message: String)
}

// MARK: - SignalService

class SignalService {
    static let shared = SignalService()

    weak var delegate: SignalServiceDelegate?
    private var signalClient: SignalClient?
    private var peerClient: PeerApi?
    var dataChannel: RTCDataChannel?
    private var peerConnection: RTCPeerConnection?
    private var dataChannelDelegates: [RTCDataChannel: DataChannelDelegate] = [:]

    private var messageQueue: [String] = []

    private var lastKnownReferer: String?
    private var isDeepLink: Bool = true

    var currentPeerType: String? // "offer" or "answer"

    private init() { }

    // MARK: - Public Methods

    /// Starts the signaling service
    ///
    /// - Parameters:
    ///   - url: The signaling server URL
    ///   - httpClient: URLSession for HTTP communications
    func start(url: String, httpClient _: URLSession) {
        // Initialize the SignalClient
        signalClient = SignalClient(url: url, service: self)
        signalClient?.connectSocket()
        delegate?.signalService(
            self,
            didReceiveStatusUpdate: "Signal Service",
            message: "Service started successfully."
        )
    }

    /// Stops the signaling service and cleans up resources
    func stop() {
        signalClient?.disconnectSocket()
        signalClient = nil
        peerClient = nil
        dataChannel = nil
        peerConnection = nil
        delegate?.signalService(self, didReceiveStatusUpdate: "Signal Service", message: "Service stopped.")
    }

    /// Disconnects from the signaling service
    func disconnect() {
        signalClient?.disconnectSocket()
        delegate?.signalService(
            self,
            didReceiveStatusUpdate: "Signal Service",
            message: "Disconnected from the signaling server."
        )
    }

    // MARK: - Check if the signaling service is initialized

    var isPeerClientInitialized: Bool {
        peerClient != nil
    }

    /// Connects to a peer using WebRTC signaling
    ///
    /// - Parameters:
    ///   - requestId: Unique identifier for the peer connection
    ///   - type: Connection type ("offer" or "answer")
    ///   - origin: Origin domain for the connection
    ///   - iceServers: ICE servers for NAT traversal
    ///   - onMessage: Callback for received messages
    ///   - onStateChange: Callback for connection state changes
    func connectToPeer(
        requestId: String,
        type: String,
        origin: String,
        iceServers: [RTCIceServer],
        onMessage: @escaping (String) -> Void,
        onStateChange: @escaping (String?) -> Void
    ) {
        currentPeerType = type

        signalClient?.disconnectSocket()
        signalClient = nil

        Logger.debug("Attempting to connect to peer with requestId: \(requestId), type: \(type)")

        // Ensure the socket is connected
        signalClient = SignalClient(url: origin, service: self)

        // Wait for socket connection before starting signaling
        signalClient?.onSocketConnected = { [weak self] in
            guard let self else { return }
            Logger.debug("Socket connected, now starting WebRTC signaling.")
            _ = signalClient?.connectToPeer(
                requestId: requestId,
                type: type,
                iceServers: iceServers,
                onDataChannelOpen: { [weak self] dataChannel in
                    Logger.debug("SignalService: onDataChannelOpen called with: \(dataChannel.label)")
                    self?.dataChannel = dataChannel
                    Logger.debug("Data channel is open and ready: \(dataChannel.label)")
                    if dataChannel.readyState == .open {
                        self?.flushMessageQueue()
                        for i in 0 ..< 10 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                                self?.sendMessage("ping")
                            }
                        }
                    }
                },
                onMessage: { message in
                    onMessage(message)
                },
                onStateChange: onStateChange
            )

            peerClient = signalClient?.peerClient
            peerConnection = peerClient?.peerConnection

            if let peerConnection {
                Logger.debug("Peer connection state: \(peerConnection.connectionState.rawValue)")
            } else {
                Logger.error("Peer connection is nil.")
            }

            delegate?.signalService(
                self,
                didReceiveStatusUpdate: "Peer Connection",
                message: "Connected to peer with request ID: \(requestId)."
            )
        }

        signalClient?.connectSocket()
        Logger.debug("ICE servers: \(iceServers)")
        Logger.debug("Waiting for socket to connect before signaling.")
    }

    /// Sends a message through the data channel
    ///
    /// - Parameter message: The message to send
    func sendMessage(_ message: String) {
        if let dataChannel, dataChannel.readyState == .open {
            Logger
                .debug(
                    "SignalService: Sending on channel to \(ObjectIdentifier(dataChannel)) label: \(dataChannel.label)"
                )
            let buffer = RTCDataBuffer(data: message.data(using: .utf8)!, isBinary: false)
            dataChannel.sendData(buffer)
            Logger.info("Message sent: \(message)")
        } else {
            Logger.error("sendMessage: Data channel is not available. Queuing message.")
            messageQueue.append(message)
        }
    }

    /// Flushes queued messages when the data channel becomes available
    private func flushMessageQueue() {
        guard let dataChannel else { return }
        for message in messageQueue {
            let buffer = RTCDataBuffer(data: message.data(using: .utf8)!, isBinary: false)
            dataChannel.sendData(buffer)
            Logger.info("Flushed queued message: \(message)")
        }
        messageQueue.removeAll()
    }
}
