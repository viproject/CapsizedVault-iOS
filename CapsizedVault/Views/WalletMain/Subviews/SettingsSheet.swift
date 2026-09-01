//
//  SettingsSheet.swift
//  CapsizedVault
//
//  Bottom sheet: wallet settings entry point — three grouped cards.
//  Each row drills into an existing sub-screen.
//

import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSecurity: () -> Void
    let onNodes: () -> Void
    let onBackup: () -> Void
    let onEditWallet: () -> Void
    let onRemoveWallet: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.dsTextPrimary)
                .padding(.bottom, 16)

            // Card 1: Security, Nodes
            settingsCard {
                SettingsRow(label: "Security", icon: "lock.shield.fill", isLast: false) {
                    onSecurity(); dismiss()
                }
                SettingsRow(label: "Nodes", icon: "antenna.radiowaves.left.and.right", isLast: true) {
                    onNodes(); dismiss()
                }
            }

            // Card 2: Backup, Edit
            settingsCard {
                SettingsRow(label: "Backup wallet", icon: "arrow.up.doc.fill", isLast: false) {
                    onBackup(); dismiss()
                }
                SettingsRow(label: "Edit wallet", icon: "pencil", isLast: true) {
                    onEditWallet(); dismiss()
                }
            }
            .padding(.top, 14)

            // Card 3: Remove wallet (danger)
            settingsCard {
                SettingsRow(label: "Remove wallet", icon: "trash.fill", isDanger: true, isLast: true) {
                    onRemoveWallet(); dismiss()
                }
            }
            .padding(.top, 14)

            // Privacy policy link
            if let urlString = Bundle.main.infoDictionary?["PrivacyPolicyURL"] as? String,
               let url = URL(string: urlString) {
                Link("Privacy Policy", destination: url)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.dsTextSecondary)
                    .underline()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            }

            // Version + git commit
            Text(Self.buildLabel)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(Color.dsTextTertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 28)
        .background(Color.dsSurface.ignoresSafeArea())
    }

    private static var buildLabel: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let commit = info?["GitCommit"] as? String ?? "unknown"
        return "v\(version) (\(commit))"
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.dsBorder, lineWidth: 1)
        )
    }
}

private struct SettingsRow: View {
    let label: String
    let icon: String
    var isDanger: Bool = false
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    // Icon tile
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isDanger ? Color.dsDanger.opacity(0.10) : Color.dsSurface2)
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(isDanger ? Color.dsDanger : Color.dsTextSecondary)
                    }
                    .frame(width: 32, height: 32)

                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isDanger ? Color.dsDanger : Color.dsTextPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isDanger ? Color.dsDanger : Color.dsTextTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isLast {
                Divider()
                    .padding(.leading, 60)
            }
        }
    }
}
