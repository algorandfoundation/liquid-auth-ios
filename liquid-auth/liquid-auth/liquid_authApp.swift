//
//  liquid_authApp.swift
//  liquid-auth
//
//  Created by Algorand Foundation on 2025-04-11.
//

import SwiftUI
import UserNotifications

@main
struct liquid_authApp: App {
    init() {
        Logger.currentLevel = .debug // or .debug, .error as needed
        requestNotificationPermissions()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func requestNotificationPermissions() {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                Logger.error("Failed to request notification permissions: \(error)")
            } else if granted {
                Logger.debug("Notification permissions granted.")
            } else {
                Logger.error("Notification permissions denied.")
            }
        }
    }
}