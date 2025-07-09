import SocketIO
import WebRTC
import CoreImage

public class SignalClient {
    private let manager: SocketManager
    private let socket: SocketIOClient
    weak var service: SignalService?
    private var sdpHandler: ((String) -> Void)?
    var peerClient: PeerApi?
    private var candidatesBuffer: [RTCIceCandidate] = []
    private var eventQueue: [(String, QueuedEventData)] = []
    private var dataChannelDelegates: [RTCDataChannel: DataChannelDelegate] = [:]
    var onSocketConnected: (() -> Void)?

    

    public init(url: String, service: SignalService) {
        self.service = service

        // Initialize the Socket.IO manager and client
        self.manager = SocketManager(socketURL: URL(string: "https://\(url)")!, config: [.log(false), .compress])
        self.socket = manager.defaultSocket

        // Set up event listeners
        setupSocketListeners()
    }

    public func connectToPeer(
        requestId: String,
        type: String,
        iceServers: [RTCIceServer],
        onDataChannelOpen: @escaping (RTCDataChannel) -> Void,
        onMessage: @escaping (String) -> Void,
        onStateChange: @escaping (String?) -> Void
    ) -> RTCDataChannel? {
        // Clean up any existing peer connection
        peerClient?.close()
        peerClient = nil

        Logger.debug("SignalClient: Attempting to connect to peer with requestId: \(requestId), type: \(type)")

        peerClient = PeerApi(
            iceServers: iceServers,
            poolSize: 10,
            signalService: service,
            onDataChannel: { [weak self] dataChannel in
                Logger.debug("SignalClient: onDataChannel called with: \(dataChannel.label)")
                Logger.debug("Received data channel from remote peer: \(dataChannel.label)")
                let delegate = DataChannelDelegate(
                    signalService: self?.service,
                    onMessage: { message in
                        Logger.info("💬 SignalClient: Received message: \(message)")
                        onMessage(message)
                    },
                    onStateChange: { state in
                        Logger.debug("SignalClient: Data channel state changed: \(state ?? "unknown")")
                        if state == "open" {
                            Logger.info("✅ SignalClient: Open and ready: \(dataChannel.label)")
                            Logger.debug("SignalService: Setting dataChannel to \(ObjectIdentifier(dataChannel)) label: \(dataChannel.label)")
                            onDataChannelOpen(dataChannel)
                        }
                    },
                    onChannelAvailable: { [weak self] channel in
                        if self?.service?.dataChannel !== channel {
                            Logger.debug("SignalClient: Setting dataChannel from didReceiveMessageWith: \(ObjectIdentifier(channel))")
                            self?.service?.dataChannel = channel
                        }
                    }
                )
                dataChannel.delegate = delegate
                self?.dataChannelDelegates[dataChannel] = delegate
                Logger.debug("SignalClient: DataChannelDelegate assigned to remote data channel: \(dataChannel.label)")

                if dataChannel.readyState == .open {
                    Logger.info("✅ SignalClient: Open and ready (immediate): \(dataChannel.label)")
                    Logger.debug("SignalService: Setting dataChannel to \(ObjectIdentifier(dataChannel)) label: \(dataChannel.label)")
                    onDataChannelOpen(dataChannel)
                }
            },
            onIceCandidate: { [weak self] candidate in
                guard let self = self else { return }
                Logger.debug("Generated ICE candidate: \(candidate)")
                let candidateEvent = (type == "offer") ? "answer-candidate" : "offer-candidate"
                self.send(event: candidateEvent, data: [
                    "candidate": candidate.sdp,
                    "sdpMid": candidate.sdpMid ?? "",
                    "sdpMLineIndex": candidate.sdpMLineIndex
                ])
            }
        )

        if (peerClient?.peerConnection) != nil {
            Logger.info("SignalClient: Peer connection created successfully.")
        } else {
            Logger.error("SignalClient: Failed to create peer connection!")
        }

        if type == "answer" {
            // Initiator logic (creates and sends offer)
            Logger.info("Answer (initiator): sending link request")
            self.send(event: "link", data: ["requestId": requestId])

            guard let peerClient = peerClient, let _ = peerClient.peerConnection else {
                Logger.error("PeerClient or its peerConnection is nil!")
                return nil
            }

            let dataChannel = peerClient.createDataChannel(
                label: "liquid",
                onMessage: onMessage,
                onStateChange: onStateChange
            )

            peerClient.createOffer { offer in
                guard let offer = offer else {
                    Logger.error("Failed to create offer: Offer is nil")
                    return
                }
                Logger.info("Answer (initiator): Setting local description")
                peerClient.setLocalDescription(offer) { error in
                    if let error = error {
                        Logger.error("Failed to set local description: \(error)")
                    } else {
                        Logger.debug("Answer (initiator): Sending offer description")
                        self.send(event: "offer-description", sdp: offer.sdp)
                    }
                }
            }
            return dataChannel
        } else if type == "offer" {
            // Responder logic (waits for offer, then sends answer)
            Logger.info("Offer (responder): Waiting for remote offer")
            self.send(event: "link", data: ["requestId": requestId])

            // Listen for the offer-description event (only for responder)
            self.socket.off("offer-description")
            self.socket.on("offer-description") { [weak self] data, _ in
                guard let self = self, let eventData = data.first as? [String: Any],
                      let sdp = eventData["sdp"] as? String,
                      let type = sdpType(from: eventData["type"] as? String) else { return }
                Logger.info("Offer (responder): Received SDP type: \(type) : \(sdp)")
                let sessionDescription = RTCSessionDescription(type: type, sdp: sdp)

                self.peerClient?.setRemoteDescription(sessionDescription, completion: { error in
                    if let error = error {
                        Logger.error("Failed to set remote description: \(error)")
                    } else {
                        Logger.info("Offer (responder): Remote description set successfully.")

                        self.peerClient?.createAnswer { answer in
                            guard let answer = answer else {
                                Logger.error("Failed to create answer: Answer is nil")
                                return
                            }
                            Logger.info("Offer (responder): Setting local description")
                            self.peerClient?.setLocalDescription(answer) { error in
                                if let error = error {
                                    Logger.error("Failed to set local description: \(error)")
                                } else {
                                    Logger.info("Offer (responder): Sending answer description")
                                    self.send(event: "answer-description", sdp: answer.sdp)//["type": stringFromSdpType(answer.type), "sdp": answer.sdp])
                                }
                            }
                        }
                    }
                })
            }   
            return nil
        }
        return nil
    }

