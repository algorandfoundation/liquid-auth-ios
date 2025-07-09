import Foundation
import WebRTC

public protocol SignalServiceDelegate: AnyObject {
    func signalService(_ service: SignalService, didReceiveStatusUpdate title: String, message: String)
}

public class SignalService {
    public static let shared = SignalService()

    public weak var delegate: SignalServiceDelegate?
    private var signalClient: SignalClient?
    private var peerClient: PeerApi?
    var dataChannel: RTCDataChannel?
    private var peerConnection: RTCPeerConnection?
    private var dataChannelDelegates: [RTCDataChannel: DataChannelDelegate] = [:]

    private var messageQueue: [String] = []

    private var lastKnownReferer: String?
    private var isDeepLink: Bool = true

    var currentPeerType: String? // "offer" or "answer"

    private init() {}

    // MARK: - Start the signaling service
    public func start(url: String, httpClient: URLSession) {
        // Initialize the SignalClient
        signalClient = SignalClient(url: url, service: self)
        signalClient?.connectSocket()
        delegate?.signalService(self, didReceiveStatusUpdate: "Signal Service", message: "Service started successfully.")
    }

    // MARK: - Stop the signaling service
    public func stop() {
        signalClient?.disconnectSocket()
        signalClient = nil
        peerClient = nil
        dataChannel = nil
        peerConnection = nil
        delegate?.signalService(self, didReceiveStatusUpdate: "Signal Service", message: "Service stopped.")
    }

    // MARK: - Disconnect from the signaling service
    public func disconnect() {
        signalClient?.disconnectSocket()
        delegate?.signalService(self, didReceiveStatusUpdate: "Signal Service", message: "Disconnected from the signaling server.")
    }

    // MARK: - Check if the signaling service is initialized
    public var isPeerClientInitialized: Bool {
        return peerClient != nil
    }

    // MARK: - Connect to a peer by request ID
    public func connectToPeer(
        requestId: String,
        type: String,
        origin: String,
        iceServers: [RTCIceServer],
        onMessage: @escaping (String) -> Void,
        onStateChange: @escaping (String?) -> Void
    ) {
        self.currentPeerType = type

        signalClient?.disconnectSocket()
        signalClient = nil

        Logger.debug("Attempting to connect to peer with requestId: \(requestId), type: \(type)")

        // Ensure the socket is connected
        signalClient = SignalClient(url: origin, service: self)

        // Wait for socket connection before starting signaling
        signalClient?.onSocketConnected = { [weak self] in
            guard let self = self else { return }
            Logger.debug("Socket connected, now starting WebRTC signaling.")
            _ = self.signalClient?.connectToPeer(
                requestId: requestId,
                type: type,
                iceServers: iceServers,
                onDataChannelOpen: { [weak self] dataChannel in
                    Logger.debug("SignalService: onDataChannelOpen called with: \(dataChannel.label)")
                    self?.dataChannel = dataChannel
                    Logger.debug("Data channel is open and ready: \(dataChannel.label)")
                    if dataChannel.readyState == .open {
                        self?.flushMessageQueue()
                        for i in 0..<10 {
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

            self.peerClient = self.signalClient?.peerClient
            self.peerConnection = self.peerClient?.peerConnection

            if let peerConnection = self.peerConnection {
                Logger.debug("Peer connection state: \(peerConnection.connectionState.rawValue)")
            } else {
                Logger.error("Peer connection is nil.")
            }

            self.delegate?.signalService(self, didReceiveStatusUpdate: "Peer Connection", message: "Connected to peer with request ID: \(requestId).")
        }

        signalClient?.connectSocket()
        Logger.debug("ICE servers: \(iceServers)")
        Logger.debug("Waiting for socket to connect before signaling.")
    }

    // MARK: - Send a message through the data channel
    public func sendMessage(_ message: String) {
        if let dataChannel = dataChannel, dataChannel.readyState == .open {
            Logger.debug("SignalService: Sending on channel to \(ObjectIdentifier(dataChannel)) label: \(dataChannel.label)")
            let buffer = RTCDataBuffer(data: message.data(using: .utf8)!, isBinary: false)
            dataChannel.sendData(buffer)
            Logger.info("Message sent: \(message)")
        } else {
            Logger.error("sendMessage: Data channel is not available. Queuing message.")
            messageQueue.append(message)
        }
    }

    // Flush queued messages when the data channel becomes available
    private func flushMessageQueue() {
        guard let dataChannel = dataChannel else { return }
        for message in messageQueue {
            let buffer = RTCDataBuffer(data: message.data(using: .utf8)!, isBinary: false)
            dataChannel.sendData(buffer)
            Logger.info("Flushed queued message: \(message)")
        }
        messageQueue.removeAll()
    }
}
