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
