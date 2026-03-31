import SwiftUI
import EventKit

// First launch onboarding — 3-step flow
// Step 1: Calendar access
// Step 2: Accessibility (for keyboard shortcuts)
// Step 3: Done
struct PermissionFlowView: View {
    @State private var step: Int = 1
    @State private var calGranted: Bool = false
    @State private var axGranted: Bool = false
    @State private var axPollTimer: Timer?

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#0d0d0d"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(NT.purple.opacity(0.20), lineWidth: 0.5)
                )

            VStack(spacing: 16) {
                // Purple dot — matches S4 aesthetic
                HStack(spacing: 6) {
                    Circle().fill(NT.purple).frame(width: 5, height: 5)
                    Text("OpenClaw")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundColor(.white.opacity(0.25))
                    Spacer()
                }

                Spacer(minLength: 8)
                stepContent
                Spacer(minLength: 8)
            }
            .padding(20)
        }
        .frame(width: 520, height: 200)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 1: step1
        case 2: step2
        default: step3
        }
    }

    // MARK: - Step 1: Calendar
    private var step1: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hi — I need two permissions to work properly.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(NT.textPrimary)

            HStack {
                if calGranted {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(NT.green)
                        Text("Calendar access granted")
                            .font(.system(size: 11))
                            .foregroundColor(NT.textSecondary)
                    }
                } else {
                    ActionButton(label: "Grant Calendar Access", style: .primary) {
                        CalendarReader.shared.requestAccess { granted in
                            calGranted = granted
                            if granted {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    step = 2
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 240)
                }

                Spacer()

                if !calGranted {
                    Button("I'll work without it, but...") {
                        step = 2
                    }
                    .font(.system(size: 10))
                    .foregroundColor(NT.textTertiary)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Step 2: Accessibility
    private var step2: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("For keyboard shortcuts, I need Accessibility.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(NT.textPrimary)

            Text("Add Notchly from the list, then come back.")
                .font(.system(size: 11))
                .foregroundColor(NT.textSecondary)

            HStack {
                if axGranted {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(NT.green)
                        Text("Accessibility granted ✓")
                            .font(.system(size: 11))
                            .foregroundColor(NT.textSecondary)
                    }
                } else {
                    ActionButton(label: "Open Settings", style: .primary) {
                        openAccessibilitySettings()
                        startAxPolling()
                    }
                    .frame(maxWidth: 160)
                }
                Spacer()
            }
        }
        .onDisappear { axPollTimer?.invalidate() }
    }

    // MARK: - Step 3: Done
    private var step3: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("That's it. I'll start learning your patterns.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(NT.textPrimary)

            ActionButton(label: "Start", style: .primary) {
                UserDefaults.standard.set(true, forKey: "notchly_setup_complete")
                onComplete()
            }
            .frame(maxWidth: 120)
        }
    }

    // MARK: - Helpers
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func startAxPolling() {
        axPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            if AXIsProcessTrusted() {
                axGranted = true
                axPollTimer?.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    step = 3
                }
            }
        }
    }
}