    // MARK: - Connect to the Socket.IO Server
    public func connectSocket() {
        if socket.status != .connected {
            Logger.debug("Socket is not connected. Attempting to connect...")
            socket.connect()
        } else {
            Logger.debug("Socket is already connected.")
        }
    }

    public func disconnectSocket() {
        socket.disconnect()
        handleDisconnect()
    }

    private func handleDisconnect() {
        Logger.debug("Handling Socket.IO disconnection...")
        peerClient?.close()
        peerClient = nil
    }

    // MARK: - Set Up Socket.IO Listeners
    private func setupSocketListeners() {
        socket.on(clientEvent: .connect) { _, _ in
            Logger.debug("Socket.IO connected")
            self.onSocketConnected?()
            self.processEventQueue()
        }

        socket.on(clientEvent: .disconnect) { _, _ in
            Logger.debug("Socket.IO disconnected")
            self.handleDisconnect()
        }

        if self.service?.currentPeerType == "offer" {
            socket.on("offer-description") { [weak self] data, _ in
                guard let self = self, let eventData = data.first as? [String: Any] else { return }
                Logger.debug("Received SDP offer: \(eventData)")
                self.handleOfferDescription(eventData)
            }
        }

        socket.on("answer-description") { [weak self] data, _ in
            guard let self = self else { return }
            // Try to handle as dictionary first, then as string
            if let eventData = data.first as? [String: Any] {
                Logger.debug("Received SDP answer as dictionary: \(eventData)")
                self.handleAnswerDescription(eventData)
            } else if let sdp = data.first as? String {
                Logger.debug("Received SDP answer as string: \(sdp)")
                self.handleAnswerDescription(sdp)
            } else {
                Logger.error("Received SDP answer in unknown format: \(data)")
            }
        }

        socket.on("candidate") { [weak self] data, _ in
            guard let self = self, let eventData = data.first as? [String: Any] else { return }
            Logger.debug("Received ICE candidate: \(eventData)")
            self.handleIceCandidate(eventData)
        }

        socket.on("offer-candidate") { [weak self] data, _ in
            guard let self = self, let eventData = data.first as? [String: Any] else { return }
            Logger.debug("Received offer ICE candidate: \(eventData)")
            self.handleIceCandidate(eventData)
        }
        socket.on("answer-candidate") { [weak self] data, _ in
            guard let self = self, let eventData = data.first as? [String: Any] else { return }
            Logger.debug("Received answer ICE candidate: \(eventData)")
            self.handleIceCandidate(eventData)
        }

        socket.on("link-response") { data, _ in
            Logger.debug("Received link response: \(data)")
        }

        socket.on("error") { data, _ in
            Logger.error("Socket.IO error: \(data)")
        }
    }

