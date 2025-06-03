import WebRTC

class DataChannelDelegate: NSObject, RTCDataChannelDelegate {
    private let onMessage: (String) -> Void
    private let onStateChange: (String?) -> Void?
    private let onBufferedAmountChange: ((UInt64) -> Void)?
    private let onChannelAvailable: ((RTCDataChannel) -> Void)?
    private weak var signalService: SignalService?

    init(
        signalService: SignalService?,
        onMessage: @escaping (String) -> Void,
        onStateChange: ((String?) -> Void)? = nil,
        onBufferedAmountChange: ((UInt64) -> Void)? = nil,
        onChannelAvailable: ((RTCDataChannel) -> Void)? = nil
    ) {
        self.signalService = signalService
        self.onMessage = onMessage
        self.onStateChange = onStateChange!
        self.onBufferedAmountChange = onBufferedAmountChange
        self.onChannelAvailable = onChannelAvailable

    }

    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
    // Ensure signalService.dataChannel is set to the active channel
    if let service = signalService, service.dataChannel !== dataChannel {
        Logger.debug("DataChannelDelegate: Setting signalService.dataChannel from didReceiveMessageWith: \(ObjectIdentifier(dataChannel))")
        service.dataChannel = dataChannel
    }
    onChannelAvailable?(dataChannel)
    if let message = String(data: buffer.data, encoding: .utf8) {
        Logger.debug("💬 DataChannel: Received message: \(message) on channel: \(ObjectIdentifier(dataChannel))")
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
