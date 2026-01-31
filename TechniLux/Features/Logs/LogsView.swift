import SwiftUI

/// Represents a query logger app found in installed apps
struct QueryLoggerApp: Identifiable {
    var id: String { classPath }
    let name: String
    let classPath: String
    let description: String
}

/// Auto-refresh interval options
enum RefreshInterval: Int, CaseIterable, Identifiable {
    case off = 0
    case twoSeconds = 2
    case fiveSeconds = 5
    case tenSeconds = 10
    case thirtySeconds = 30

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .off: return "Off"
        case .twoSeconds: return "2s"
        case .fiveSeconds: return "5s"
        case .tenSeconds: return "10s"
        case .thirtySeconds: return "30s"
        }
    }
}

@MainActor
@Observable
final class LogsViewModel {
    var entries: [LogEntry] = []
    var logFiles: [LogFile] = []
    var isLoading = false
    var error: String?

    var currentPage = 1
    var totalPages = 1
    var entriesPerPage = 50

    // Query logger apps
    var queryLoggerApps: [QueryLoggerApp] = []
    var selectedApp: QueryLoggerApp?
    var appsLoaded = false

    // Filters
    var filterClientIP = ""
    var filterDomain = ""
    var filterResponseType = ""

    // Auto-refresh for query logs
    var queryAutoRefresh: RefreshInterval = .off

    private let client = TechnitiumClient.shared
    private let cluster = ClusterService.shared

    /// Load installed apps and find query logger apps
    func loadApps() async {
        do {
            let response = try await client.listApps(node: cluster.nodeParam)
            var loggers: [QueryLoggerApp] = []

            for app in response.appsList {
                if let processors = app.dnsApps {
                    for processor in processors {
                        if processor.isQueryLogger == true {
                            loggers.append(QueryLoggerApp(
                                name: app.name,
                                classPath: processor.classPath,
                                description: processor.displayDescription
                            ))
                        }
                    }
                }
            }

            queryLoggerApps = loggers
            appsLoaded = true

            // Auto-select first app if available
            if selectedApp == nil, let first = loggers.first {
                selectedApp = first
                await loadLogs()
            }
        } catch {
            self.error = error.localizedDescription
            appsLoaded = true
        }
    }

