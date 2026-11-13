import SwiftUI

/// The panel that drops down from the menu bar icon.
struct MenuBarPanel: View {
    @Bindable var viewModel: RunnerViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            DevicePicker(viewModel: viewModel)
                .labelsHidden()
            Picker("", selection: $viewModel.mode) {
                ForEach(BuildMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(viewModel.status.isActive)

            controls
            StatusLabel(viewModel: viewModel)
            recentLogs
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 340)
    }

    private var header: some View {
        HStack {
            Button(action: viewModel.chooseProject) {
                Label(viewModel.projectName, systemImage: "folder")
                    .lineLimit(1)
            }
            .help(viewModel.projectURL?.path ?? "Flutter proje klasörü seç")
            .disabled(viewModel.status.isActive)
            Spacer()
            Button {
                Task { await viewModel.refreshDevices() }
            } label: {
                if viewModel.isLoadingDevices {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .help("Cihazları yenile")
            .disabled(viewModel.isLoadingDevices)
        }
    }

    private var controls: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                RunStopButton(viewModel: viewModel)
                Button(action: viewModel.hotReload) {
                    Label("Hot Reload", systemImage: "bolt.fill").frame(maxWidth: .infinity)
                }
                .tint(.orange)
                .disabled(!viewModel.canReload)
            }
            GridRow {
                Button(action: viewModel.hotRestart) {
                    Label("Restart", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.canReload)
                Button(action: viewModel.openDevTools) {
                    Label("DevTools", systemImage: "ladybug").frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.canOpenDevTools)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    @ViewBuilder
    private var recentLogs: some View {
        let lines = viewModel.logs.suffix(5)
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(lines) { line in
                    Text(line.text)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(line.level == .error ? Color.red : Color.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack {
            Button("Logları aç") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Spacer()
            Text("⌃⌥R reload · ⌃⌥⇧R restart")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Çık") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
    }
}

struct RunStopButton: View {
    let viewModel: RunnerViewModel

    var body: some View {
        if viewModel.status.isActive {
            Button(action: viewModel.stop) {
                Label("Stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
            }
            .tint(.red)
            .disabled(!viewModel.canStop)
        } else {
            Button(action: viewModel.runOrBoot) {
                Label(viewModel.selectedDevice?.isReady == false ? "Aç ve Çalıştır" : "Run",
                      systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .tint(.green)
            .disabled(viewModel.projectURL == nil || viewModel.selectedDevice == nil || viewModel.isBooting)
        }
    }
}
