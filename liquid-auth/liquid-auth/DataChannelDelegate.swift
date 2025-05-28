import WebRTC

class DataChannelDelegate: NSObject, RTCDataChannelDelegate {
    private let onMessage: (String) -> Void
    private let onStateChange: (String?) -> Void?
    private let onBufferedAmountChange: ((UInt64) -> Void)?

    init(
        onMessage: @escaping (String) -> Void,
        onStateChange: ((String?) -> Void)? = nil,
        onBufferedAmountChange: ((UInt64) -> Void)? = nil
    ) {
        self.onMessage = onMessage
        self.onStateChange = onStateChange!
        self.onBufferedAmountChange = onBufferedAmountChange

    }

    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        if let message = String(data: buffer.data, encoding: .utf8) {
            Logger.debug("💬 DataChannel: Received message: \(message)")
            onMessage(message)
        }
    }

    func dataChannel(_ dataChannel: RTCDataChannel, didChangeBufferedAmount amount: UInt64) {
        onBufferedAmountChange?(amount)
    }

    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        let state = dataChannel.readyState.description
        if state == "open" {
            Logger.info("✅ DataChannel: State changed to OPEN")
        }
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
