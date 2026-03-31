import SwiftUI
import AppKit

// Shows "Open [App]", "Switch to [App]", or is hidden if app is frontmost.
struct AppLaunchButton: View {
    let hint: AppLaunchHint
    @State private var isHovered = false

    var body: some View {
        Button(action: launch) {
            Text(buttonLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(NT.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(NT.blue.opacity(isHovered ? 0.15 : 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(NT.blue.opacity(0.20), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .opacity(hint.isFrontmost ? 0 : 1)   // hide when already frontmost
    }

    private var buttonLabel: String {
        if hint.isFrontmost { return "" }
        return hint.isRunning ? "Switch to \(hint.displayName)" : "Open \(hint.displayName)"
    }

    private func launch() {
        guard !hint.isFrontmost else { return }
        let ws = NSWorkspace.shared
        if hint.isRunning {
            // Switch to running app
            if let app = NSRunningApplication.runningApplications(
                withBundleIdentifier: hint.bundleID
            ).first {
                app.activate(options: .activateAllWindows)
            }
        } else {
            // Open app
            ws.launchApplication(withBundleIdentifier: hint.bundleID,
                                  options: [],
                                  additionalEventParamDescriptor: nil,
                                  launchIdentifier: nil)
        }
    }
}
