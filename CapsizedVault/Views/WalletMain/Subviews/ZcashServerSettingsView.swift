//
//  ZcashServerSettingsView.swift
//  CapsizedVault
//
//  Zcash counterpart to NodeSettingsView. No per-server latency/height probing — the Zcash
//  SDK only exposes that through a live gRPC call per server, which is real extra work this
//  phase deliberately cuts (just a list to pick from, plus custom servers).
//

import SwiftUI
import CapsizedMoneroKit

/// Percent-decodes a server address for display, same reasoning as NodeSettingsView's
/// `displayAddress` (duplicated here rather than shared — it's ten lines, file-local).
private func displayZcashAddress(_ raw: String) -> String {
    raw.removingPercentEncoding ?? raw
}

private struct ZcashServerSnapshot: Identifiable {
    let id: String
    let urlString: String

    init(_ nodeData: NodeData) {
        self.id = nodeData.urlString
        self.urlString = nodeData.urlString
    }
}

private enum ZcashServerConnectionStatus {
    case connected, connecting, offline

    var dotColor: Color {
        switch self {
        case .connected:  return .dsAccent
        case .connecting: return Color(red: 184/255, green: 134/255, blue: 11/255)
        case .offline:    return .dsDanger
        }
    }

    var label: String {
        switch self {
        case .connected:  return "Connected"
        case .connecting: return "Connecting…"
        case .offline:    return "Not connected"
        }
    }

    var labelColor: Color {
        switch self {
        case .connected, .connecting: return .dsTextSecondary
        case .offline:                return .dsDanger
        }
    }
}

struct ZcashServerSettingsView: View {

    @StateObject private var walletManager = WalletManager.shared
    @State private var customServers: [ZcashServerSnapshot] = []
    @State private var openSwipeHost: String? = nil

    @AppStorage("zcashTorEnabled") private var torEnabled: Bool = true
    @AppStorage("zcashServerURL") private var selectedServerURLString: String = ZcashSettings.defaultServerURLString

    @State private var confirmDeleteURL: String? = nil
    @State private var editingServer: ZcashServerSnapshot? = nil
    @State private var showingAddServer = false

    @Environment(\.dismiss) private var dismiss

    private var activeWallet: ZECWallet? {
        walletManager.activeWallet?.zcashWallet
    }

    private var connectionStatus: ZcashServerConnectionStatus {
        guard let wallet = activeWallet else { return .offline }
        switch wallet.syncStatus {
        case .synced, .syncing:
            return .connected
        case .connecting:
            return .connecting
        case .idle, .error:
            return .offline
        }
    }

