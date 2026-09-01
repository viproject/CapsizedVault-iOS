import SwiftUI

struct ChangePINView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var step = Step.verify
    @State private var oldPIN = ""
    @State private var newPIN = ""
    @State private var errorMessage: String?

    private enum Step {
        case verify, create, confirm
    }

    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                shellHeader
                stepIndicator
                pinContent
            }
        }
    }

    // MARK: - Shell

    private var shellHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.dsJadeSoft)
                        .frame(width: 36, height: 36)
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dsAccentStrong)
                }
            }
            Spacer()
            Text("Change PIN")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Color.dsTextPrimary)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
        .padding(.top, 36)
        .padding(.bottom, 8)
    }

    private var stepIndicator: some View {
        Text(stepLabel)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(Color.dsTextTertiary)
    }

    private var stepLabel: String {
        switch step {
        case .verify: return "Step 1 of 3"
        case .create: return "Step 2 of 3"
        case .confirm: return "Step 3 of 3"
        }
    }

    // MARK: - PIN content

    @ViewBuilder
    private var pinContent: some View {
        switch step {
        case .verify:
            PINEntryView(title: "Current PIN", subtitle: "Enter your current PIN", errorMessage: $errorMessage) { pin in
                if KeychainHelper.verifyPIN(pin) {
                    oldPIN = pin
                    errorMessage = nil
                    step = .create
                } else {
                    errorMessage = "Incorrect PIN. Try again."
                }
            }
        case .create:
            PINEntryView(title: "New PIN", subtitle: "Enter a new 6-digit PIN", errorMessage: $errorMessage) { pin in
                newPIN = pin
                errorMessage = nil
                step = .confirm
            }
        case .confirm:
            PINEntryView(title: "Confirm PIN", subtitle: "Re-enter your new PIN", errorMessage: $errorMessage) { pin in
                if pin == newPIN {
                    if AuthManager.shared.changePIN(from: oldPIN, to: pin) {
                        dismiss()
                    }
                } else {
                    errorMessage = "PINs don't match. Try again."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        newPIN = ""
                        errorMessage = nil
                        step = .create
                    }
                }
            }
        }
    }
}

#Preview {
    ChangePINView()
}
