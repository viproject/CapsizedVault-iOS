//
//  CapsizedVaultApp.swift
//  CapsizedVault
//
//  Created by Dmitrij on 05/12/2025.
//

import SwiftUI

@main
struct CapsizedVaultApp: App {

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authManager = AuthManager.shared

    init() {
        ZcashSettings.registerDefaults()
        BackgroundSyncCoordinator.registerDefaults()
        BackgroundSyncCoordinator.shared.registerTasks()
        CoinPriceManager.shared.startPolling()
        _ = ReviewManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                authManager.appMovedToBackground()
                BackgroundSyncCoordinator.shared.appDidEnterBackground()
            case .active:
                authManager.appMovedToForeground()
            default:
                break
            }
        }
    }
}
