import SwiftUI
import CapsizedMoneroKit

/// Percent-decodes a node address for display. `URL.absoluteString` re-encodes any non-ASCII
/// characters (e.g. Cyrillic) as raw percent-escapes when reconstructing the string form, even
/// though the address was accepted and stored exactly as typed — this undoes that for
/// presentation only. Falls back to the raw string if decoding fails (e.g. a stray literal "%").
private func displayAddress(_ raw: String) -> String {
    raw.removingPercentEncoding ?? raw
}

struct NodeProbeStatus: Identifiable {
    let id: URL
    let host: String
    let isTrusted: Bool
    let isDefault: Bool
    var latencyMs: Int?
    var height: UInt64?
    var failed: Bool = false
    var checked: Bool = false
}

/// Value-type snapshot of a NodeData Realm object. Captured immediately on load so closures
/// never hold a reference to a live Realm object that can be invalidated after deletion.
private struct NodeSnapshot: Identifiable {
    let id: String
    let urlString: String
    let isTrusted: Bool
    let login: String
    let password: String

    init(_ nodeData: NodeData) {
        self.id = nodeData.urlString
        self.urlString = nodeData.urlString
        self.isTrusted = nodeData.isTrusted
        let credentials = nodeData.credentials
        self.login = credentials.login
        self.password = credentials.password
    }
}

// MARK: - Connection status

private enum NodeConnectionStatus {
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

// MARK: - NodeSettingsView

struct NodeSettingsView: View {

    @StateObject private var walletManager = WalletManager.shared
    @State private var customNodes: [NodeSnapshot] = []
    @State private var probeResults: [URL: NodeProbeStatus] = [:]
    @State private var isTesting = false
    @State private var openSwipeHost: String? = nil

    // Persisted node selection preference
    @AppStorage("nodeAutoSelect") private var autoSelect: Bool = true
    @AppStorage("nodePinnedURL") private var pinnedNodeURL: String = ""

    // Dialog state
    @State private var confirmHost: String? = nil
    @State private var confirmDeleteURL: String? = nil
    @State private var showTrustInfo = false
    @State private var editingNode: NodeSnapshot? = nil

    // Add-node form state
    @State private var showingAddNode = false
    @State private var addFormURL = ""
    @State private var addFormIsTrusted = false
    @State private var addFormLogin = ""
    @State private var addFormPassword = ""
    @State private var addFormError: String? = nil

    @Environment(\.dismiss) private var dismiss

    private var activeNodeURL: String {
        walletManager.activeWallet?.activeNodeURL ?? ""
    }

    private var connectionStatus: NodeConnectionStatus {
        guard let wallet = walletManager.activeWallet else { return .offline }
        switch wallet.walletState {
        case .synced, .syncing, .idle(daemonReachable: true):
            return .connected
        case .connecting:
            return .connecting
        case .notSynced, .idle(daemonReachable: false):
            return .offline
        }
    }

    private var activeNode: Node? {
        WalletManager.allNodes().first { $0.url.absoluteString == activeNodeURL }
    }

    private var isActiveNodeCustom: Bool {
        guard let activeNode else { return false }
        return !WalletManager.defaultNodes.contains(activeNode)
    }