    // MARK: - Handle WebSocket Messages
    private func handleOfferDescription(_ data: [String: Any]) {
        guard let sdp = data["sdp"] as? String,
              let type = sdpType(from: data["type"] as? String) else {
            Logger.error("Received SDP is missing or invalid.")
            return
        }

        Logger.debug("handleOfferDescription: Received SDP: \(type) :  \(sdp)")
        let sessionDescription = RTCSessionDescription(type: type, sdp: sdp)

        if peerClient?.peerConnection?.signalingState == .haveLocalOffer {
            Logger.error("HandleOfferDescription: cannot set remote offer while in have-local-offer state")
            return
        }

        Logger.debug("Setting remote description with session description: \(sessionDescription)")

        peerClient?.setRemoteDescription(sessionDescription, completion: { error in
            if let error = error {
                Logger.error("Failed to set remote description: \(error)")
            } else {
                Logger.debug("Remote description set successfully.")
                self.processBufferedCandidates()
                self.peerClient?.createAnswer { answer in
                    guard let answer = answer else {
                        Logger.error("Failed to create answer: Answer is nil")
                        return
                    }
                    self.peerClient?.setLocalDescription(answer) { error in
                        if let error = error {
                            Logger.error("Failed to set local description: \(error)")
                        } else {
                            Logger.debug("Local description set successfully.")
                            self.socket.emit("answer-description", ["sdp": answer.sdp])
                        }
                    }
                }
            }
        })
    }

    private func handleAnswerDescription(_ data: [String: Any]) {
        guard let sdp = data["sdp"] as? String,
            let type = sdpType(from: data["type"] as? String) else {
            Logger.error("Received SDP is missing or invalid.")
            return
        }
        Logger.debug("handleAnswerDescription: Received SDP: \(type) : \(sdp)")
        let sessionDescription = RTCSessionDescription(type: type, sdp: sdp)

        if peerClient?.peerConnection?.signalingState != .haveLocalOffer {
            Logger.error("Cannot set remote answer unless in have-local-offer state")
            return
        }

        peerClient?.setRemoteDescription(sessionDescription, completion: { error in
            if let error = error {
                Logger.error("Failed to set remote description: \(error)")
            } else {
                self.processBufferedCandidates()
            }
        })
    }

