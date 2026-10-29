//
//  BackgroundSyncCoordinator.swift
//  CapsizedVault
//
//  Keeps the active Zcash wallet syncing a little past the user leaving the app, and
//  occasionally overnight while charging on Wi-Fi. Monero is out of scope here —
//  CapsizedMoneroKit's `Kit` pauses itself the instant the app backgrounds (see
//  `Kit.handleDidEnterBackground`), with no public opt-out, so Monero background sync needs
//  its own follow-up phase with additive Kit API.
//
//  Two distinct code paths, both driven from here:
//   (a) App backgrounds while still running: the active wallet's engine/seed are already
//       resident in memory from the foreground session, so continuing the sync needs no
//       Keychain read — just extra run time via `beginBackgroundTask`.
//   (b) Process was killed and a scheduled `BGProcessingTask` cold-launches the app: this
//       goes through the normal `WalletManager`/`activate()` path, which does read Keychain.
//       If the device is locked, that read fails and the run is skipped — an accepted
//       tradeoff, not a case to engineer around (see the Zcash plan memory).
//

import Foundation
import UIKit
import BackgroundTasks
import Network
import RealmSwift

@MainActor
final class BackgroundSyncCoordinator {

    static let shared = BackgroundSyncCoordinator()

    static let processingTaskIdentifier = "io.capsized.vault.background-sync"
    static let rearmTaskIdentifier = "io.capsized.vault.background-sync-rearm"

    private static let enabledKey = "backgroundSyncEnabled"

    /// Must be called once at app launch (see `CapsizedVaultApp.init`), before `registerTasks()`,
    /// so `isEnabled` reads a real default instead of `UserDefaults`' own type-less nil.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [enabledKey: true])
    }

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    // MARK: - Registration

    /// Must be called before the app finishes launching (from `CapsizedVaultApp.init`) — iOS
    /// requires every `BGTaskScheduler` identifier to be registered that early, regardless of
    /// whether the user has the feature enabled.
    func registerTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.processingTaskIdentifier, using: .main) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else { return }
            MainActor.assumeIsolated {
                self?.handleProcessingTask(processingTask)
            }
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.rearmTaskIdentifier, using: .main) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            MainActor.assumeIsolated {
                self?.handleRearmTask(refreshTask)
            }
        }
    }

    // MARK: - Path (a): app entering background while still running

    func appDidEnterBackground() {
        guard Self.isEnabled else {
            BGTaskScheduler.shared.cancelAllTaskRequests()
            return
        }

        scheduleRequests()

        guard let zcashWallet = WalletManager.shared.activeWallet?.zcashWallet else { return }
        guard !isSynced(zcashWallet) else { return }

        let taskID = UIApplication.shared.beginBackgroundTask(withName: "io.capsized.vault.zcash-continue-sync") { [weak self] in
            self?.endBackgroundTask()
        }
        guard taskID != .invalid else { return }
        backgroundTaskID = taskID

        Task { [weak self] in
            _ = await zcashWallet.waitForSyncPass()
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    private func isSynced(_ wallet: ZECWallet) -> Bool {
        if case .synced = wallet.syncStatus { return true }
        return false
    }

    // MARK: - Setting changed from the UI

    func settingChanged(_ enabled: Bool) {
        if enabled {
            scheduleRequests()
        } else {
            BGTaskScheduler.shared.cancelAllTaskRequests()
        }
    }

    // MARK: - Scheduling

    private func scheduleRequests() {
        scheduleProcessing()
        scheduleRearm()
    }

    private func scheduleProcessing() {
        let request = BGProcessingTaskRequest(identifier: Self.processingTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func scheduleRearm() {
        let request = BGAppRefreshTaskRequest(identifier: Self.rearmTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Path (b): scheduled processing task, possibly a cold launch

    private func handleProcessingTask(_ task: BGProcessingTask) {
        // Keep a request pending at all times, independent of whether this run succeeds.
        scheduleProcessing()

        guard Self.isEnabled else {
            task.setTaskCompleted(success: false)
            return
        }

        let runTask = Task { [weak self] in
            guard let self else {
                task.setTaskCompleted(success: false)
                return
            }
            guard await self.isOnWifi() else {
                task.setTaskCompleted(success: false)
                return
            }
            // Checked with a raw Realm query, before ever touching `WalletManager.shared` —
            // on a cold launch, first access to that singleton runs its init, which activates
            // the most-recently-active wallet. If either check fails, bail before paying that
            // cost (and before any Keychain read a locked-device activation would also fail).
            guard UIApplication.shared.isProtectedDataAvailable, self.isLastActiveWalletZcash() else {
                task.setTaskCompleted(success: false)
                return
            }
            guard let zcashWallet = WalletManager.shared.activeWallet?.zcashWallet else {
                task.setTaskCompleted(success: false)
                return
            }
            let success = await zcashWallet.waitForSyncPass()
            task.setTaskCompleted(success: success)
        }

        task.expirationHandler = {
            runTask.cancel()
        }
    }

    private func handleRearmTask(_ task: BGAppRefreshTask) {
        scheduleRequests()
        task.setTaskCompleted(success: true)
    }

    // MARK: - Helpers

    private func isLastActiveWalletZcash() -> Bool {
        guard let realm = RealmManager.shared.getThreadSaveRealm(),
              let active = realm.objects(WalletsData.self).sorted(byKeyPath: "lastActive", ascending: false).first else {
            return false
        }
        return active.coin == Coin.zcash.rawValue
    }

    /// One-shot Wi-Fi check — `BGProcessingTask`'s own `requiresNetworkConnectivity` can't
    /// distinguish Wi-Fi from cellular, so this is checked explicitly before syncing.
    private func isOnWifi() async -> Bool {
        nonisolated final class ResumeOnce: @unchecked Sendable {
            private let lock = NSLock()
            private var done = false
            func run(_ body: () -> Void) {
                lock.lock()
                defer { lock.unlock() }
                guard !done else { return }
                done = true
                body()
            }
        }

        let resumeOnce = ResumeOnce()
        return await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
            monitor.pathUpdateHandler = { path in
                resumeOnce.run {
                    continuation.resume(returning: path.status == .satisfied)
                }
                monitor.cancel()
            }
            monitor.start(queue: DispatchQueue.global(qos: .utility))
        }
    }
}