    var body: some View {
        ZStack {
            mainContent
            if let host = confirmHost {
                confirmManualDialog(host: host)
            }
            if let deleteURL = confirmDeleteURL {
                confirmDeleteDialog(urlString: deleteURL)
            }
            if showTrustInfo {
                trustInfoDialog
            }
        }
        .onAppear {
            loadCustomNodes()
        }
        .onChange(of: autoSelect) { newValue in
            walletManager.activeWallet?.setAutoNodeSelectionEnabled(newValue)
            if newValue, isActiveNodeCustom, let bestURL = walletManager.activeWallet?.bestAutoSelectableNodeURL() {
                pinnedNodeURL = bestURL
                walletManager.activeWallet?.selectNode(urlString: bestURL)
            }
        }
        .sheet(isPresented: $showingAddNode) {
            addEditNodeSheet(editing: nil)
        }
        .sheet(item: $editingNode) { node in
            addEditNodeSheet(editing: node)
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    activeNodeCard
                        .padding(.horizontal, 20)

                    if let error = walletManager.activeWallet?.nodeSwitchError {
                        Text(error)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.dsDanger)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }

                    customNodesSection
                        .padding(.top, 22)

                    defaultNodesSection
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
            Text("Nodes")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dsTextPrimary)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 20)
    }

    // MARK: - Active node card

    private var activeNodeCard: some View {
        VStack(spacing: 0) {
            // Upper: auto switch row
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Choose node automatically")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.dsTextPrimary)
                    Text(autoSelect
                         ? "The app keeps you on a reachable node and moves you if it stops responding."
                         : "You stay on the node you picked, even if it stops responding.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dsTextSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: $autoSelect)
                    .labelsHidden()
                    .tint(Color.dsAccent)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 16)

            // Lower: active node info
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text("Active node")
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

                Text(activeNodeURL.isEmpty ? "—" : displayAddress(activeNodeURL))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.dsTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)

                HStack(alignment: .center, spacing: 6) {
                    trustBadge(for: activeNode)

                    // Info button — visual 18px, tap target 44px
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showTrustInfo = true } }) {
                        ZStack {
                            Circle()
                                .strokeBorder(Color.dsBorder, lineWidth: 1)
                                .frame(width: 18, height: 18)
                            Text("?")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.dsTextTertiary)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .padding(.trailing, -13)
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .background(Color.dsSurfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func trustBadge(for node: Node?) -> some View {
        if let node {
            if node.isTrusted {
                Text("Trusted")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.dsAccentStrong)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.dsJadeSoft)
                    .clipShape(Capsule())
            } else {
                Text("Untrusted")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.dsTextSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.dsSurfaceRaised)
                    .overlay(Capsule().stroke(Color.dsBorder, lineWidth: 1))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Custom nodes section

    private var customNodesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if customNodes.isEmpty {
                addNodePillButton
                    .padding(.horizontal, 20)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    sectionLabel("Custom nodes")
                    Spacer()
                    Text("Swipe to edit or delete")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dsTextTertiary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(Array(customNodes.enumerated()), id: \.element.id) { index, nodeData in
                        if index > 0 { Divider() }
                        if let url = URL(string: nodeData.urlString) {
                            let node = Node(
                                url: url,
                                isTrusted: nodeData.isTrusted,
                                login: nodeData.login.isEmpty ? nil : nodeData.login,
                                password: nodeData.password.isEmpty ? nil : nodeData.password
                            )
                            SwipeToEditDeleteRow(
                                isOpen: openSwipeHost == nodeData.urlString,
                                onOpenChange: { open in openSwipeHost = open ? nodeData.urlString : nil },
                                onEdit: { editingNode = nodeData },
                                onDelete: { withAnimation(.easeInOut(duration: 0.2)) { confirmDeleteURL = nodeData.urlString } }
                            ) {
                                nodeRow(node: node)
                            }
                        }
                    }
                    Divider()
                    addNodeListRowButton
                }
                .background(Color.dsSurfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsBorder, lineWidth: 1))
                .padding(.horizontal, 20)
            }
        }
    }

    // Ghost pill — shown when the custom list is empty
    private var addNodePillButton: some View {
        Button(action: { resetAddNodeForm(); showingAddNode = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text("Add custom node")
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

    // Final row of the list card when custom nodes are present
    private var addNodeListRowButton: some View {
        Button(action: { resetAddNodeForm(); showingAddNode = true }) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text("Add custom node")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(Color.dsTextPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Default nodes section

    private var defaultNodesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                sectionLabel("Default nodes")
                Spacer()
                Button(action: testAllNodes) {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView()
                                .tint(Color.dsAccentStrong)
                                .scaleEffect(0.75)
                                .frame(width: 15, height: 15)
                        } else {
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text(isTesting ? "Testing…" : "Test all")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.dsAccentStrong)
                    .opacity(isTesting ? 0.7 : 1)
                }
                .disabled(isTesting)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(WalletManager.defaultNodes.enumerated()), id: \.element.url) { index, node in
                    if index > 0 { Divider() }
                    nodeRow(node: node)
                }
            }
            .background(Color.dsSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsBorder, lineWidth: 1))
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Node row

    private func nodeRow(node: Node) -> some View {
        let probeStatus = probeResults[node.url]
        let isSelected = node.url.absoluteString == activeNodeURL
        let isPending = node.url.absoluteString == walletManager.activeWallet?.pendingNodeURL
        // Custom nodes are never eligible for auto-selection, so they must never show the "Auto"
        // badge — including transiently, e.g. while activeNodeURL hasn't caught up yet during
        // the brief window right after re-enabling auto-select from a pinned custom node.
        let isDefault = WalletManager.defaultNodes.contains(node)
        return NodeRowView(
            node: node,
            probeStatus: probeStatus,
            isSelected: isSelected,
            isPending: isPending,
            showAutoBadge: isSelected && autoSelect && isDefault,
            onSelect: { handleNodeSelection(node: node) }
        )
    }

    // MARK: - Selection logic

    private func handleNodeSelection(node: Node) {
        // Ignore taps on a different node while a switch is already in flight, rather
        // than queuing multiple switchToNode calls back-to-back.
        if let pending = walletManager.activeWallet?.pendingNodeURL, pending != node.url.absoluteString {
            return
        }
        guard node.url.absoluteString != activeNodeURL else { return }
        if autoSelect {
            withAnimation(.easeInOut(duration: 0.2)) { confirmHost = node.url.absoluteString }
        } else {
            pinnedNodeURL = node.url.absoluteString
            walletManager.activeWallet?.selectNode(urlString: node.url.absoluteString)
        }
    }

    // MARK: - Confirm manual dialog

    @ViewBuilder
    private func confirmManualDialog(host: String) -> some View {
        ZStack {
            Color(red: 27/255, green: 35/255, blue: 32/255).opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { confirmHost = nil } }
                .transition(.opacity)

            VStack(alignment: .leading, spacing: 0) {
                Text("Choose this node yourself?")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dsTextPrimary)

                Text("Automatic selection will be turned off and the wallet will stay on this node.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsTextSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                Text(displayAddress(host))
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
                        pinnedNodeURL = host
                        autoSelect = false
                        walletManager.activeWallet?.selectNode(urlString: host)
                        withAnimation(.easeInOut(duration: 0.2)) { confirmHost = nil }
                    }) {
                        Text("Turn off automatic")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.dsAccent)
                            .clipShape(Capsule())
                    }

                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { confirmHost = nil } }) {
                        Text("Keep automatic")
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

    // MARK: - Confirm delete dialog

    @ViewBuilder
    private func confirmDeleteDialog(urlString: String) -> some View {
        ZStack {
            Color(red: 27/255, green: 35/255, blue: 32/255).opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { confirmDeleteURL = nil } }
                .transition(.opacity)

            VStack(alignment: .leading, spacing: 0) {
                Text("Delete this node?")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dsTextPrimary)

                Text("Are you sure? This can't be undone.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsTextSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                Text(displayAddress(urlString))
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
                        deleteCustomNodeByURL(urlString)
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

    // MARK: - Trust info dialog

    private var trustInfoDialog: some View {
        ZStack {
            Color(red: 27/255, green: 35/255, blue: 32/255).opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showTrustInfo = false } }
                .transition(.opacity)

            VStack(alignment: .leading, spacing: 0) {
                Text("Trusted and untrusted nodes")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dsTextPrimary)

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trusted")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.dsAccentStrong)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.dsJadeSoft)
                            .clipShape(Capsule())
                        Text("A node you run or control. The wallet can ask it for more detail, which makes syncing faster.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.dsTextSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Untrusted")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.dsTextSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.dsSurfaceRaised)
                            .overlay(Capsule().stroke(Color.dsBorder, lineWidth: 1))
                            .clipShape(Capsule())
                        Text("Someone else's node. The wallet keeps more work to itself, so the operator learns less about you. Your keys never leave this device either way.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.dsTextSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 14)

                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showTrustInfo = false } }) {
                    Text("Got it")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.dsAccent)
                        .clipShape(Capsule())
                }
                .padding(.top, 22)
            }
            .padding(24)
            .background(Color.dsBackground)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 20)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }

    // MARK: - Add / Edit node sheet

    @ViewBuilder
    private func addEditNodeSheet(editing: NodeSnapshot?) -> some View {
        AddEditNodeSheet(
            editing: editing,
            onAdd: { urlString, isTrusted, login, password in
                let success = WalletManager.addCustomNode(
                    urlString: urlString, isTrusted: isTrusted, login: login, password: password
                )
                if success {
                    // Register the new node with the live pool so it can be selected right away
                    walletManager.activeWallet?.syncNodePool()
                    showingAddNode = false
                    loadCustomNodes()
                    if autoSelect {
                        // Ask, same as tapping an existing row would, rather than switching silently
                        withAnimation(.easeInOut(duration: 0.2)) { confirmHost = urlString }
                    } else {
                        pinnedNodeURL = urlString
                        walletManager.activeWallet?.selectNode(urlString: urlString)
                    }
                }
                return success
            },
            onUpdate: { oldURL, newURL, isTrusted, login, password in
                let success = WalletManager.updateCustomNode(
                    oldURLString: oldURL, newURLString: newURL,
                    isTrusted: isTrusted, login: login, password: password
                )
                if success {
                    let wasActive = activeNodeURL == oldURL
                    // If the edited node was selected, follow the rename
                    if pinnedNodeURL == oldURL { pinnedNodeURL = newURL }
                    walletManager.activeWallet?.syncNodePool()
                    if wasActive {
                        walletManager.activeWallet?.selectNode(urlString: newURL)
                        // Now that the old URL is no longer active, prune it from the live pool
                        walletManager.activeWallet?.syncNodePool()
                    }
                    editingNode = nil
                    loadCustomNodes()
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

    private func testAllNodes() {
        guard let activeWallet = walletManager.activeWallet else { return }
        isTesting = true
        let defaultURLs = Set(WalletManager.defaultNodes.map(\.url))

        let nodes = activeWallet.testAllNodes { node, metrics in
            DispatchQueue.main.async {
                var status = self.probeResults[node.url] ?? NodeProbeStatus(
                    id: node.url, host: node.url.absoluteString,
                    isTrusted: node.isTrusted, isDefault: defaultURLs.contains(node.url)
                )
                status.checked = true
                if metrics.lastResponseTime == nil {
                    status.failed = true
                } else {
                    status.failed = false
                    status.latencyMs = Int((metrics.lastResponseTime ?? 0) * 1000)
                    status.height = metrics.lastKnownHeight
                }
                self.probeResults[node.url] = status
                if self.probeResults.values.allSatisfy(\.checked) { self.isTesting = false }
            }
        }

        var fresh: [URL: NodeProbeStatus] = [:]
        for node in nodes {
            fresh[node.url] = NodeProbeStatus(
                id: node.url, host: node.url.absoluteString,
                isTrusted: node.isTrusted, isDefault: defaultURLs.contains(node.url)
            )
        }
        probeResults = fresh
    }

    private func loadCustomNodes() {
        customNodes = WalletManager.getCustomNodes().map { NodeSnapshot($0) }
    }

    private func deleteCustomNodeByURL(_ urlString: String) {
        _ = WalletManager.removeCustomNode(urlString: urlString)
        if openSwipeHost == urlString { openSwipeHost = nil }
        let wasActive = activeNodeURL == urlString
        if pinnedNodeURL == urlString {
            pinnedNodeURL = WalletManager.defaultNodes.first?.url.absoluteString ?? ""
        }
        walletManager.activeWallet?.syncNodePool()
        // The pool keeps the active node alive even after removal, so explicitly move
        // the wallet off it onto a default node that's always present in the pool,
        // then prune the removed node now that it's no longer active.
        if wasActive, let fallback = WalletManager.defaultNodes.first {
            walletManager.activeWallet?.selectNode(urlString: fallback.url.absoluteString)
            walletManager.activeWallet?.syncNodePool()
        }
        loadCustomNodes()
    }

    private func resetAddNodeForm() {
        addFormURL = ""
        addFormIsTrusted = false
        addFormLogin = ""
        addFormPassword = ""
        addFormError = nil
    }

    private func pingColor(_ ms: Int) -> Color {
        if ms < 800  { return Color(red: 90/255, green: 143/255, blue: 62/255) }
        if ms < 2500 { return Color(red: 184/255, green: 134/255, blue: 11/255) }
        return .dsDanger
    }
}

// MARK: - NodeRowView

private struct NodeRowView: View {
    let node: Node
    let probeStatus: NodeProbeStatus?
    let isSelected: Bool
    let isPending: Bool
    let showAutoBadge: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            radioView
            centerContent
            Spacer(minLength: 10)
            trailingIndicator
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var rowBackground: Color {
        if isSelected { return .dsJadeSoft }
        return .clear
    }

    private var radioView: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Color.dsAccent : Color.dsBorder, lineWidth: 1.5)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(Color.dsAccent)
                    .frame(width: 22, height: 22)
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var centerContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Line 1: host — full width, word-break
            Text(displayAddress(node.url.absoluteString))
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(isSelected ? Color.dsAccentStrong : Color.dsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Line 2: badges and test data
            lineTwoContent
                .font(.system(size: 11))
                .foregroundStyle(Color.dsTextTertiary)
        }
    }

    @ViewBuilder
    private var lineTwoContent: some View {
        HStack(spacing: 6) {
            if showAutoBadge {
                Text("Auto")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.dsAccent)
                    .clipShape(Capsule())
            }

            if isPending {
                Text("Switching…")
                    .fontWeight(.bold)
                    .foregroundStyle(Color.dsAccentStrong)
            } else if let status = probeStatus {
                if !status.checked {
                    Text("Testing…")
                } else if status.failed {
                    Text("Failed to connect")
                        .fontWeight(.bold)
                        .foregroundStyle(Color.dsDanger)
                } else {
                    if let ms = status.latencyMs {
                        Text("\(ms) ms")
                            .fontWeight(.bold)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(pingColor(ms))
                    }
                    if let h = status.height, h > 0 {
                        Text("Height \(h)")
                            .foregroundStyle(Color.dsTextTertiary)
                    }
                }
            } else {
                if node.isTrusted {
                    Text("Trusted")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.dsAccentStrong)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.dsJadeSoft)
                        .clipShape(Capsule())
                } else if !showAutoBadge {
                    Text("Untrusted")
                }
            }
        }
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        Group {
            if isPending {
                ProgressView()
                    .tint(Color.dsAccentStrong)
                    .scaleEffect(0.75)
            } else if let status = probeStatus {
                if !status.checked {
                    ProgressView()
                        .tint(Color.dsTextTertiary)
                        .scaleEffect(0.75)
                } else if status.failed {
                    ZStack {
                        Circle().fill(Color.dsDanger)
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                } else if let ms = status.latencyMs {
                    PingMeterView(ms: ms)
                } else {
                    Color.clear
                }
            } else {
                Color.clear
            }
        }
        .frame(width: 18, height: 18)
    }

    private func pingColor(_ ms: Int) -> Color {
        if ms < 800  { return Color(red: 90/255, green: 143/255, blue: 62/255) }
        if ms < 2500 { return Color(red: 184/255, green: 134/255, blue: 11/255) }
        return .dsDanger
    }
}

