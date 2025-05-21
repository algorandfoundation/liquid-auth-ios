import Foundation
import WebRTC
import UserNotifications

class SignalService {
    static let shared = SignalService()

    private var signalClient: SignalClient?
    private var peerClient: PeerApi?
    var dataChannel: RTCDataChannel?
    private var peerConnection: RTCPeerConnection?
    private var dataChannelDelegates: [RTCDataChannel: DataChannelDelegate] = [:]


    private var lastKnownReferer: String?
    private var isDeepLink: Bool = true

    var currentPeerType: String? // "offer" or "answer"

    private init() {}

    // MARK: - Start the signaling service
    func start(url: String, httpClient: URLSession) {
        // Initialize the SignalClient
        signalClient = SignalClient(url: url, service: self)

        signalClient?.connectSocket()

        // Send a notification to indicate the service has started
        sendNotification(title: "Signal Service", body: "Service started successfully.")
    }

    // MARK: - Stop the signaling service
    func stop() {
        signalClient?.disconnectSocket()
        signalClient = nil
        peerClient = nil
        dataChannel = nil
        peerConnection = nil

        sendNotification(title: "Signal Service", body: "Service stopped.")
    }

    // MARK: - Disconnect from the signaling service
    func disconnect() {
        signalClient?.disconnectSocket()
        sendNotification(title: "Signal Service", body: "Disconnected from the signaling server.")
    }

    // MARK: - Check if the signaling service is initialized
    public var isPeerClientInitialized: Bool {
        return peerClient != nil
    }

    // MARK: - Connect to a peer by request ID
    func connectToPeer(
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

        print("Attempting to connect to peer with requestId: \(requestId), type: \(type)")

        // Ensure the socket is connected
        signalClient = SignalClient(url: origin, service: self)
        signalClient?.connectSocket()

        print("ICE servers: \(iceServers)")

        print("About to call signalClient.connectToPeer.")
        // Pass the closures down to SignalClient
        let returnedDataChannel = signalClient?.connectToPeer(
            requestId: requestId,
            type: type,
            iceServers: iceServers,
            onDataChannelOpen: { [weak self] dataChannel in
                print("Data channel is open and ready: \(dataChannel.label)")
                self?.dataChannel = dataChannel
            },
            onMessage: onMessage,
            onStateChange: onStateChange
        )

        peerClient = signalClient?.peerClient
        peerConnection = peerClient?.peerConnection

        if let peerConnection = peerConnection {
            print("Peer connection state: \(peerConnection.connectionState.rawValue)")
        } else {
            print("Peer connection is nil.")
        }

        sendNotification(title: "Peer Connection", body: "Connected to peer with request ID: \(requestId).")
    }

    // MARK: - Send a message through the data channel
    func sendMessage(_ message: String) {
        guard let dataChannel = dataChannel else {
            print("sendMessage: Data channel is not available.")
            return
        }

        let buffer = RTCDataBuffer(data: message.data(using: .utf8)!, isBinary: false)
        dataChannel.sendData(buffer)

        print("Message sent: \(message)")
    }

    // MARK: - Send a notification
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
}
