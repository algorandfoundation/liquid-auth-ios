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

public struct LiquidAuthConfig {
    public let iceServers: [RTCIceServer]
    public let userAgent: String?
    public let timeout: TimeInterval
    public let enableLogging: Bool

    public init(
        iceServers: [RTCIceServer]? = nil,
        userAgent: String? = nil,
        timeout: TimeInterval = 30.0,
        enableLogging: Bool = false
    ) {
        self.iceServers = iceServers ?? Self.defaultIceServers
        self.userAgent = userAgent
        self.timeout = timeout
        self.enableLogging = enableLogging
    }

    public static let `default` = LiquidAuthConfig()

    private static let defaultIceServers: [RTCIceServer] = [
        RTCIceServer(urlStrings: [
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302",
            "stun:stun2.l.google.com:19302",
            "stun:stun3.l.google.com:19302",
            "stun:stun4.l.google.com:19302",
        ]),
        RTCIceServer(
            urlStrings: [
                "turn:global.turn.nodely.network:80?transport=tcp",
                "turns:global.turn.nodely.network:443?transport=tcp",
                "turn:eu.turn.nodely.io:80?transport=tcp",
                "turns:eu.turn.nodely.io:443?transport=tcp",
                "turn:us.turn.nodely.io:80?transport=tcp",
                "turns:us.turn.nodely.io:443?transport=tcp",
            ],
            username: "liquid-auth",
            credential: "sqmcP4MiTKMT4TGEDSk9jgHY"
        ),
    ]
}
