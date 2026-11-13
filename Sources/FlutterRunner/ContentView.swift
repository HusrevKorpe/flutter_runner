import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: RunnerViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                TargetBar(viewModel: viewModel)
                ControlBar(viewModel: viewModel)
            }
            .padding(12)

            if viewModel.showLogs {
                Divider()
                LogView(viewModel: viewModel)
            }
        }
        .frame(minWidth: 560, minHeight: viewModel.showLogs ? 320 : 0)
        .background(WindowAccessor(alwaysOnTop: viewModel.alwaysOnTop))
        .task { await viewModel.refreshDevices() }
    }
}

/// Project, device and build mode.
private struct TargetBar: View {
    @Bindable var viewModel: RunnerViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button(action: viewModel.chooseProject) {
                Label(viewModel.projectName, systemImage: "folder")
                    .lineLimit(1)
            }
            .help(viewModel.projectURL?.path ?? "Flutter proje klasörü seç")
            .disabled(viewModel.status.isActive)

            DevicePicker(viewModel: viewModel)

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

            Picker("", selection: $viewModel.mode) {
                ForEach(BuildMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .disabled(viewModel.status.isActive)
        }
    }
}

private struct DevicePicker: View {
    @Bindable var viewModel: RunnerViewModel

    private var ready: [Device] { viewModel.devices.filter(\.isReady) }
    private var simulators: [Device] { viewModel.devices.filter { $0.kind == .iosSimulator } }
    private var emulators: [Device] { viewModel.devices.filter { $0.kind == .androidEmulator } }

    var body: some View {
        Picker("", selection: $viewModel.selectedDeviceId) {
            if viewModel.devices.isEmpty {
                Text(viewModel.isLoadingDevices ? "Cihazlar aranıyor…" : "Cihaz yok").tag(String?.none)
            }
            section("Açık cihazlar", ready)
            section("iOS simülatörler (kapalı)", simulators)
            section("Android emülatörler", emulators)
        }
        .frame(minWidth: 200)
        .disabled(viewModel.status.isActive || viewModel.isBooting)
    }

    @ViewBuilder
    private func section(_ title: String, _ devices: [Device]) -> some View {
        if !devices.isEmpty {
            Section(title) {
                ForEach(devices) { device in
                    Text("\(device.name)  —  \(device.detail)").tag(Optional(device.id))
                }
            }
        }
    }
}

/// Run, hot reload, restart, stop, DevTools and window toggles.
private struct ControlBar: View {
    @Bindable var viewModel: RunnerViewModel

    var body: some View {
        HStack(spacing: 8) {
            if viewModel.status.isActive {
                Button(action: viewModel.stop) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .tint(.red)
                .keyboardShortcut(".", modifiers: .command)
                .disabled(!viewModel.canStop)
            } else {
                Button(action: viewModel.runOrBoot) {
                    Label(viewModel.selectedDevice?.isReady == false ? "Aç ve Çalıştır" : "Run",
                          systemImage: "play.fill")
                }
                .tint(.green)
                .keyboardShortcut("r", modifiers: .command)
                .disabled(viewModel.projectURL == nil || viewModel.selectedDevice == nil || viewModel.isBooting)
            }

            Button(action: viewModel.hotReload) {
                Label("Hot Reload", systemImage: "bolt.fill")
            }
            .tint(.orange)
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!viewModel.canReload)

            Button(action: viewModel.hotRestart) {
                Label("Restart", systemImage: "arrow.counterclockwise")
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(!viewModel.canReload)

            Button(action: viewModel.openDevTools) {
                Label("DevTools", systemImage: "ladybug")
            }
            .disabled(!viewModel.canOpenDevTools)

            Spacer(minLength: 8)
            StatusLabel(viewModel: viewModel)

            Toggle(isOn: $viewModel.alwaysOnTop) { Image(systemName: "pin") }
                .toggleStyle(.button)
                .help("Pencere hep üstte")
            Toggle(isOn: $viewModel.showLogs) { Image(systemName: "text.alignleft") }
                .toggleStyle(.button)
                .help("Logları göster")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

private struct StatusLabel: View {
    let viewModel: RunnerViewModel

    private var color: Color {
        switch viewModel.status {
        case .idle: .secondary
        case .running: .green
        case .launching, .reloading, .restarting: .orange
        case .stopping: .red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if viewModel.isBooting || [.launching, .reloading, .restarting, .stopping].contains(viewModel.status) {
                ProgressView().controlSize(.small)
            } else {
                Circle().fill(color).frame(width: 8, height: 8)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.isBooting ? "Cihaz açılıyor…" : viewModel.status.title)
                    .font(.callout.weight(.medium))
                if let result = viewModel.lastResult {
                    Text(result).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .fixedSize()
    }
}
