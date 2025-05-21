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
        print("DataChannelDelegate initialized!")
        self.onMessage = onMessage
        self.onStateChange = onStateChange!
        self.onBufferedAmountChange = onBufferedAmountChange

    }

    deinit {
        print("DataChannelDelegate deinitialized!")
    }

    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        print("DataChannelDelegate: didReceiveMessageWith called")
        if let message = String(data: buffer.data, encoding: .utf8) {
            print("DataChannelDelegate: Received message: \(message)")
            onMessage(message)
        }
    }

    func dataChannel(_ dataChannel: RTCDataChannel, didChangeBufferedAmount amount: UInt64) {
        print("DataChannelDelegate: Buffered amount changed to: \(amount)")
        onBufferedAmountChange?(amount)
    }

    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        let state = dataChannel.readyState.description
        print("DataChannelDelegate: Data channel state changed to: \(state) at \(Date())")
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
