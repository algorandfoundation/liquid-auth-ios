import SocketIO
import WebRTC
import CoreImage

class SignalClient {
    private let manager: SocketManager
    private let socket: SocketIOClient
    private weak var service: SignalService?
    private var sdpHandler: ((String) -> Void)?
    var peerClient: PeerApi?
    private var candidatesBuffer: [RTCIceCandidate] = []
    private var eventQueue: [(String, [String: Any])] = []

    

    init(url: String, service: SignalService) {
        self.service = service

        // Initialize the Socket.IO manager and client
        self.manager = SocketManager(socketURL: URL(string: "https://\(url)")!, config: [.log(true), .compress])
        self.socket = manager.defaultSocket

        // Set up event listeners
        setupSocketListeners()
    }

    func handleDataChannel(
        _ dataChannel: RTCDataChannel,
        onMessage: @escaping (String) -> Void,
        onStateChange: @escaping (String?) -> Void
    ) {
        // Set up the data channel delegate
        dataChannel.delegate = DataChannelDelegate(
            onMessage: { message in
                onMessage(message)
            },
            onStateChange: { state in
                onStateChange(state)
            }
        )
    }


    func connectToPeer(requestId: String, type: String, iceServers: [RTCIceServer]) -> RTCDataChannel? {
        print("SignalClient: Attempting to connect to peer with requestId: \(requestId), type: \(type)")

        peerClient = PeerApi(iceServers: iceServers, poolSize: 10)

        if type == "offer" {
            print("Offer: sending link request")
            self.send(event: "link", data: ["requestId": requestId])

            peerClient?.createOffer { offer in
                guard let offer = offer else {
                    print("Failed to create offer: Offer is nil")
                    return
                }
                print("Offer: Setting local description")
                self.peerClient?.setLocalDescription(offer) { error in
                    if let error = error {
                        print("Failed to set local description: \(error)")
                    } else {
                        print("Offer: Sending offer description")
                        self.send(event: "offer-description", data: ["sdp": offer.sdp])
                    }
                }
            }
        } else if type == "answer" {
            print("Answer: Waiting for remote offer")
        }

        // Return the data channel if available
        return peerClient?.peerConnection?.dataChannel(forLabel: "liquid", configuration: RTCDataChannelConfiguration())
    }

    // MARK: - Connect to the Socket.IO Server
    func connectSocket() {
        if socket.status != .connected {
            print("Socket is not connected. Attempting to connect...")
            socket.connect()
        } else {
            print("Socket is already connected.")
        }
    }

    func disconnectSocket() {
        socket.disconnect()
        handleDisconnect()
    }

    private func handleDisconnect() {
        print("Handling Socket.IO disconnection...")
        peerClient?.close()
        peerClient = nil
    }

    // MARK: - Set Up Socket.IO Listeners
    private func setupSocketListeners() {
        socket.on(clientEvent: .connect) { _, _ in
            print("Socket.IO connected")
            self.processEventQueue()
        }

        socket.on(clientEvent: .disconnect) { _, _ in
            print("Socket.IO disconnected")
            self.handleDisconnect()
        }

        socket.on("offer-description") { [weak self] data, _ in
            guard let self = self, let eventData = data.first as? [String: Any] else { return }
            print("Received SDP offer: \(eventData)")
            self.handleOfferDescription(eventData)
        }

        socket.on("answer-description") { [weak self] data, _ in
            guard let self = self, let eventData = data.first as? [String: Any] else { return }
            print("Received SDP answer: \(eventData)")
            self.handleAnswerDescription(eventData)
        }

        socket.on("candidate") { [weak self] data, _ in
            guard let self = self, let eventData = data.first as? [String: Any] else { return }
            print("Received ICE candidate: \(eventData)")
            self.handleIceCandidate(eventData)
        }

        socket.on("link-response") { data, _ in
            print("Received link response: \(data)")
        }

        socket.on("error") { data, _ in
            print("Socket.IO error: \(data)")
        }
    }

    // MARK: - Handle WebSocket Messages
    private func handleOfferDescription(_ data: [String: Any]) {
        guard let sdp = data["sdp"] as? String else {
            print("Received SDP is missing or invalid.")
            return
        }

        print("Received SDP offer 2: \(sdp)")

        let sessionDescription = RTCSessionDescription(type: .offer, sdp: sdp)

        if peerClient?.peerConnection?.signalingState == .haveLocalOffer {
            print("Cannot set remote offer while in have-local-offer state")
            return
        }

        print("Setting remote description with session description: \(sessionDescription)")

        peerClient?.setRemoteDescription(sessionDescription, completion: { error in
            if let error = error {
                print("Failed to set remote description: \(error)")
            } else {
                print("Remote description set successfully.")
                self.peerClient?.createAnswer { answer in
                    guard let answer = answer else {
                        print("Failed to create answer: Answer is nil")
                        return
                    }
                    self.peerClient?.setLocalDescription(answer) { error in
                        if let error = error {
                            print("Failed to set local description: \(error)")
                        } else {
                            print("Local description set successfully.")
                            self.socket.emit("answer-description", ["sdp": answer.sdp])
                        }
                    }
                }
            }
        })
    }

    private func handleAnswerDescription(_ data: [String: Any]) {
        guard let sdp = data["sdp"] as? String else { return }
        let sessionDescription = RTCSessionDescription(type: .answer, sdp: sdp)
        print("Received SDP answer: \(sdp)")

        if peerClient?.peerConnection?.signalingState != .haveLocalOffer {
            print("Cannot set remote answer unless in have-local-offer state")
            return
        }

        peerClient?.setRemoteDescription(sessionDescription, completion: { error in
            if let error = error {
                print("Failed to set remote description: \(error)")
            } else {
                // Process buffered ICE candidates
                self.processBufferedCandidates()
            }
        })
    }

    private func handleIceCandidate(_ data: [String: Any]) {
        guard let candidate = data["candidate"] as? String,
            let sdpMid = data["sdpMid"] as? String,
            let sdpMLineIndex = data["sdpMLineIndex"] as? Int else { return }
        let iceCandidate = RTCIceCandidate(sdp: candidate, sdpMLineIndex: Int32(sdpMLineIndex), sdpMid: sdpMid)
        print("Adding ICE candidate: \(iceCandidate)")

        if let peerConnection = peerClient?.peerConnection {
            peerConnection.add(iceCandidate)
        } else {
            candidatesBuffer.append(iceCandidate)
        }
    }

    // Process buffered ICE candidates once the peer connection is ready
    private func processBufferedCandidates() {
        guard let peerConnection = peerClient?.peerConnection else { return }
        for candidate in candidatesBuffer {
            peerConnection.add(candidate)
        }
        candidatesBuffer.removeAll()
    }

    // MARK: - Send Events to the Server
    func send(event: String, data: [String: Any]) {
        if socket.status == .connected {
            print("Emitting event immediately: \(event) with data: \(data)")
            socket.emit(event, data)
        } else {
            print("Socket not connected. Queuing event: \(event)")
            eventQueue.append((event, data))
        }
    }

    private func processEventQueue() {
        guard socket.status == .connected else { return }
        print("Processing event queue. Number of queued events: \(eventQueue.count)")
        for (event, data) in eventQueue {
            print("Emitting queued event: \(event) with data: \(data)")
            socket.emit(event, data)
        }
        eventQueue.removeAll()
    }

    func link(requestId: String) {
        socket.emit("link", ["requestId": requestId]) {
            print("Link request emitted successfully.")
        }
    }

    func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .ascii)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("Q", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)

        return UIImage(ciImage: scaledImage)
    }
}