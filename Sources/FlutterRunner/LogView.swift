import SwiftUI

struct LogView: View {
    let viewModel: RunnerViewModel
    @Environment(AppSettings.self) private var settings
    @State private var filter = ""
    @State private var followTail = true
    @State private var errorsOnly = false

    private var visibleLogs: [LogLine] {
        viewModel.logs.filter { line in
            (!errorsOnly || line.level == .error)
                && (filter.isEmpty || line.text.localizedCaseInsensitiveContains(filter))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.5)
            console
        }
        .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.primary.opacity(0.09), lineWidth: 0.5)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                TextField("Loglarda ara", text: $filter)
                    .textFieldStyle(.plain)
                if !filter.isEmpty {
                    Button { filter = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .frame(width: 230, height: 24)
            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))

            Chip(title: "Hatalar", symbol: "exclamationmark.triangle", isOn: $errorsOnly, color: .stop)
            Chip(title: "Sona kaydır", symbol: "arrow.down.to.line", isOn: $followTail, color: settings.theme.accent)

            Spacer()

            Text("\(visibleLogs.count) satır")
                .font(.system(size: 10.5))
                .monospacedDigit()
                .foregroundStyle(.tertiary)

            IconButton(symbol: "doc.on.doc", help: "Kopyala") {
                let text = visibleLogs.map(\.text).joined(separator: "\n")
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            IconButton(symbol: "trash", help: "Temizle", action: viewModel.clearLogs)
        }
        .font(.system(size: 11.5))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private var console: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(visibleLogs) { line in
                        Text(line.text)
                            .font(.system(size: settings.logFontSize, design: .monospaced))
                            .foregroundStyle(line.level.color(theme: settings.theme))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 10)
                            // The marker sits behind the text so only the text decides the row height.
                            .background(alignment: .leading) {
                                if let marker = marker(for: line.level) {
                                    Rectangle().fill(marker).frame(width: 2)
                                }
                            }
                            .id(line.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .overlay {
                if viewModel.logs.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "terminal")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(settings.theme.gradient)
                        Text("Henüz log yok")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Çalıştır'a bas, flutter çıktısı burada akar.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: viewModel.logs.last?.id) { _, lastId in
                guard followTail, filter.isEmpty, !errorsOnly, let lastId else { return }
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

private extension LogView {
    func marker(for level: LogLine.Level) -> Color? {
        switch level {
        case .error: .stop
        case .system: settings.theme.accent
        case .info, .progress: nil
        }
    }
}

private struct Chip: View {
    let title: String
    let symbol: String
    @Binding var isOn: Bool
    let color: Color

    var body: some View {
        Button { isOn.toggle() } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .frame(height: 22)
                .foregroundStyle(isOn ? color : .secondary)
                .background(isOn ? color.opacity(0.15) : .primary.opacity(0.05), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