// MARK: - PingMeterView

private struct PingMeterView: View {
    let ms: Int

    private var litBars: Int { ms < 800 ? 3 : ms < 2500 ? 2 : 1 }
    private var barColor: Color {
        if ms < 800  { return Color(red: 90/255, green: 143/255, blue: 62/255) }
        if ms < 2500 { return Color(red: 184/255, green: 134/255, blue: 11/255) }
        return .dsDanger
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i < litBars ? barColor : Color.dsBorder)
                    .frame(width: 3, height: [6, 10, 14][i])
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - SwipeToEditDeleteRow

private struct SwipeToEditDeleteRow<Content: View>: View {
    let isOpen: Bool
    let onOpenChange: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offsetX: CGFloat = 0
    private let revealWidth: CGFloat = 152
    private let actionWidth: CGFloat = 76

    var body: some View {
        ZStack(alignment: .trailing) {
            // Row content — stays in place; the action panel overlays it from the right
            content()
                .background(Color.dsSurfaceRaised)
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            let base: CGFloat = isOpen ? -revealWidth : 0
                            offsetX = max(-revealWidth, min(0, base + value.translation.width))
                        }
                        .onEnded { value in
                            let base: CGFloat = isOpen ? -revealWidth : 0
                            let final = max(-revealWidth, min(0, base + value.translation.width))
                            snap(open: final < -revealWidth / 2)
                        }
                )
                .simultaneousGesture(
                    TapGesture().onEnded {
                        if isOpen { snap(open: false) }
                    }
                )
                .onChange(of: isOpen) { newValue in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                        offsetX = newValue ? -revealWidth : 0
                    }
                }