    var body: some View {
        ZStack {
            mainContent
            if let deleteURL = confirmDeleteURL {
                confirmDeleteDialog(urlString: deleteURL)
            }
        }
        .onAppear { loadCustomServers() }
        .onChange(of: torEnabled) { _ in activeWallet?.restartSync() }
        .sheet(isPresented: $showingAddServer) {
            addEditServerSheet(editing: nil)
        }
        .sheet(item: $editingServer) { server in
            addEditServerSheet(editing: server)
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    torCard
                        .padding(.horizontal, 20)

                    activeServerCard
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    customServersSection
                        .padding(.top, 22)

                    defaultServersSection
                        .padding(.top, 20)
                }
                .padding(.bottom, 28)
            }
        }
        .background(Color.dsBackground)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.dsJadeSoft)
                        .frame(width: 36, height: 36)
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dsAccentStrong)
                }
            }
            Spacer()
            Text("Servers")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dsTextPrimary)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }

    // MARK: - Tor card

    private var torCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Zcash traffic only")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.dsTextPrimary)
                    Text("Routes transaction submission, lookups and server requests through Tor. Block sync and transparent-address fetches still go direct — everyone downloads the same blocks, so there's no privacy loss there. This never affects Monero.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dsTextSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: $torEnabled)
                    .labelsHidden()
                    .tint(Color.dsAccent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsBorder, lineWidth: 1))
    }

    // MARK: - Active server card

    private var activeServerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text("Active server")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dsTextTertiary)
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(connectionStatus.dotColor)
                        .frame(width: 7, height: 7)
                    Text(connectionStatus.label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(connectionStatus.labelColor)
                }
            }

            Text(displayZcashAddress(selectedServerURLString))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.dsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsBorder, lineWidth: 1))
    }

    // MARK: - Custom servers section

    private var customServersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if customServers.isEmpty {
                addServerPillButton
                    .padding(.horizontal, 20)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    sectionLabel("Custom servers")
                    Spacer()
                    Text("Swipe to edit or delete")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dsTextTertiary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(Array(customServers.enumerated()), id: \.element.id) { index, server in
                        if index > 0 { Divider() }
                        SwipeToEditDeleteRow(
                            isOpen: openSwipeHost == server.urlString,
                            onOpenChange: { open in openSwipeHost = open ? server.urlString : nil },
                            onEdit: { editingServer = server },
                            onDelete: { withAnimation(.easeInOut(duration: 0.2)) { confirmDeleteURL = server.urlString } }
                        ) {
                            serverRow(urlString: server.urlString)
                        }
                    }
                    Divider()
                    addServerListRowButton
                }
                .background(Color.dsSurfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsBorder, lineWidth: 1))
                .padding(.horizontal, 20)
            }
        }
    }

    private var addServerPillButton: some View {
        Button(action: { showingAddServer = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text("Add custom server")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(Color.dsTextPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .overlay(Capsule().stroke(Color.dsBorder, lineWidth: 1))
            .clipShape(Capsule())
        }
    }

    private var addServerListRowButton: some View {
        Button(action: { showingAddServer = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text("Add custom server")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(Color.dsTextPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Default servers section

    private var defaultServersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Default servers")
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(NodeStore.defaults(for: .zcash).enumerated()), id: \.element.url) { index, node in
                    if index > 0 { Divider() }
                    serverRow(urlString: node.url.absoluteString)
                }
            }
            .background(Color.dsSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsBorder, lineWidth: 1))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Server row

    private func serverRow(urlString: String) -> some View {
        let isSelected = urlString == selectedServerURLString
        return HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .strokeBorder(isSelected ? Color.dsAccent : Color.dsBorder, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle().fill(Color.dsAccent).frame(width: 22, height: 22)
                    Circle().fill(Color.white).frame(width: 8, height: 8)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isSelected)

            Text(displayZcashAddress(urlString))
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(isSelected ? Color.dsAccentStrong : Color.dsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 10)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(isSelected ? Color.dsJadeSoft : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { selectServer(urlString) }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Confirm delete dialog

    @ViewBuilder
    private func confirmDeleteDialog(urlString: String) -> some View {
        ZStack {
            Color(red: 27/255, green: 35/255, blue: 32/255).opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { confirmDeleteURL = nil } }
                .transition(.opacity)

            VStack(alignment: .leading, spacing: 0) {
                Text("Delete this server?")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dsTextPrimary)

                Text("Are you sure? This can't be undone.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsTextSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                Text(displayZcashAddress(urlString))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.dsTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.dsSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsBorder, lineWidth: 1))
                    .padding(.top, 12)

                VStack(spacing: 10) {
                    Button(action: {
                        deleteCustomServer(urlString)
                        withAnimation(.easeInOut(duration: 0.2)) { confirmDeleteURL = nil }
                    }) {
                        Text("Delete")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.dsDanger)
                            .clipShape(Capsule())
                    }

                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { confirmDeleteURL = nil } }) {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.dsTextPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .overlay(Capsule().stroke(Color.dsBorder, lineWidth: 1))
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 20)
            }
            .padding(24)
            .background(Color.dsBackground)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 20)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }

    // MARK: - Add / Edit server sheet

    @ViewBuilder
    private func addEditServerSheet(editing: ZcashServerSnapshot?) -> some View {
        AddEditZcashServerSheet(
            editing: editing,
            onAdd: { urlString in
                let success = NodeStore.addCustomNode(urlString: urlString, isTrusted: false, login: "", password: "", coin: .zcash)
                if success {
                    showingAddServer = false
                    loadCustomServers()
                }
                return success
            },
            onUpdate: { oldURL, newURL in
                let success = NodeStore.updateCustomNode(oldURLString: oldURL, newURLString: newURL, isTrusted: false, login: "", password: "", coin: .zcash)
                if success {
                    if selectedServerURLString == oldURL { selectServer(newURL) }
                    editingServer = nil
                    loadCustomServers()
                }
                return success
            }
        )
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color.dsTextTertiary)
    }

    private func loadCustomServers() {
        customServers = NodeStore.custom(for: .zcash).map { ZcashServerSnapshot($0) }
    }

    /// Switching servers restarts the active Zcash wallet's sync — `SDKZcashEngine` only reads
    /// `ZcashSettings.endpoint` once, at construction, so there's no live "switch node" the way
    /// Monero's `selectNode` has.
    private func selectServer(_ urlString: String) {
        guard urlString != selectedServerURLString else { return }
        selectedServerURLString = urlString
        activeWallet?.restartSync()
    }

    private func deleteCustomServer(_ urlString: String) {
        _ = NodeStore.removeCustomNode(urlString: urlString, coin: .zcash)
        if openSwipeHost == urlString { openSwipeHost = nil }
        if selectedServerURLString == urlString {
            selectServer(NodeStore.defaults(for: .zcash).first?.url.absoluteString ?? ZcashSettings.defaultServerURLString)
        }
        loadCustomServers()
    }
}

