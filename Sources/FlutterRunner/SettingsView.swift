import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let updater: Updater

    var body: some View {
        TabView {
            Tab("Görünüm", systemImage: "paintpalette") {
                AppearanceSettings(settings: settings)
            }
            Tab("Davranış", systemImage: "slider.horizontal.3") {
                BehaviorSettings(settings: settings)
            }
            Tab("Hakkında", systemImage: "info.circle") {
                AboutSettings(settings: settings, updater: updater)
            }
        }
        .frame(width: 500)
        .tint(settings.theme.accent)
    }
}

private struct AppearanceSettings: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Renk teması") {
                HStack(spacing: 10) {
                    ForEach(AppTheme.allCases) { theme in
                        ThemeSwatch(theme: theme, isSelected: settings.theme == theme) {
                            withAnimation(.spring(duration: 0.3)) { settings.theme = theme }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }

            Section("Mod") {
                Picker("Görünüm", selection: $settings.appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Önizleme") {
                ThemePreview(theme: settings.theme)
            }
        }
        .formStyle(.grouped)
        .frame(height: 430)
    }
}

private struct ThemeSwatch: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    Circle().fill(theme.gradient)
                    Circle()
                        .fill(theme.reload)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .offset(x: 15, y: 15)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 48, height: 48)
                .padding(3)
                .overlay {
                    Circle().strokeBorder(isSelected ? theme.accent : .clear, lineWidth: 2.5)
                }
                Text(theme.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A miniature of the menu bar panel's controls in the chosen theme.
private struct ThemePreview: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                AppGlyph(theme: theme, size: 20)
                Text("Flutter Runner").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Çalışıyor")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.live)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.live.opacity(0.13), in: Capsule())
            }
            HStack(spacing: 8) {
                Button {} label: { Label("Çalıştır", systemImage: "play.fill") }
                    .buttonStyle(ActionButtonStyle(kind: .primary(theme.accent)))
                Button {} label: { Label("Hot Reload", systemImage: "bolt.fill") }
                    .buttonStyle(ActionButtonStyle(kind: .plain(theme.reload)))
                Button {} label: { Label("Restart", systemImage: "arrow.counterclockwise") }
                    .buttonStyle(ActionButtonStyle(kind: .plain(theme.accent)))
            }
            .allowsHitTesting(false)
        }
        .padding(.vertical, 4)
    }
}

private struct BehaviorSettings: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Başlangıç") {
                Toggle("Giriş yapınca otomatik aç", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                if let error = settings.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Menü çubuğu paneli") {
                Picker("Son log satırları", selection: $settings.panelLogLines) {
                    Text("Gizle").tag(0)
                    Text("3 satır").tag(3)
                    Text("4 satır").tag(4)
                    Text("6 satır").tag(6)
                    Text("8 satır").tag(8)
                }
                Toggle("Kısayol ipuçlarını göster", isOn: $settings.showShortcutHints)
            }

            Section("Log konsolu") {
                LabeledContent("Yazı boyutu") {
                    HStack {
                        Slider(value: $settings.logFontSize, in: 10...15, step: 0.5)
                            .frame(width: 160)
                        Text(String(format: "%.1f pt", settings.logFontSize))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
                Text("flutter: Hot reload tamamlandı")
                    .font(.system(size: settings.logFontSize, design: .monospaced))
                    .foregroundStyle(settings.theme.accent)
            }

            Section("Kısayollar (her yerden)") {
                ShortcutRow(title: "Çalıştır", keys: "⌃⌥↩")
                ShortcutRow(title: "Hot Reload", keys: "⌃⌥R")
                ShortcutRow(title: "Hot Restart", keys: "⌃⌥⇧R")
                ShortcutRow(title: "Durdur", keys: "⌃⌥.")
            }
        }
        .formStyle(.grouped)
        .frame(height: 430)
    }
}

private struct ShortcutRow: View {
    let title: String
    let keys: String

    var body: some View {
        LabeledContent(title) {
            Text(keys)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
        }
    }
}

private struct AboutSettings: View {
    let settings: AppSettings
    let updater: Updater

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            AppGlyph(theme: settings.theme, size: 72)
            VStack(spacing: 4) {
                Text("Flutter Runner").font(.title2.weight(.bold))
                Text("Sürüm \(updater.currentVersion)").foregroundStyle(.secondary)
            }
            Text("Flutter uygulamanı IDE açmadan çalıştır,\nhot reload yap, DevTools'u aç.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Güncellemeleri denetle") {
                Task { await updater.check(userInitiated: true) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!updater.canUpdate)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 430)
    }
}