    func loadLogs() async {
        guard let app = selectedApp else { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            var filters: [String: Any] = [:]
            if !filterClientIP.isEmpty { filters["clientIpAddress"] = filterClientIP }
            if !filterDomain.isEmpty { filters["qname"] = filterDomain }
            if !filterResponseType.isEmpty { filters["responseType"] = filterResponseType }

            let response = try await client.queryLogs(
                appName: app.name,
                classPath: app.classPath,
                pageNumber: currentPage,
                entriesPerPage: entriesPerPage,
                filters: filters,
                node: cluster.nodeParam
            )

            entries = response.entries
            totalPages = response.totalPages
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadLogFiles() async {
        do {
            let response = try await client.listLogFiles(node: cluster.nodeParam)
            logFiles = response.filesList
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteLogFile(_ file: LogFile) async {
        do {
            try await client.deleteLogFile(fileName: file.fileName, node: cluster.nodeParam)
            await loadLogFiles()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteAllLogs() async {
        do {
            try await client.deleteAllLogs(node: cluster.nodeParam)
            await loadLogFiles()
            entries = []
        } catch {
            self.error = error.localizedDescription
        }
    }

    func nextPage() async {
        if currentPage < totalPages {
            currentPage += 1
            await loadLogs()
        }
    }

    func previousPage() async {
        if currentPage > 1 {
            currentPage -= 1
            await loadLogs()
        }
    }

    func clearFilters() {
        filterClientIP = ""
        filterDomain = ""
        filterResponseType = ""
        currentPage = 1
    }
}

@MainActor
@Observable
final class LogFileViewModel {
    var content: String = ""
    var isLoading = false
    var error: String?
    var autoRefresh: RefreshInterval = .off
    var followMode = true

    private var refreshTask: Task<Void, Never>?
    private let client = TechnitiumClient.shared
    private let cluster = ClusterService.shared

    func loadContent(fileName: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            content = try await client.downloadLogFile(
                fileName: fileName,
                limit: 500,
                node: cluster.nodeParam
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startAutoRefresh(fileName: String) {
        stopAutoRefresh()
        guard autoRefresh != .off else { return }

        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(autoRefresh.rawValue))
                if Task.isCancelled { break }
                await loadContent(fileName: fileName)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

struct LogsView: View {
    @State private var viewModel = LogsViewModel()
    @State private var showFilters = false
    @State private var showFiles = false
    @State private var showDeleteAllConfirm = false
    @State private var refreshTask: Task<Void, Never>?
    @Bindable var cluster = ClusterService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Loading apps
                if !viewModel.appsLoaded {
                    ProgressView("Loading...")
                        .frame(maxHeight: .infinity)
                }
                // Error loading apps
                else if let error = viewModel.error, viewModel.queryLoggerApps.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.red)
                        Text("Failed to Load Apps")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            viewModel.appsLoaded = false
                            viewModel.error = nil
                            Task { await viewModel.loadApps() }
                        }
                        .buttonStyle(.glassPrimary)
                    }
                    .frame(maxHeight: .infinity)
                    .padding()
                }
                // No query logger apps installed
                else if viewModel.queryLoggerApps.isEmpty {
                    noQueryLoggerView
                }
                // Query logs view
                else {
                    // App picker if multiple apps
                    if viewModel.queryLoggerApps.count > 1 {
                        appPicker
                    }

                    // Controls bar
                    controlsBar

                    // Logs list
                    if viewModel.isLoading && viewModel.entries.isEmpty {
                        ProgressView("Loading logs...")
                            .frame(maxHeight: .infinity)
                    } else if viewModel.entries.isEmpty {
                        EmptyStateView(
                            icon: "doc.text",
                            title: "No Logs",
                            description: "Query logs will appear here when enabled"
                        )
                    } else {
                        logsList
                    }
                }
            }
            .navigationTitle("Logs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        ClusterNodePicker()

                        Menu {
                            Button {
                                showFilters = true
                            } label: {
                                Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                            }

                            Button {
                                showFiles = true
                            } label: {
                                Label("Log Files", systemImage: "folder")
                            }

                            Divider()

                            Button(role: .destructive) {
                                showDeleteAllConfirm = true
                            } label: {
                                Label("Delete All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.loadLogs()
            }
            .task {
                await viewModel.loadApps()
            }
            .onChange(of: cluster.selectedNode) { _, _ in
                viewModel.selectedApp = nil
                viewModel.queryLoggerApps = []
                viewModel.entries = []
                viewModel.appsLoaded = false
                stopAutoRefresh()
                Task { await viewModel.loadApps() }
            }
            .onChange(of: viewModel.queryAutoRefresh) { _, newValue in
                if newValue == .off {
                    stopAutoRefresh()
                } else {
                    startAutoRefresh()
                }
            }
            .onDisappear {
                stopAutoRefresh()
            }
            .sheet(isPresented: $showFilters) {
                LogFiltersSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showFiles) {
                LogFilesSheet(viewModel: viewModel)
            }
            .confirmationDialog(
                "Delete All Logs",
                isPresented: $showDeleteAllConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    Task { await viewModel.deleteAllLogs() }
                }
            } message: {
                Text("This will permanently delete all log files. This action cannot be undone.")
            }
        }
    }

    private func startAutoRefresh() {
        stopAutoRefresh()
        guard viewModel.queryAutoRefresh != .off else { return }

        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(viewModel.queryAutoRefresh.rawValue))
                if Task.isCancelled { break }
                await viewModel.loadLogs()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private var noQueryLoggerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "info.circle")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("Query Logs App Required")
                .font(.headline)

            Text("To view detailed query logs, install a Query Logs app from the Apps page.\n\nAvailable options include:\n• Query Logs (Sqlite)\n• Query Logs (MySQL)\n• Query Logs (SQL Server)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            NavigationLink(destination: AppsView()) {
                Text("Go to Apps")
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassPrimary)
        }
        .frame(maxHeight: .infinity)
        .padding()
    }

    private var appPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Log Source")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Picker("Log Source", selection: Binding(
                get: { viewModel.selectedApp?.classPath ?? "" },
                set: { newValue in
                    if let app = viewModel.queryLoggerApps.first(where: { $0.classPath == newValue }) {
                        viewModel.selectedApp = app
                        viewModel.currentPage = 1
                        Task { await viewModel.loadLogs() }
                    }
                }
            )) {
                ForEach(viewModel.queryLoggerApps) { app in
                    Text(app.name).tag(app.classPath)
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var controlsBar: some View {
        HStack {
            // Auto-refresh picker
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("", selection: $viewModel.queryAutoRefresh) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                if viewModel.queryAutoRefresh != .off {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            // Pagination
            if !viewModel.entries.isEmpty {
                HStack(spacing: 12) {
                    Button {
                        Task { await viewModel.previousPage() }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(viewModel.currentPage <= 1)

                    Text("\(viewModel.currentPage)/\(viewModel.totalPages)")
                        .font(.caption)
                        .monospacedDigit()

                    Button {
                        Task { await viewModel.nextPage() }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(viewModel.currentPage >= viewModel.totalPages)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var logsList: some View {
        List(viewModel.entries) { entry in
            LogEntryRow(entry: entry)
        }
        .listStyle(.plain)
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.qname)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                StatusBadge(text: entry.qtype, color: .techniluxPrimary)
            }

            HStack {
                Text(entry.clientIpAddress)
                    .font(.caption)

                Spacer()

                StatusBadge(
                    text: entry.responseType,
                    color: responseColor(entry.responseType)
                )
            }

            HStack {
                Text(entry.timestamp)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(entry.protocol)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func responseColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "authoritative", "cached":
            return .green
        case "blocked":
            return .red
        case "recursive":
            return .blue
        default:
            return .secondary
        }
    }
}

struct LogFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: LogsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Client IP", text: $viewModel.filterClientIP)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Domain", text: $viewModel.filterDomain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Picker("Response Type", selection: $viewModel.filterResponseType) {
                        Text("All").tag("")
                        Text("Authoritative").tag("Authoritative")
                        Text("Recursive").tag("Recursive")
                        Text("Cached").tag("Cached")
                        Text("Blocked").tag("Blocked")
                    }
                }

                Section {
                    Button("Clear Filters") {
                        viewModel.clearFilters()
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        viewModel.currentPage = 1
                        Task { await viewModel.loadLogs() }
                        dismiss()
                    }
                }
            }
        }
    }
}

struct LogFilesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: LogsViewModel
    @State private var isLoading = true
    @State private var selectedFile: LogFile?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading log files...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.logFiles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No Log Files")
                            .font(.headline)
                        Text("Log files will appear here when logging is enabled")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List(viewModel.logFiles) { file in
                        Button {
                            selectedFile = file
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(file.fileName)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text(file.size)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteLogFile(file) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.loadLogFiles()
                isLoading = false
            }
            .sheet(item: $selectedFile) { file in
                LogFileViewerSheet(fileName: file.fileName)
            }
        }
    }
}