            // Action panel — overlays the row from the right as it's revealed
            HStack(spacing: 0) {
                Button(action: { snap(open: false); DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onEdit() } }) {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .medium))
                        Text("Edit")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.dsTextPrimary)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.dsSurface2)
                }

                Button(action: { snap(open: false); DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDelete() } }) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .medium))
                        Text("Delete")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.dsDanger)
                }
            }
            .frame(width: revealWidth)
            .offset(x: revealWidth + offsetX)
        }
        .clipped()
    }

    private func snap(open: Bool) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
            onOpenChange(open)
            offsetX = open ? -revealWidth : 0
        }
    }
}

// MARK: - AddEditNodeSheet

private struct AddEditNodeSheet: View {
    let editing: NodeSnapshot?
    let onAdd: (String, Bool, String, String) -> Bool
    let onUpdate: (String, String, Bool, String, String) -> Bool

    @State private var url: String
    @State private var isTrusted: Bool
    @State private var login: String
    @State private var password: String
    @State private var error: String? = nil

    @Environment(\.dismiss) private var dismiss

    init(editing: NodeSnapshot?,
         onAdd: @escaping (String, Bool, String, String) -> Bool,
         onUpdate: @escaping (String, String, Bool, String, String) -> Bool) {
        self.editing = editing
        self.onAdd = onAdd
        self.onUpdate = onUpdate
        _url = State(initialValue: editing?.urlString ?? "")
        _isTrusted = State(initialValue: editing?.isTrusted ?? false)
        _login = State(initialValue: editing?.login ?? "")
        _password = State(initialValue: editing?.password ?? "")
    }