// MARK: - AddEditZcashServerSheet

private struct AddEditZcashServerSheet: View {
    let editing: ZcashServerSnapshot?
    let onAdd: (String) -> Bool
    let onUpdate: (String, String) -> Bool

    @State private var url: String
    @State private var error: String? = nil

    @Environment(\.dismiss) private var dismiss

    init(editing: ZcashServerSnapshot?, onAdd: @escaping (String) -> Bool, onUpdate: @escaping (String, String) -> Bool) {
        self.editing = editing
        self.onAdd = onAdd
        self.onUpdate = onUpdate
        _url = State(initialValue: editing?.urlString ?? "")
    }

    private var isEditing: Bool { editing != nil }
    private var canSubmit: Bool { !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 999)
                .fill(Color.dsBorder)
                .frame(width: 36, height: 4)
                .padding(.top, 14)
                .padding(.bottom, 18)

            HStack {
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle().fill(Color.dsJadeSoft).frame(width: 36, height: 36)
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.dsAccentStrong)
                    }
                }
                Spacer()
                Text(isEditing ? "Edit server" : "Add server")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)

            VStack(alignment: .leading, spacing: 0) {
                Text("Server address")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dsTextTertiary)
                    .padding(.horizontal, 20)

                TextField("https://lightwalletd.example.com:9067", text: $url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(Color.dsTextPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(Color.dsSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dsBorder, lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .onChange(of: url) { newValue in
                        guard error != nil else { return }
                        error = formatError(for: newValue.trimmingCharacters(in: .whitespacesAndNewlines))
                    }

                Text("Always connects over TLS.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.dsTextTertiary)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if let error {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.dsDanger)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }

                Button(action: submit) {
                    Text(isEditing ? "Save changes" : "Add server")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.dsTextOnAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(canSubmit ? Color.dsAccent : Color.dsAccent.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!canSubmit)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
        .background(Color.dsBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }

    private func formatError(for raw: String) -> String? {
        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty,
              let port = url.port, (1...65535).contains(port) else {
            return "Enter a valid address with a port, e.g. https://lightwalletd.example.com:9067"
        }
        return nil
    }

    private func submit() {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if let formatError = formatError(for: trimmed) {
            error = formatError
            return
        }
        if isEditing {
            let success = onUpdate(editing!.urlString, trimmed)
            if !success { error = "Could not save changes" }
        } else {
            let success = onAdd(trimmed)
            if !success { error = "Server already exists or could not be saved" }
        }
    }
}