struct LogFileViewerSheet: View {
    let fileName: String

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = LogFileViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Controls bar
                HStack {
                    // Auto-refresh picker
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Picker("", selection: $viewModel.autoRefresh) {
                            ForEach(RefreshInterval.allCases) { interval in
                                Text(interval.label).tag(interval)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()

                        if viewModel.autoRefresh != .off {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                        }
                    }

                    Spacer()

                    // Follow mode toggle
                    Toggle(isOn: $viewModel.followMode) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.to.line")
                                .font(.caption)
                            Text("Follow")
                                .font(.caption)
                        }
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)

                // Log content
                if viewModel.isLoading && viewModel.content.isEmpty {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.red)
                        Text("Error")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(viewModel.content)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .id("logContent")
                        }
                        .onChange(of: viewModel.content) { _, _ in
                            if viewModel.followMode {
                                withAnimation {
                                    proxy.scrollTo("logContent", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.stopAutoRefresh()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.loadContent(fileName: fileName) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await viewModel.loadContent(fileName: fileName)
            }
            .onChange(of: viewModel.autoRefresh) { _, newValue in
                if newValue == .off {
                    viewModel.stopAutoRefresh()
                } else {
                    viewModel.startAutoRefresh(fileName: fileName)
                }
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
            }
        }
    }
}

#Preview("Logs View") {
    LogsView()
}
