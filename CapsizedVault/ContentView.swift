//
//  ContentView.swift
//  CapsizedVault
//
//  Created by Dmitrij on 05/12/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var isLoading = true
    @State private var showSecurityOnboarding = false
    @State private var showOptionalUpdate = false
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var updateManager = AppUpdateManager.shared
    @State private var privacyOverlayTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            MainView()
                .opacity(isLoading ? 0 : 1)

            if isLoading {
                SplashScreen()
                    .transition(.opacity)
            }

            if case let .forceUpdate(version, message, url) = updateManager.updateState {
                ForceUpdateView(version: version, message: message, url: url)
                    .transition(.opacity)
            }

            if showOptionalUpdate, case let .optionalUpdate(version, message, url) = updateManager.updateState {
                UpdateAvailableDialog(
                    version: version,
                    message: message,
                    url: url,
                    onLater: { showOptionalUpdate = false },
                    onUpdate: { UIApplication.shared.open(url); showOptionalUpdate = false }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: isLoading)
        .animation(.easeOut(duration: 0.3), value: updateManager.updateState)
        .animation(.easeOut(duration: 0.2), value: showOptionalUpdate)
        .onChange(of: scenePhase) { newPhase in
            updatePrivacyOverlay(for: newPhase)
            if newPhase == .active {
                Task { await updateManager.checkForUpdate() }
            }
        }
        .onChange(of: authManager.isLocked) { locked in
            if !isLoading {
                OverlayWindowManager.shared.setLockScreenVisible(locked)
            }
        }
        .onChange(of: updateManager.updateState) { state in
            if case .optionalUpdate = state {
                showOptionalUpdate = true
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(2))
            isLoading = false
            if authManager.isLocked {
                OverlayWindowManager.shared.setLockScreenVisible(true)
            }
            if authManager.shouldShowSecurityOnboarding {
                showSecurityOnboarding = true
            }
        }
        .sheet(isPresented: $showSecurityOnboarding) {
            SecurityOnboardingView()
                .interactiveDismissDisabled()
        }

    }

    private func updatePrivacyOverlay(for phase: ScenePhase) {
        privacyOverlayTask?.cancel()

        switch phase {
        case .active:
            OverlayWindowManager.shared.setPrivacyOverlayVisible(false)
        case .inactive:
            privacyOverlayTask = Task {
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                OverlayWindowManager.shared.setPrivacyOverlayVisible(true)
            }
        case .background:
            OverlayWindowManager.shared.setPrivacyOverlayVisible(true)
        @unknown default:
            break
        }
    }
}

private struct ForceUpdateView: View {
    let version: String
    let message: String?
    let url: URL
    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            // Decorative: filled jade circle bleeding off top-right
            Circle()
                .fill(Color.dsJadeSoft)
                .frame(width: 200, height: 200)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 50, y: -60)

            // Decorative: dashed jade circle bleeding off left
            Circle()
                .stroke(Color.green700.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4]))
                .frame(width: 120, height: 120)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -40, y: 70)

            VStack(spacing: 16) {
                // Icon tile
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.dsAccent)
                        .frame(width: 64, height: 64)
                    Image(systemName: "arrow.down")
                        .font(.system(size: 30, weight: .regular, design: .rounded))
                        .foregroundStyle(.white)
                }

                Text("Update Required")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dsTextPrimary)

                VStack(spacing: 6) {
                    Text("A new version is available.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.dsTextSecondary)
                        .multilineTextAlignment(.center)

                    if let changelog = message {
                        Text("Version \(version) \u{2014} \(changelog)")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.dsTextTertiary)
                            .multilineTextAlignment(.center)
                    } else {
                        EmptyView()
                    }
                }

                Button {
                    UIApplication.shared.open(url)
                } label: {
                    Text("Update Now")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.dsAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 28)
        }
    }
}

private struct UpdateAvailableDialog: View {
    let version: String
    let message: String?
    let url: URL
    let onLater: () -> Void
    let onUpdate: () -> Void

    var body: some View {
        ZStack {
            Color(red: 27/255, green: 35/255, blue: 32/255)
                .opacity(0.45)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("Update Available")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dsTextPrimary)

                Text("A new version is available.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(.top, 8)

                if let changelog = message {
                    Text("Version \(version) \u{2014} \(changelog)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.dsTextTertiary)
                        .padding(.top, 10)
                } else {
                    EmptyView()
                }

                VStack(spacing: 10) {
                    Button(action: onUpdate) {
                        Text("Update")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.dsAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: onLater) {
                        Text("Later")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.dsTextTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .background(Color.dsBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 28)
        }
    }
}

private struct PrivacyOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var overlayBackground: Color {
        colorScheme == .dark
            ? Color(red: 14/255, green: 22/255, blue: 20/255)
            : .dsBackground
    }

    private var circleBackground: Color {
        colorScheme == .dark
            ? Color(red: 184/255, green: 201/255, blue: 98/255, opacity: 0.20)
            : .dsJadeSoft
    }

    private var lockIconColor: Color {
        colorScheme == .dark
            ? Color(red: 184/255, green: 201/255, blue: 98/255)
            : .green700
    }

    var body: some View {
        ZStack {
            overlayBackground
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(circleBackground)
                        .frame(width: 76, height: 76)

                    Image(systemName: "lock")
                        .font(.system(size: 32, weight: .regular, design: .rounded))
                        .foregroundStyle(lockIconColor)
                }

                VStack(spacing: 6) {
                    Text("Capsized")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .tracking(-0.3)
                        .foregroundStyle(Color.primary)

                    Text("Content hidden")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }
}

struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.dsBackground
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("CAPSIZED VAULT")
                    .font(.dsDisplayLG)
                    .tracking(3)
                    .foregroundColor(.dsTextPrimary)

                Text("What goes under, stays under.")
                    .font(.dsBodyLG)
                    .foregroundColor(.dsTextSecondary)
            }
        }
    }
}

@MainActor
private class OverlayWindowManager {
    static let shared = OverlayWindowManager()

    private var lockWindow: UIWindow?
    private var privacyWindow: UIWindow?

    private func windowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
    }

    func setLockScreenVisible(_ visible: Bool) {
        if visible {
            guard lockWindow == nil, let scene = windowScene() else { return }
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            window.rootViewController = UIHostingController(rootView: LockScreenView())
            window.makeKeyAndVisible()
            lockWindow = window
        } else {
            UIView.animate(withDuration: 0.3) {
                self.lockWindow?.alpha = 0
            } completion: { _ in
                self.lockWindow?.isHidden = true
                self.lockWindow = nil
            }
        }
    }

    func setPrivacyOverlayVisible(_ visible: Bool) {
        if visible {
            guard privacyWindow == nil, let scene = windowScene() else { return }
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 2
            window.rootViewController = UIHostingController(rootView: PrivacyOverlayView())
            window.makeKeyAndVisible()
            privacyWindow = window
        } else {
            privacyWindow?.isHidden = true
            privacyWindow = nil
        }
    }
}

#Preview {
    ContentView()
}
