import SwiftUI

/// The conversation of one session right in the notch, with a reply field.
struct ChatView: View {
    let session: Session
    let messages: [ChatMessage]
    var status: String?
    var queued: [ReplyQueue.Item] = []
    var onRemoveQueued: (ReplyQueue.Item.ID) -> Void = { _ in }
    var onSend: (String) -> Void
    var onOpenApp: () -> Void
    var onClose: () -> Void

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if messages.isEmpty {
                            Text(session.lastSummary ?? "No messages yet.")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        ForEach(messages) { message in
                            ChatBubble(message: message, accent: session.agent.color).id(message.id)
                        }
                        Color.clear.frame(height: 1).id("end")
                    }
                    .padding(.horizontal, 4)
                }
                .scrollIndicators(.never)
                .frame(height: NotchViewModel.chatListHeight)
                .onAppear { proxy.scrollTo("end", anchor: .bottom) }
                .onChange(of: messages.last?.id) { _, _ in
                    withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("end", anchor: .bottom) }
                }
            }
            ForEach(queued) { item in
                QueuedRow(item: item, accent: session.agent.color) { onRemoveQueued(item.id) }
                    .transition(.blurFade.combined(with: .move(edge: .bottom)))
            }
            input
            if let status {
                Text(status)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 6)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: queued)
        .onExitCommand(perform: onClose)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focused = true } }
    }

    private var header: some View {
        HStack(spacing: 8) {
            AgentGlyph(agent: session.agent, mode: SparkMode(session.state), color: session.accent)
                .frame(width: 16, height: 16)
            Text(session.projectName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            AgentBadge(agent: session.agent)
            Text(session.statusTitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(session.accent)
                .shimmer(session.state.isActive)
            Spacer()
            Button(action: onOpenApp) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
            .help("Open the session's app")
            DismissButton(action: onClose)
        }
    }

    private var input: some View {
        HStack(spacing: 8) {
            TextField(session.isBusy ? "Next prompt for when \(session.agent.name) is done…" : "Reply to \(session.agent.name)…",
                      text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundStyle(.white)
                .lineLimit(1...3)
                .focused($focused)
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: session.isBusy ? "clock" : "arrow.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(draft.isEmpty ? .white.opacity(0.25) : session.agent.color))
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.leading, 12)
        .padding(.trailing, 5)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(focused ? 0.18 : 0.06), lineWidth: 1))
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        onSend(text)
    }
}

/// A prompt waiting for the agent to finish, with a way to take it back.
private struct QueuedRow: View {
    let item: ReplyQueue.Item
    let accent: Color
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.system(size: 10))
                .foregroundStyle(accent)
            Text(item.text)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Don't send this")
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(height: NotchViewModel.queuedRowHeight - 8)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(accent.opacity(0.1)))
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    let accent: Color

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }
            Text(Self.attributed(message.text))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(message.role == .user ? 0.92 : 0.82))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, message.role == .user ? 11 : 2)
                .padding(.vertical, message.role == .user ? 7 : 0)
                .background {
                    if message.role == .user {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.1))
                    }
                }
            if message.role == .assistant { Spacer(minLength: 20) }
        }
    }

    /// Inline markdown (bold, code, links) – headings and lists stay as plain text.
    static func attributed(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}
