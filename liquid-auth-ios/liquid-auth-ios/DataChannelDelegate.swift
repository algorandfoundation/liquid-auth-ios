import WebRTC

class DataChannelDelegate: NSObject, RTCDataChannelDelegate {
    private let onMessage: (String) -> Void
    private let onStateChange: (String?) -> Void

    init(onMessage: @escaping (String) -> Void, onStateChange: @escaping (String?) -> Void) {
        self.onMessage = onMessage
        self.onStateChange = onStateChange
    }

    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        if let message = String(data: buffer.data, encoding: .utf8) {
            onMessage(message)
        } else {
            print("Failed to decode message.")
        }
    }

    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        let state = dataChannel.readyState.description
        onStateChange(state)
    }
}

extension RTCDataChannelState {
    var description: String {
        switch self {
        case .connecting: return "connecting"
        case .open: return "open"
        case .closing: return "closing"
        case .closed: return "closed"
        @unknown default: return "unknown"
        }
    }
}