    private var isEditing: Bool { editing != nil }
    private var canSubmit: Bool { !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Grab handle
            RoundedRectangle(cornerRadius: 999)
                .fill(Color.dsBorder)
                .frame(width: 36, height: 4)
                .padding(.top, 14)
                .padding(.bottom, 18)

            // Header
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
                Text(isEditing ? "Edit node" : "Add node")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dsTextPrimary)
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Node URL")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dsTextTertiary)
                        .padding(.horizontal, 20)

                    TextField("http://node.example.com:18081", text: $url)
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

                    HStack {
                        Text("Trusted node")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.dsTextPrimary)
                        Spacer()
                        Toggle("", isOn: $isTrusted)
                            .labelsHidden()
                            .tint(Color.dsAccent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.dsSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsBorder, lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Text("Trusted nodes can see your real IP and link it to your transactions. Only mark nodes you operate yourself as trusted.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dsTextTertiary)
                        .lineSpacing(3)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    Text("Authentication (optional)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dsTextTertiary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    VStack(spacing: 0) {
                        TextField("Login", text: $login)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 15))
                            .foregroundStyle(Color.dsTextPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                        Divider()
                        SecureField("Password", text: $password)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.dsTextPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                    }
                    .background(Color.dsSurfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dsBorder, lineWidth: 1))
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
                        Text(isEditing ? "Save changes" : "Add node")
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
        }
        .background(Color.dsBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }

    private func formatError(for raw: String) -> String? {
        guard let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty,
              let port = url.port, (1...65535).contains(port) else {
            return "Enter a valid address with a port, e.g. http://node.example.com:18081"
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
            let success = onUpdate(editing!.urlString, trimmed, isTrusted, login, password)
            if !success { error = "Could not save changes" }
        } else {
            let success = onAdd(trimmed, isTrusted, login, password)
            if !success { error = "Node already exists or could not be saved" }
        }
    }
}
