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

import WebRTC

// MARK: - DataChannelDelegate

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
            Logger
                .debug(
                    "DataChannelDelegate: Setting signalService.dataChannel from " +
                        "didReceiveMessageWith: \(ObjectIdentifier(dataChannel))"
                )
            service.dataChannel = dataChannel
        }
        onChannelAvailable?(dataChannel)
        if let message = String(data: buffer.data, encoding: .utf8) {
            Logger.debug("💬 DataChannel: Received message: \(message) on channel: \(ObjectIdentifier(dataChannel))")
            onMessage(message)
        }
    }

    func dataChannel(_: RTCDataChannel, didChangeBufferedAmount amount: UInt64) {
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
