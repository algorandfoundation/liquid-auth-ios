//
//  liquid_auth_iosApp.swift
//  liquid-auth-ios
//
//  Created by Yared Efrem Afework on 2025-04-11.
//

import SwiftUI
import UserNotifications

@main
struct liquid_auth_iosApp: App {
    init() {
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
                print("Failed to request notification permissions: \(error)")
            } else if granted {
                print("Notification permissions granted.")
            } else {
                print("Notification permissions denied.")
            }
        }
    }
}