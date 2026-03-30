import SwiftUI

/// Stage 4 — Conversational AI chat (Phase I).
struct Stage4ChatView: View {

    @EnvironmentObject var state: NotchState
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    private let cardW: CGFloat = 500
    private let cardH: CGFloat = 360
    private let radius: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color(red: 0.05, green: 0.05, blue: 0.05))
            .frame(width: cardW, height: cardH)
            .overlay(
                VStack(spacing: 0) {
                    chatHeader
                    Divider().background(Color.white.opacity(0.1))
                    chatMessages
                    Divider().background(Color.white.opacity(0.1))
                    inputBar
                }
            )
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack {
            Image(systemName: "sparkles")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#7F77DD"))
            Text("Notchly")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
            Button(action: { state.collapseToIdle() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Messages

    private var chatMessages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(state.chatMessages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                    if state.chatIsAIResponding {
                        typingIndicator
                    }
                }
                .padding(14)
            }
            .onChange(of: state.chatMessages.count) { _ in
                if let last = state.chatMessages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func messageBubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer() }

            Text(msg.text)
                .font(.system(size: 13))
                .foregroundColor(msg.role == .user ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(msg.role == .user
                              ? Color.white
                              : Color.white.opacity(0.1))
                )
                .frame(maxWidth: 340, alignment: msg.role == .user ? .trailing : .leading)

            if msg.role == .assistant { Spacer() }
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 5, height: 5)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15),
                        value: state.chatIsAIResponding
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.1)))
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask anything…", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .focused($isFocused)
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(inputText.isEmpty ? .white.opacity(0.2) : Color(hex: "#7F77DD"))
            }
            .buttonStyle(.plain)
            .disabled(inputText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""

        let msg = ChatMessage(role: .user, text: text)
        state.chatMessages.append(msg)

        // Stub: echo response (Phase I will add real AI)
        state.chatIsAIResponding = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let reply = ChatMessage(role: .assistant, text: "Got it: \"\(text)\". (AI integration in Phase I)")
            state.chatMessages.append(reply)
            state.chatIsAIResponding = false
        }
    }
}
