import SwiftUI

struct LogView: View {
    let viewModel: RunnerViewModel
    @State private var filter = ""
    @State private var followTail = true

    private var visibleLogs: [LogLine] {
        guard !filter.isEmpty else { return viewModel.logs }
        return viewModel.logs.filter { $0.text.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("Loglarda ara", text: $filter)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)
                Toggle("Sona kaydır", isOn: $followTail)
                    .toggleStyle(.checkbox)
                Spacer()
                Button("Kopyala") {
                    let text = visibleLogs.map(\.text).joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                Button("Temizle", action: viewModel.clearLogs)
            }
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(visibleLogs) { line in
                            Text(line.text)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(color(for: line.level))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: viewModel.logs.last?.id) { _, lastId in
                    guard followTail, filter.isEmpty, let lastId else { return }
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
        }
    }

    private func color(for level: LogLine.Level) -> Color {
        switch level {
        case .info: .primary
        case .progress: .secondary
        case .error: .red
        case .system: .blue
        }
    }
}
