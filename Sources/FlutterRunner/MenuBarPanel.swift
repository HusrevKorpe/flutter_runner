import SwiftUI

/// The panel that drops down from the menu bar icon.
struct MenuBarPanel: View {
    @Bindable var viewModel: RunnerViewModel
    let updater: Updater
    @Environment(AppSettings.self) private var settings
    @Environment(\.openWindow) private var openWindow

    private var theme: AppTheme { settings.theme }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            UpdateBanner(updater: updater, isBusy: viewModel.status.isActive, theme: theme)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            SectionDivider()

            VStack(spacing: 2) {
                ProjectRow(viewModel: viewModel)
                DeviceRow(viewModel: viewModel)
                HStack {
                    Text("Mod")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    ModePicker(viewModel: viewModel, theme: theme)
                }
                .padding(.horizontal, 8)
                .frame(height: 30)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)

            SectionDivider()

            VStack(spacing: 6) {
                RunStopButton(viewModel: viewModel, theme: theme, height: 28)
                HStack(spacing: 6) {
                    Button(action: viewModel.hotReload) {
                        Label("Reload", systemImage: "bolt.fill")
                    }
                    .buttonStyle(ActionButtonStyle(kind: .plain(theme.reload)))
                    .disabled(!viewModel.canReload)
                    .help("Hot Reload  ⌃⌥R")

                    Button(action: viewModel.hotRestart) {
                        Label("Restart", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(ActionButtonStyle(kind: .plain(theme.accent)))
                    .disabled(!viewModel.canReload)
                    .help("Hot Restart  ⌃⌥⇧R")

                    Button(action: viewModel.openDevTools) {
                        Label("DevTools", systemImage: "ladybug")
                    }
                    .buttonStyle(ActionButtonStyle(kind: .plain(.secondary)))
                    .disabled(!viewModel.canOpenDevTools)
                }
                if let result = viewModel.lastResult {
                    ResultLine(text: result)
                }
                recentLogs
            }
            .padding(12)

            SectionDivider()
            footer
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
        }
        .frame(width: 300)
        .animation(.easeInOut(duration: 0.15), value: viewModel.status)
        .animation(.easeInOut(duration: 0.15), value: viewModel.lastResult)
    }

    private var header: some View {
        HStack(spacing: 8) {
            AppGlyph(theme: theme, size: 20)
            Text("Flutter Runner").font(.system(size: 13, weight: .semibold))
            Spacer()
            StatusPill(viewModel: viewModel, theme: theme)
        }
    }