    private func handleAnswerDescription(_ sdp: String) {
        // If you know this is always an answer, you can hardcode the type
        let sessionDescription = RTCSessionDescription(type: .answer, sdp: sdp)

        if peerClient?.peerConnection?.signalingState != .haveLocalOffer {
            Logger.error("Cannot set remote answer unless in have-local-offer state")
            return
        }

        Logger.debug("handleAnswerDescription SDP: Setting remote description with session description.")
        peerClient?.setRemoteDescription(sessionDescription, completion: { error in
            if let error = error {
                Logger.error("Failed to set remote description: \(error)")
            } else {
                self.processBufferedCandidates()
            }
        })
    }

    private func handleIceCandidate(_ data: [String: Any]) {
        guard let candidate = data["candidate"] as? String,
            let sdpMid = data["sdpMid"] as? String,
            let sdpMLineIndex = data["sdpMLineIndex"] as? Int else { return }
        let iceCandidate = RTCIceCandidate(sdp: candidate, sdpMLineIndex: Int32(sdpMLineIndex), sdpMid: sdpMid)
        Logger.debug("Adding ICE candidate: \(iceCandidate)")

        if let peerConnection = peerClient?.peerConnection {
            // Only add if remote description is set
            if peerConnection.remoteDescription != nil {
                peerConnection.add(iceCandidate, completionHandler: { error in
                    if let error = error {
                        Logger.error("handleIceCandidate: Failed to add ICE candidate: \(error)")
                    } else {
                        Logger.debug("handleIceCandidate: ICE candidate added successfully.")
                    }
                })
            } else {
                Logger.debug("Remote description not set yet, buffering ICE candidate.")
                candidatesBuffer.append(iceCandidate)
            }
        } else {
            candidatesBuffer.append(iceCandidate)
        }
    }

    // Process buffered ICE candidates once the peer connection is ready
    private func processBufferedCandidates() {
        guard let peerConnection = peerClient?.peerConnection else { return }
        for iceCandidate in candidatesBuffer {
            peerConnection.add(iceCandidate, completionHandler: { error in
                if let error = error {
                    Logger.error("processBufferedCandidates: Failed to add ICE candidate: \(error)")
                } else {
                    Logger.debug("processBufferedCandidates: ICE candidate added successfully.")
                }
            })
        }
        candidatesBuffer.removeAll()
    }

    // MARK: - Send Events to the Server, wth Swift Dictionary/JSON Encoding
    public func send(event: String, data: [String: Any]) {
        if socket.status == .connected {
            Logger.debug("Emitting event immediately: \(event) with data: \(data)")
            socket.emit(event, data)
        } else {
            Logger.debug("Socket not connected. Queuing event: \(event)")
            eventQueue.append((event, .dictionary(data)))
        }
    }

    // Send event with data as a pure string
    public func send(event: String, sdp: String) {
        if socket.status == .connected {
            Logger.debug("Emitting event immediately: \(event) with SDP string")
            socket.emit(event, sdp)
        } else {
            Logger.debug("Socket not connected. Queuing event: \(event)")
            eventQueue.append((event, .string(sdp)))
        }
    }

    private func processEventQueue() {
        guard socket.status == .connected else { return }
        Logger.debug("Processing event queue. Number of queued events: \(eventQueue.count)")
        for (event, data) in eventQueue {
            switch data {
            case .dictionary(let dict):
                Logger.debug("Emitting queued event: \(event) with data: \(dict)")
                socket.emit(event, dict)
            case .string(let sdp):
                Logger.debug("Emitting queued event: \(event) with SDP string")
                socket.emit(event, sdp)
            }
        }
        eventQueue.removeAll()
    }
}

private func sdpType(from typeString: String?) -> RTCSdpType? {
    switch typeString {
    case "offer": return .offer
    case "answer": return .answer
    case "pranswer": return .prAnswer
    case "rollback": return .rollback
    default: return nil
    }
}

private func stringFromSdpType(_ type: RTCSdpType) -> String {
    switch type {
    case .offer: return "offer"
    case .answer: return "answer"
    case .prAnswer: return "pranswer"
    case .rollback: return "rollback"
    @unknown default: return ""
    }
}

private enum QueuedEventData {
    case dictionary([String: Any])
    case string(String)
}
