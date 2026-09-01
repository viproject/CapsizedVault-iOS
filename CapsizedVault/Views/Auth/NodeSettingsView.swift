import SwiftUI
import CapsizedMoneroKit

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
    let id: String        // urlString used as stable identity
    let urlString: String
    let isTrusted: Bool
    let login: String
    let password: String

    init(_ nodeData: NodeData) {
        self.id = nodeData.urlString
        self.urlString = nodeData.urlString
        self.isTrusted = nodeData.isTrusted
        self.login = nodeData.login
        self.password = nodeData.password
    }
}

struct NodeSettingsView: View {

    @StateObject private var walletManager = WalletManager.shared
    @State private var customNodes: [NodeSnapshot] = []
    @State private var showingAddNode = false
    @State private var newNodeURL = ""
    @State private var newNodeIsTrusted = false
    @State private var newNodeLogin = ""
    @State private var newNodePassword = ""
    @State private var addNodeError: String?
    @State private var probeResults: [URL: NodeProbeStatus] = [:]
    @State private var isTesting = false
    @State private var openSwipeHost: String? = nil

    @Environment(\.dismiss) private var dismiss

    private var activeNodeURL: String {
        walletManager.activeWallet?.activeNodeURL ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionLabel("Active node")
                        .padding(.horizontal, 20)

                    activeNodeCard
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    #if DEBUG
                    testNodesButton
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    Text("Connects to every node and measures response time.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dsTextTertiary)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    #endif

                    defaultNodesSection
                        .padding(.top, 20)

                    #if DEBUG
                    customNodesSection
                        .padding(.top, 20)
                    #endif
                }
                .padding(.bottom, 28)
            }
        }
        .background(Color.dsBackground)
        .onAppear {
            loadCustomNodes()
            loadExistingMetrics()
        }
        .sheet(isPresented: $showingAddNode) {
            addNodeSheet
        }
    }

    // MARK: - Layout

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 999)
            .fill(Color.dsBorder)
            .frame(width: 36, height: 4)
            .padding(.top, 14)
            .padding(.bottom, 18)
    }

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
        .padding(.bottom, 20)
    }

    private var activeNodeCard: some View {
        Text(displayHost(activeNodeURL))
            .font(.system(size: 15, design: .monospaced))
            .foregroundStyle(Color.dsTextPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.dsSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
    }

    #if DEBUG
    private var testNodesButton: some View {
        Button(action: testAllNodes) {
            HStack(spacing: 10) {
                Image(systemName: "qrcode")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.dsAccentStrong)
                Text("Test all nodes")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dsAccentStrong)
                Spacer()
                if isTesting {
                    ProgressView()
                        .tint(Color.dsAccentStrong)
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dsAccentStrong)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.dsJadeSoft)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isTesting)
        .opacity(isTesting ? 0.7 : 1)
    }
    #endif

    private var defaultNodesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel("Default nodes")
                Spacer()
                Text("Can't be removed")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dsTextTertiary)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(WalletManager.defaultNodes.enumerated()), id: \.element.url) { index, node in
                    if index > 0 {
                        Divider()
                    }
                    nodeResultRow(node: node)
                }
            }
            .background(Color.dsSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }

    #if DEBUG
    private var customNodesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel("Custom nodes")
                Spacer()
                if !customNodes.isEmpty {
                    Text("Swipe to delete")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.dsTextTertiary)
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                if customNodes.isEmpty {
                    Text("No custom nodes added")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.dsTextTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                } else {
                    ForEach(Array(customNodes.enumerated()), id: \.element.id) { index, nodeData in
                        if index > 0 {
                            Divider()
                        }
                        if let url = URL(string: nodeData.urlString) {
                            let node = Node(
                                url: url,
                                isTrusted: nodeData.isTrusted,
                                login: nodeData.login.isEmpty ? nil : nodeData.login,
                                password: nodeData.password.isEmpty ? nil : nodeData.password
                            )
                            SwipeToDeleteRow(
                                isOpen: openSwipeHost == nodeData.urlString,
                                onOpenChange: { open in openSwipeHost = open ? nodeData.urlString : nil },
                                onDelete: { deleteCustomNodeByURL(nodeData.urlString) }
                            ) {
                                nodeResultRow(node: node)
                            }
                        }
                    }
                }

                Divider()

                Button(action: {
                    resetAddNodeForm()
                    showingAddNode = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Add custom node")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Spacer()
                    }
                    .foregroundStyle(Color.dsAccentStrong)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(Color.dsJadeSoft)
                }
            }
            .background(Color.dsSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.dsBorder, lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
    }
    #endif

    // MARK: - Node Result Row

    private func nodeResultRow(node: Node) -> some View {
        let probeStatus = probeResults[node.url]
        let isActive = node.url.absoluteString == activeNodeURL

        return HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(displayHost(node.url.absoluteString))
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Color.dsTextPrimary)
                        .lineLimit(1)

                    // Trusted badge — only shown after testing, only for trusted nodes
                    if let status = probeStatus, status.checked, node.isTrusted {
                        Text("Trusted")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.dsAccentStrong)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.dsJadeSoft)
                            .clipShape(Capsule())
                    }
                }

                // Secondary line
                Group {
                    if let status = probeStatus {
                        if !status.checked {
                            Text("Pending…")
                                .foregroundStyle(Color.dsTextTertiary)
                        } else if status.failed {
                            Text("Failed to connect")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.dsDanger)
                        } else {
                            HStack(spacing: 6) {
                                if let ms = status.latencyMs {
                                    Text("\(ms) ms")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(pingColor(ms))
                                }
                                if let h = status.height, h > 0 {
                                    Text("Height: \(h)")
                                        .foregroundStyle(Color.dsTextTertiary)
                                }
                            }
                        }
                    } else {
                        Text(node.isTrusted ? "Trusted" : "Untrusted")
                            .foregroundStyle(Color.dsTextTertiary)
                    }
                }
                .font(.system(size: 12))
            }

            Spacer(minLength: 8)

            nodeTrailingIndicator(probeStatus: probeStatus, isActive: isActive)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private func nodeTrailingIndicator(probeStatus: NodeProbeStatus?, isActive: Bool) -> some View {
        if let status = probeStatus, !status.checked {
            // Pending: spinner
            ProgressView()
                .tint(Color.dsTextTertiary)
                .scaleEffect(0.85)
                .frame(width: 26, height: 26)
        } else if let status = probeStatus, status.failed {
            // Failed: rose filled circle + X
            ZStack {
                Circle().fill(Color.dsDanger)
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)
        } else if let status = probeStatus, status.checked {
            // Tested successfully: jade circle, full if active, 30% if not
            ZStack {
                Circle().fill(Color.dsAccent)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)
            .opacity(isActive ? 1.0 : 0.3)
        } else if isActive {
            // Not tested yet, but is the active node
            ZStack {
                Circle().fill(Color.dsAccent)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)
        } else {
            Color.clear.frame(width: 26, height: 26)
        }
    }

    // MARK: - Add Node Sheet

    private var addNodeSheet: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 999)
                .fill(Color.dsBorder)
                .frame(width: 36, height: 4)
                .padding(.top, 14)
                .padding(.bottom, 18)

            HStack {
                Button(action: { showingAddNode = false }) {
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
                Text("Add node")
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

                    TextField("http://node.example.com:18081", text: $newNodeURL)
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

                    HStack {
                        Text("Trusted node")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.dsTextPrimary)
                        Spacer()
                        Toggle("", isOn: $newNodeIsTrusted)
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
                        TextField("Login", text: $newNodeLogin)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 15))
                            .foregroundStyle(Color.dsTextPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: 46)
                        Divider()
                        SecureField("Password", text: $newNodePassword)
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

                    if let error = addNodeError {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.dsDanger)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }

                    Button(action: addCustomNode) {
                        Text("Add node")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.dsTextOnAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                newNodeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.dsAccent.opacity(0.4)
                                    : Color.dsAccent
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(newNodeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(Color.dsBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(Color.dsTextTertiary)
    }

    private func testAllNodes() {
        guard let nodePool = walletManager.activeWallet?.nodePool else { return }

        isTesting = true

        let defaultURLs = Set(WalletManager.defaultNodes.map(\.url))

        var fresh: [URL: NodeProbeStatus] = [:]
        for node in nodePool.nodes {
            fresh[node.url] = NodeProbeStatus(
                id: node.url,
                host: displayHost(node.url.absoluteString),
                isTrusted: node.isTrusted,
                isDefault: defaultURLs.contains(node.url)
            )
        }
        probeResults = fresh

        nodePool.onNodeProbeResult = { node, metrics in
            DispatchQueue.main.async { [self] in
                var status = probeResults[node.url] ?? NodeProbeStatus(
                    id: node.url,
                    host: displayHost(node.url.absoluteString),
                    isTrusted: node.isTrusted,
                    isDefault: defaultURLs.contains(node.url)
                )

                status.checked = true
                if metrics.lastResponseTime == nil {
                    status.failed = true
                } else {
                    status.failed = false
                    status.latencyMs = Int((metrics.lastResponseTime ?? 0) * 1000)
                    status.height = metrics.lastKnownHeight
                }
                probeResults[node.url] = status

                let allChecked = probeResults.values.allSatisfy(\.checked)
                if allChecked {
                    isTesting = false
                }
            }
        }

        nodePool.probeAllNodesSequentially()
    }

    private func loadExistingMetrics() {
        guard let nodePool = walletManager.activeWallet?.nodePool else { return }

        let defaultURLs = Set(WalletManager.defaultNodes.map(\.url))
        let allMetrics = nodePool.allNodeMetrics()

        for (node, metrics) in allMetrics {
            guard metrics.lastCheckedAt != nil else { continue }
            var status = NodeProbeStatus(
                id: node.url,
                host: displayHost(node.url.absoluteString),
                isTrusted: node.isTrusted,
                isDefault: defaultURLs.contains(node.url)
            )
            status.checked = true
            if metrics.lastResponseTime == nil {
                status.failed = true
            } else {
                status.latencyMs = Int((metrics.lastResponseTime ?? 0) * 1000)
                status.height = metrics.lastKnownHeight
            }
            probeResults[node.url] = status
        }
    }

    private func addCustomNode() {
        let trimmed = newNodeURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard URL(string: trimmed) != nil else {
            addNodeError = "Invalid URL format"
            return
        }

        let success = RealmManager.shared.addCustomNode(
            urlString: trimmed,
            isTrusted: newNodeIsTrusted,
            login: newNodeLogin,
            password: newNodePassword
        )

        if success {
            showingAddNode = false
            loadCustomNodes()
        } else {
            addNodeError = "Node already exists or could not be saved"
        }
    }

    private func deleteCustomNodeByURL(_ urlString: String) {
        _ = RealmManager.shared.removeCustomNode(urlString: urlString)
        if openSwipeHost == urlString { openSwipeHost = nil }
        loadCustomNodes()
    }

    private func deleteCustomNode(at offsets: IndexSet) {
        for index in offsets {
            _ = RealmManager.shared.removeCustomNode(urlString: customNodes[index].urlString)
        }
        loadCustomNodes()
    }

    private func loadCustomNodes() {
        // Convert Realm live objects to value-type snapshots immediately so no closure
        // ever holds a reference to a Realm object that can be invalidated after deletion.
        customNodes = RealmManager.shared.getCustomNodes().map { NodeSnapshot($0) }
    }

    private func resetAddNodeForm() {
        newNodeURL = ""
        newNodeIsTrusted = false
        newNodeLogin = ""
        newNodePassword = ""
        addNodeError = nil
    }

    private func displayHost(_ urlString: String) -> String {
        return urlString
    }

    private func pingColor(_ ms: Int) -> Color {
        if ms < 800 { return Color(red: 90/255, green: 143/255, blue: 62/255) }   // #5A8F3E
        if ms < 2500 { return Color(red: 184/255, green: 134/255, blue: 11/255) } // #B8860B
        return .dsDanger
    }
}

// MARK: - SwipeToDeleteRow

private struct SwipeToDeleteRow<Content: View>: View {
    let isOpen: Bool
    let onOpenChange: (Bool) -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offsetX: CGFloat = 0
    private let deleteWidth: CGFloat = 76

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete action revealed behind the row
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    onOpenChange(false)
                }
                onDelete()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: deleteWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.dsDanger)
            }

            // Row content layer
            content()
                .background(Color.dsSurfaceRaised)
                .offset(x: offsetX)
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            let base = isOpen ? -deleteWidth : 0
                            offsetX = max(-deleteWidth, min(0, base + value.translation.width))
                        }
                        .onEnded { value in
                            let base = isOpen ? -deleteWidth : 0
                            let finalOffset = max(-deleteWidth, min(0, base + value.translation.width))
                            let shouldOpen = finalOffset < -deleteWidth / 2
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                onOpenChange(shouldOpen)
                                offsetX = shouldOpen ? -deleteWidth : 0
                            }
                        }
                )
                .onTapGesture {
                    if isOpen {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            onOpenChange(false)
                            offsetX = 0
                        }
                    }
                }
                .onChange(of: isOpen) { newValue in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offsetX = newValue ? -deleteWidth : 0
                    }
                }
        }
        .clipped()
    }
}