    @ViewBuilder
    private var recentLogs: some View {
        let lines = settings.panelLogLines > 0 ? Array(viewModel.logs.suffix(settings.panelLogLines)) : []
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(lines) { line in
                    Text(line.text)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(line.level == .error ? Color.stop : Color.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .onTapGesture(perform: openMainWindow)
            .help("Tüm loglar için tıkla")
            .padding(.top, 2)
        }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            FooterButton(title: "Loglar", action: openMainWindow)
            Spacer()
            if settings.showShortcutHints {
                Text("⌃⌥R  reload")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            SettingsButton()
            Menu {
                Text("Sürüm \(updater.currentVersion)")
                Button("Güncellemeleri denetle") {
                    Task { await updater.check(userInitiated: true) }
                }
                .disabled(!updater.canUpdate)
                Divider()
                Button("Flutter Runner'dan çık") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Daha fazla")
        }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct SectionDivider: View {
    var body: some View {
        Rectangle().fill(.primary.opacity(0.08)).frame(height: 0.5)
    }
}

/// A hoverable list row: icon, title, secondary detail and trailing accessory.
struct PanelRow<Trailing: View>: View {
    let symbol: String
    let title: String
    let detail: String?
    @ViewBuilder var trailing: Trailing
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            Spacer(minLength: 6)
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            trailing
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(.primary.opacity(isHovering ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

private struct ProjectRow: View {
    let viewModel: RunnerViewModel

    var body: some View {
        Button(action: viewModel.chooseProject) {
            PanelRow(symbol: "folder",
                     title: viewModel.projectName,
                     detail: viewModel.projectURL.map { abbreviate($0.deletingLastPathComponent().path) }) {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .help(viewModel.projectURL?.path ?? "Flutter proje klasörü seç")
        .disabled(viewModel.status.isActive)
    }
}

private struct DeviceRow: View {
    let viewModel: RunnerViewModel

    var body: some View {
        HStack(spacing: 0) {
            DeviceMenu(viewModel: viewModel) {
                PanelRow(symbol: viewModel.selectedDevice?.symbol ?? "iphone",
                         title: viewModel.selectedDevice?.name
                            ?? (viewModel.isLoadingDevices ? "Cihazlar aranıyor…" : "Cihaz seç"),
                         detail: viewModel.selectedDevice?.platform) {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            IconButton(symbol: "arrow.clockwise", help: "Cihazları yenile",
                       isLoading: viewModel.isLoadingDevices) {
                Task { await viewModel.refreshDevices() }
            }
            .disabled(viewModel.isLoadingDevices)
            .padding(.leading, 2)
        }
    }
}

/// Device chooser as a plain menu so the label can be fully custom.
struct DeviceMenu<Label: View>: View {
    let viewModel: RunnerViewModel
    @ViewBuilder var label: Label

    private var ready: [Device] { viewModel.devices.filter(\.isReady) }
    private var simulators: [Device] { viewModel.devices.filter { $0.kind == .iosSimulator } }
    private var emulators: [Device] { viewModel.devices.filter { $0.kind == .androidEmulator } }

    var body: some View {
        Menu {
            if viewModel.devices.isEmpty {
                Text(viewModel.isLoadingDevices ? "Cihazlar aranıyor…" : "Cihaz bulunamadı")
            }
            section("Açık cihazlar", ready)
            section("iOS simülatörler", simulators)
            section("Android emülatörler", emulators)
        } label: {
            label
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .disabled(viewModel.status.isActive || viewModel.isBooting)
    }

    @ViewBuilder
    private func section(_ title: String, _ devices: [Device]) -> some View {
        if !devices.isEmpty {
            Section(title) {
                ForEach(devices) { device in
                    Toggle(isOn: Binding(
                        get: { viewModel.selectedDeviceId == device.id },
                        set: { if $0 { viewModel.selectedDeviceId = device.id } }
                    )) {
                        Text("\(device.name)  ·  \(device.platform)")
                    }
                }
            }
        }
    }
}

/// Small three-way segmented control for the build mode.
struct ModePicker: View {
    @Bindable var viewModel: RunnerViewModel
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 1) {
            ForEach(BuildMode.allCases) { mode in
                let isSelected = viewModel.mode == mode
                Button { viewModel.mode = mode } label: {
                    Text(mode.title)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(.background)
                                    .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .disabled(viewModel.status.isActive)
        .opacity(viewModel.status.isActive ? 0.6 : 1)
        .animation(.easeOut(duration: 0.12), value: viewModel.mode)
    }
}

func abbreviate(_ path: String) -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
}

private struct ResultLine: View {
    let text: String

    private var isFailure: Bool { text.contains("başarısız") || text.contains("Hata") }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: isFailure ? "exclamationmark.triangle.fill" : "checkmark")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(isFailure ? Color.stop : Color.live)
            Text(text).foregroundStyle(.secondary)
            Spacer()
        }
        .font(.system(size: 11))
        .padding(.horizontal, 2)
        .transition(.opacity)
    }
}

struct RunStopButton: View {
    let viewModel: RunnerViewModel
    let theme: AppTheme
    var height: CGFloat = 26

    var body: some View {
        if viewModel.status.isActive {
            Button(action: viewModel.stop) {
                Label("Durdur", systemImage: "stop.fill")
            }
            .buttonStyle(ActionButtonStyle(kind: .plain(.stop), height: height))
            .disabled(!viewModel.canStop)
        } else {
            Button(action: viewModel.runOrBoot) {
                Label(viewModel.selectedDevice?.isReady == false ? "Aç ve Çalıştır" : "Çalıştır",
                      systemImage: "play.fill")
            }
            .buttonStyle(ActionButtonStyle(kind: .primary(theme.accent), height: height))
            .disabled(viewModel.projectURL == nil || viewModel.selectedDevice == nil || viewModel.isBooting)
        }
    }
}

struct IconButton: View {
    let symbol: String
    let help: String
    var isLoading = false
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView().controlSize(.small).scaleEffect(0.6)
                } else {
                    Image(systemName: symbol).font(.system(size: 11, weight: .medium))
                }
            }
            .frame(width: 24, height: 22)
            .background(.primary.opacity(isHovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .onHover { isHovering = $0 }
        .help(help)
    }
}

private struct FooterButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5))
                .padding(.horizontal, 6)
                .frame(height: 22)
                .background(.primary.opacity(isHovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .onHover { isHovering = $0 }
    }
}

/// Opens the Settings window and brings it to the front (we are an accessory app).
struct SettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        IconButton(symbol: "gearshape", help: "Ayarlar  ⌘,") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
    }
}

/// Only speaks up when there is something actionable about updates.
private struct UpdateBanner: View {
    let updater: Updater
    let isBusy: Bool
    let theme: AppTheme

    var body: some View {
        switch updater.state {
        case let .available(version, _):
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Sürüm \(version) hazır").font(.system(size: 12, weight: .medium))
                    if isBusy {
                        Text("Önce uygulamayı durdur").font(.system(size: 10.5)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Güncelle") { Task { await updater.install() } }
                    .buttonStyle(ActionButtonStyle(kind: .primary(theme.accent), height: 22))
                    .fixedSize()
                    .disabled(isBusy)
            }
            .padding(8)
            .background(theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        case .installing:
            banner {
                ProgressView().controlSize(.small).scaleEffect(0.7)
                Text("Güncelleniyor…")
            }
        case let .failed(message):
            banner {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.stop)
                Text(message).lineLimit(2)
            }
        case .upToDate:
            banner {
                Image(systemName: "checkmark").foregroundStyle(Color.live)
                Text("Güncel sürümü kullanıyorsun")
            }
        case .idle, .checking:
            EmptyView()
        }
    }

    private func banner(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 6) { content() }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
