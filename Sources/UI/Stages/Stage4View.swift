import SwiftUI

// Stage 4 — Chat (intentional path)
// Triggers: ⌘⇧Space | double-click notch | double-tap S3
struct Stage4View: View {
    @EnvironmentObject var state: NotchState

    private let notchH: CGFloat = NotchDimensions.shared.notchH
    private let pillW: CGFloat = 520

    @State private var inputText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var isPinned: Bool = false
    @State private var isResponding: Bool = false
    @State private var showContextPeek: Bool = false
    @State private var peekEvents: [ContextPeekEvent] = []
    @State private var graceCancelTimer: Timer?
    @FocusState private var inputFocused: Bool

    // Height: 80pt empty → grows → MAX=360pt
    private var pillH: CGFloat {
        let base: CGFloat = 80
        let conversationH = min(CGFloat(messages.count) * 44, 260)
        let peekH: CGFloat = showContextPeek ? 70 : 0
        return min(360, max(base, base + conversationH + peekH))
    }

    var body: some View {
        ZStack(alignment: .top) {
            AsymmetricRoundedRect(topRadius: StageRadii.s4.top,
                                  bottomRadius: StageRadii.s4.bottom)
                .fill(Color(hex: "#0d0d0d"))
                .overlay(
                    AsymmetricRoundedRect(topRadius: StageRadii.s4.top,
                                         bottomRadius: StageRadii.s4.bottom)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                )

            VStack(spacing: 0) {
                // Header
                headerBar
                    .padding(.horizontal, 12)
                    .padding(.top, notchH + 8)
                    .padding(.bottom, 8)

                // Context peek (appears on keyword detection)
                if showContextPeek && !peekEvents.isEmpty {
                    ContextPeekView(events: peekEvents)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(Springs.hoverExpand, value: showContextPeek)
                }

                // Conversation scroll area
                if !messages.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 8) {
                                ForEach(messages) { msg in
                                    chatBubble(msg)
                                        .id(msg.id)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                        .onChange(of: messages.count) { _ in
                            if let last = messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }

                Spacer(minLength: 0)

                // Input bar (always at bottom)
                inputBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .padding(.top, 6)
            }
        }
        .frame(width: pillW, height: pillH)
        .animation(Springs.chat, value: pillH)
        .onAppear {
            inputFocused = true
            startGraceTimer()
        }
        .onDisappear {
            graceCancelTimer?.invalidate()
        }
        .onHover { hovered in
            if !hovered && !isPinned {
                startGraceTimer()
            } else {
                graceCancelTimer?.invalidate()
            }
        }
    }

    // MARK: - Header
    private var headerBar: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(NT.purple)
                .frame(width: 5, height: 5)

            Text("OpenClaw")
                .font(.system(size: 10.5, weight: .regular))
                .foregroundColor(.white.opacity(0.20))

            if isPinned {
                HStack(spacing: 4) {
                    Circle().fill(NT.purple).frame(width: 4, height: 4)
                    Text("pinned · action pending")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundColor(NT.purple.opacity(0.60))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 5)
                    .fill(NT.purple.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 5)
                        .stroke(NT.purple.opacity(0.20), lineWidth: 0.5)))
            }

            Spacer()

            Text("⌘⇧Space")
                .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                .foregroundColor(NT.purple.opacity(0.50))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4)
                    .fill(NT.purple.opacity(0.08)))

            Button {
                closeAndClear()
            } label: {
                Text("✕")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.15))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Chat bubble
    @ViewBuilder
    private func chatBubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.isUser { Spacer(minLength: 40) }

            Text(msg.text)
                .font(.system(size: 11.5, weight: .regular))
                .foregroundColor(msg.isUser ? .white.opacity(0.75) : .white.opacity(0.80))
                .lineSpacing(1.5 * 11.5 - 11.5)
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(msg.isUser
                              ? NT.blue.opacity(0.12)
                              : Color.white.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(msg.isUser
                                        ? NT.blue.opacity(0.18)
                                        : Color.white.opacity(0.06),
                                        lineWidth: 0.5)
                        )
                )

            if !msg.isUser { Spacer(minLength: 40) }
        }
    }

    // MARK: - Input bar
    private var inputBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(NT.purple.opacity(0.40))
                .frame(width: 5, height: 5)

            TextField("ask anything · add task · reschedule...",
                      text: $inputText)
                .font(.system(size: 11.5, weight: .regular))
                .foregroundColor(NT.textPrimary)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .onChange(of: inputText) { text in
                    checkContextPeek(for: text)
                }
                .onSubmit { sendMessage() }

            Text("↩")
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.white.opacity(0.20))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .stroke(NT.purple.opacity(0.20), lineWidth: 0.5))
        )
    }

    // MARK: - Send
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(ChatMessage(text: text, isUser: true))
        inputText = ""
        showContextPeek = false
        isResponding = true
        isPinned = true

        // Route to brain for response (Phase G wires this to Python daemon)
        BDIAgent.shared.handleChatInput(text, state: state) { response in
            DispatchQueue.main.async {
                messages.append(ChatMessage(text: response, isUser: false))
                isResponding = false
                isPinned = false
            }
        }
    }

    // MARK: - Context peek
    private func checkContextPeek(for text: String) {
        if ContextPeekView.shouldShow(for: text) {
            peekEvents = WorkingMemory.shared.tomorrowPreview()
            withAnimation(Springs.hoverExpand) { showContextPeek = true }
        } else {
            withAnimation(.easeOut(duration: 0.15)) { showContextPeek = false }
        }
    }

    // MARK: - Grace timer (60s idle → clear → s0)
    private func startGraceTimer() {
        graceCancelTimer?.invalidate()
        graceCancelTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: false) { _ in
            closeAndClear()
        }
    }

    private func closeAndClear() {
        messages.removeAll()
        inputText = ""
        isPinned = false
        state.collapse()
    }
}

struct ChatMessage: Identifiable {
    var id: UUID = UUID()
    var text: String
    var isUser: Bool
}
