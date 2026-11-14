import SwiftUI

struct ContentView: View {
    @Bindable var viewModel: RunnerViewModel
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(spacing: 10) {
            TargetBar(viewModel: viewModel, theme: settings.theme)
            ControlBar(viewModel: viewModel, theme: settings.theme)
            if viewModel.showLogs {
                LogView(viewModel: viewModel)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(12)
        .frame(minWidth: 640, minHeight: viewModel.showLogs ? 380 : 0, alignment: .top)
        .background(WindowAccessor(alwaysOnTop: viewModel.alwaysOnTop))
        .animation(.easeInOut(duration: 0.25), value: viewModel.showLogs)
        .animation(.easeInOut(duration: 0.2), value: viewModel.status)
    }
}

/// Project, device and build mode.
private struct TargetBar: View {
    @Bindable var viewModel: RunnerViewModel
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 12) {
            Button(action: viewModel.chooseProject) {
                HStack(spacing: 10) {
                    AppGlyph(theme: theme, size: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(viewModel.projectName)
                                .font(.system(size: 13.5, weight: .semibold))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        Text(viewModel.projectURL.map { abbreviate($0.path) } ?? "Flutter proje klasörü seç")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(viewModel.projectURL?.path ?? "Flutter proje klasörü seç")
            .disabled(viewModel.status.isActive)
            .frame(maxWidth: 260, alignment: .leading)

            Spacer(minLength: 8)

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
                .frame(maxWidth: 260)
                IconButton(symbol: "arrow.clockwise", help: "Cihazları yenile",
                           isLoading: viewModel.isLoadingDevices) {
                    Task { await viewModel.refreshDevices() }
                }
                .disabled(viewModel.isLoadingDevices)
            }

            ModePicker(viewModel: viewModel, theme: theme)
        }
    }
}

/// Run, hot reload, restart, stop, DevTools and window toggles.
private struct ControlBar: View {
    @Bindable var viewModel: RunnerViewModel
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 8) {
            RunStopButton(viewModel: viewModel, theme: theme, height: 28)
                .frame(width: 120)
                .keyboardShortcut(viewModel.status.isActive ? "." : "r", modifiers: .command)

            Button(action: viewModel.hotReload) {
                Label("Hot Reload", systemImage: "bolt.fill")
            }
            .buttonStyle(ActionButtonStyle(kind: .plain(theme.reload), height: 28))
            .frame(width: 104)
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!viewModel.canReload)

            Button(action: viewModel.hotRestart) {
                Label("Restart", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(ActionButtonStyle(kind: .plain(theme.accent), height: 28))
            .frame(width: 88)
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(!viewModel.canReload)

            Button(action: viewModel.openDevTools) {
                Label("DevTools", systemImage: "ladybug")
            }
            .buttonStyle(ActionButtonStyle(kind: .plain(.secondary), height: 28))
            .frame(width: 92)
            .disabled(!viewModel.canOpenDevTools)

            Spacer(minLength: 8)

            if let result = viewModel.lastResult {
                Text(result)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
                    .transition(.opacity)
            }
            StatusPill(viewModel: viewModel, theme: theme)

            HStack(spacing: 0) {
                ToggleIcon(symbol: "pin.fill", isOn: $viewModel.alwaysOnTop, theme: theme, help: "Pencere hep üstte")
                ToggleIcon(symbol: "text.alignleft", isOn: $viewModel.showLogs, theme: theme, help: "Logları göster")
                SettingsButton()
            }
            .padding(2)
            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}

private struct ToggleIcon: View {
    let symbol: String
    @Binding var isOn: Bool
    let theme: AppTheme
    let help: String

    var body: some View {
        Button { isOn.toggle() } label: {
            Image(systemName: symbol)
                .font(.system(size: 11.5, weight: .semibold))
                .frame(width: 24, height: 22)
                .foregroundStyle(isOn ? theme.accent : .secondary)
                .background(isOn ? theme.accent.opacity(0.14) : .clear,
                            in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
