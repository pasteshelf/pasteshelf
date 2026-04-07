// swiftlint:disable file_length
#if !APP_STORE
//
    //  PluginSettingsView.swift
    //  PasteShelf
//
    //  Settings view for managing installed plugins.
    //  Shows plugin list, enable/disable toggles, and per-plugin settings.
//

    import AppKit
    import Combine
    import os.log
    import SwiftUI
    import UniformTypeIdentifiers

    /// Main plugin settings view
    struct PluginSettingsView: View {
        // MARK: Internal

        @EnvironmentObject var settingsManager: SettingsManager

        var body: some View {
            VStack(spacing: 0) {
                // Master toggle
                HStack {
                    Toggle("Enable Plugin System", isOn: Binding(
                        get: { self.settingsManager.enterprise.pluginsEnabled },
                        set: { newValue in
                            self.settingsManager.update { $0.enterprise.pluginsEnabled = newValue }
                        }
                    ))
                    .toggleStyle(.switch)
                    Spacer()
                }
                .padding()

                Divider()

                if self.settingsManager.enterprise.pluginsEnabled {
                    HSplitView {
                        // Plugin list
                        self.pluginList
                            .frame(minWidth: 200, maxWidth: 300)

                        // Plugin detail
                        if let pluginId = selectedPluginId,
                           let plugin = viewModel.plugins.first(where: { $0.id == pluginId })
                        {
                            self.pluginDetail(plugin)
                        } else {
                            self.emptyState
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Plugin system is disabled")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Enable the toggle above to use plugins.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                }
            }
            .frame(minHeight: 400)
            .onAppear {
                self.viewModel.loadPlugins()
            }
            .onReceive(PluginManager.shared.$isInitialized) { _ in
                self.viewModel.loadPlugins()
            }
            .sheet(isPresented: self.$showingInstallSheet) {
                PluginInstallSheet { url in
                    self.viewModel.installPlugin(from: url)
                }
            }
        }

        // MARK: Private

        @StateObject private var viewModel = PluginSettingsViewModel()
        @State private var selectedPluginId: String?
        @State private var showingInstallSheet = false

        // MARK: - Plugin List

        private var pluginList: some View {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Plugins")
                        .font(.headline)
                    Spacer()
                    Button {
                        self.showingInstallSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    .help("Install Plugin")
                }
                .padding()

                Divider()

                // Plugin list
                List(selection: self.$selectedPluginId) {
                    ForEach(self.viewModel.plugins) { plugin in
                        PluginListRow(plugin: plugin, viewModel: self.viewModel)
                            .tag(plugin.id)
                    }
                }
                .listStyle(.sidebar)

                // Status bar
                if !self.viewModel.plugins.isEmpty {
                    Divider()
                    HStack {
                        Text("\(self.viewModel.activeCount) of \(self.viewModel.plugins.count) active")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }

        // MARK: - Empty State

        private var emptyState: some View {
            VStack(spacing: 16) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("No Plugin Selected")
                    .font(.title2)

                Text("Select a plugin from the list to view its details, or install a new plugin.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)

                Button("Install Plugin...") {
                    self.showingInstallSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        // MARK: - Plugin Detail

        private func pluginDetail(_ plugin: LoadedPlugin) -> some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    self.pluginDetailHeader(plugin)
                    self.pluginDetailErrorBanner(plugin)
                    self.permissionsSection(plugin)
                    if !plugin.bundle.manifest.categories.isEmpty {
                        self.categoriesSection(plugin)
                    }
                    if !self.viewModel.actions(for: plugin.id).isEmpty {
                        self.actionsSection(plugin)
                    }
                    if let settingsView = viewModel.settingsView(for: plugin.id) {
                        GroupBox("Settings") { settingsView }
                    }
                    self.infoSection(plugin)
                    Spacer()
                }
                .padding()
            }
        }

        private func pluginDetailHeader(_ plugin: LoadedPlugin) -> some View {
            HStack(spacing: 16) {
                Image(nsImage: plugin.bundle.icon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .cornerRadius(12)
                VStack(alignment: .leading, spacing: 4) {
                    Text(plugin.bundle.manifest.name)
                        .font(.title2).fontWeight(.semibold)
                    if let description = plugin.bundle.manifest.pluginDescription {
                        Text(description).font(.body).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Text("v\(plugin.bundle.manifest.shortVersion)")
                            .font(.caption).foregroundStyle(.secondary)
                        if let author = plugin.bundle.manifest.author {
                            Text("by \(author)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Toggle("", isOn: self.viewModel.binding(for: plugin.id))
                    .toggleStyle(.switch).labelsHidden()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }

        @ViewBuilder
        private func pluginDetailErrorBanner(_ plugin: LoadedPlugin) -> some View {
            if plugin.state == .failed, let error = plugin.loadError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error).font(.callout)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }

        // MARK: - Sections

        private func permissionsSection(_ plugin: LoadedPlugin) -> some View {
            GroupBox("Permissions") {
                VStack(alignment: .leading, spacing: 8) {
                    if plugin.bundle.manifest.requiredPermissions.isEmpty {
                        Text("No special permissions required")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(plugin.bundle.manifest.requiredPermissions), id: \.self) { permission in
                            HStack {
                                Image(systemName: permission.iconName)
                                    .foregroundColor(self.permissionColor(permission.riskLevel))
                                VStack(alignment: .leading) {
                                    Text(permission.displayName)
                                        .font(.callout)
                                    Text(permission.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if self.viewModel.hasPermission(permission, for: plugin.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }

        private func categoriesSection(_ plugin: LoadedPlugin) -> some View {
            GroupBox("Categories") {
                FlowLayout(spacing: 8) {
                    ForEach(plugin.bundle.manifest.categories, id: \.self) { category in
                        HStack(spacing: 4) {
                            Image(systemName: category.iconName)
                            Text(category.displayName)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 4)
            }
        }

        private func actionsSection(_ plugin: LoadedPlugin) -> some View {
            GroupBox("Actions") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(self.viewModel.actions(for: plugin.id), id: \.id) { action in
                        HStack {
                            if let iconName = action.iconName {
                                Image(systemName: iconName)
                            }
                            VStack(alignment: .leading) {
                                Text(action.name)
                                    .font(.callout)
                                if let description = action.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }

        private func infoSection(_ plugin: LoadedPlugin) -> some View {
            GroupBox("Information") {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Identifier", value: plugin.bundle.manifest.identifier)
                    InfoRow(label: "Version", value: plugin.bundle.manifest.shortVersion)

                    if let website = plugin.bundle.manifest.website {
                        HStack {
                            Text("Website")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Link(website.host ?? website.absoluteString, destination: website)
                        }
                        .font(.callout)
                    }

                    if let email = plugin.bundle.manifest.supportEmail {
                        InfoRow(label: "Support", value: email)
                    }

                    if let minVersion = plugin.bundle.manifest.minPasteShelfVersion {
                        InfoRow(label: "Requires", value: "PasteShelf \(minVersion)+")
                    }
                }
                .padding(.vertical, 4)
            }
        }

        // MARK: - Helpers

        private func permissionColor(_ level: PermissionRiskLevel) -> Color {
            switch level {
            case .low: .green
            case .medium: .orange
            case .high: .red
            }
        }
    }

    // MARK: - Plugin List Row

    private struct PluginListRow: View {
        // MARK: Internal

        let plugin: LoadedPlugin

        @ObservedObject var viewModel: PluginSettingsViewModel

        var body: some View {
            HStack(spacing: 12) {
                Image(nsImage: self.plugin.bundle.icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(self.plugin.bundle.manifest.name)
                        .font(.body)

                    Text(self.stateText)
                        .font(.caption)
                        .foregroundStyle(self.stateColor)
                }

                Spacer()

                Toggle("", isOn: self.viewModel.binding(for: self.plugin.id))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            }
            .padding(.vertical, 4)
        }

        // MARK: Private

        private var stateText: String {
            switch self.plugin.state {
            case .active: "Active"
            case .disabled: "Disabled"
            case .failed: "Failed"
            case .loading: "Loading..."
            default: "Inactive"
            }
        }

        private var stateColor: Color {
            switch self.plugin.state {
            case .active: .green
            case .failed: .red
            default: .secondary
            }
        }
    }

    // MARK: - Info Row

    private struct InfoRow: View {
        let label: String
        let value: String

        var body: some View {
            HStack {
                Text(self.label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(self.value)
            }
            .font(.callout)
        }
    }

    // MARK: - Flow Layout

    private struct FlowLayout: Layout {
        // MARK: Internal

        var spacing: CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout Void) -> CGSize {
            let result = self.arrangeSubviews(proposal: proposal, subviews: subviews)
            return CGSize(width: proposal.width ?? result.width, height: result.height)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout Void) {
            let result = self.arrangeSubviews(proposal: proposal, subviews: subviews)

            for (index, placement) in result.placements.enumerated() {
                subviews[index].place(
                    at: CGPoint(x: bounds.minX + placement.x, y: bounds.minY + placement.y),
                    proposal: ProposedViewSize(placement.size)
                )
            }
        }

        // MARK: Private

        private struct Placement {
            let x: CGFloat
            let y: CGFloat
            let size: CGSize
        }

        private struct ArrangementResult {
            let width: CGFloat
            let height: CGFloat
            let placements: [Placement]
        }

        private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> ArrangementResult {
            let maxWidth = proposal.width ?? .infinity
            var placements: [Placement] = []
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var rowHeight: CGFloat = 0
            var totalWidth: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth, currentX > 0 {
                    currentX = 0
                    currentY += rowHeight + self.spacing
                    rowHeight = 0
                }

                placements.append(Placement(x: currentX, y: currentY, size: size))
                rowHeight = max(rowHeight, size.height)
                currentX += size.width + self.spacing
                totalWidth = max(totalWidth, currentX)
            }

            return ArrangementResult(
                width: totalWidth,
                height: currentY + rowHeight,
                placements: placements
            )
        }
    }

    // MARK: - Plugin Install Sheet

    private struct PluginInstallSheet: View {
        // MARK: Internal

        let onInstall: (URL) -> Void

        var body: some View {
            VStack(spacing: 20) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 48))
                    .foregroundColor(self.isDragging ? Color.accentColor : Color.secondary)

                Text("Install Plugin")
                    .font(.title2)

                Text("Drag and drop a .pasteshelfplugin file here, or click to browse.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Button("Browse...") {
                        self.browseForPlugin()
                    }

                    Button("Cancel") {
                        self.dismiss()
                    }
                }
            }
            .padding(40)
            .frame(width: 400)
            .onDrop(of: [.fileURL], isTargeted: self.$isDragging) { providers in
                self.handleDrop(providers)
            }
        }

        // MARK: Private

        @Environment(\.dismiss)
        private var dismiss
        @State private var isDragging = false

        private func browseForPlugin() {
            let panel = NSOpenPanel()
            if let pluginType = UTType(filenameExtension: "pasteshelfplugin") {
                panel.allowedContentTypes = [pluginType]
            }
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false

            if panel.runModal() == .OK, let url = panel.url {
                self.onInstall(url)
                self.dismiss()
            }
        }

        private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
            guard let provider = providers.first else {
                return false
            }

            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.pathExtension == "pasteshelfplugin"
                else {
                    return
                }

                DispatchQueue.main.async {
                    self.onInstall(url)
                    self.dismiss()
                }
            }

            return true
        }
    }

    // MARK: - View Model

    @MainActor
    final class PluginSettingsViewModel: ObservableObject {
        @Published var plugins: [LoadedPlugin] = []

        var activeCount: Int {
            self.plugins.filter { $0.state == .active }.count
        }

        func loadPlugins() {
            self.plugins = PluginManager.shared.allPlugins
        }

        func binding(for pluginId: String) -> Binding<Bool> {
            Binding(
                get: { PluginManager.shared.isEnabled(id: pluginId) },
                set: { newValue in
                    Task {
                        if newValue {
                            try? await PluginManager.shared.enablePlugin(id: pluginId)
                        } else {
                            await PluginManager.shared.disablePlugin(id: pluginId)
                        }
                        self.loadPlugins()
                    }
                }
            )
        }

        func hasPermission(_ permission: PluginPermission, for pluginId: String) -> Bool {
            PluginManager.shared.hasPermission(permission, for: pluginId)
        }

        func actions(for pluginId: String) -> [PluginAction] {
            PluginActionRegistry.shared.actions(for: pluginId)
        }

        func settingsView(for pluginId: String) -> AnyView? {
            guard let plugin = PluginManager.shared.plugin(id: pluginId) as? PasteShelfPluginWithSettings else {
                return nil
            }
            return plugin.settingsView()
        }

        func installPlugin(from url: URL) {
            Task {
                do {
                    _ = try PluginLoader.shared.installPlugin(from: url)
                    await PluginManager.shared.refreshPlugins()
                    self.loadPlugins()
                } catch {
                    Logger.plugins.error("Failed to install plugin: \(error.localizedDescription)")
                }
            }
        }
    }

#endif
