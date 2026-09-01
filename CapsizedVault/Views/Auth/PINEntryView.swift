import SwiftUI

struct PINEntryView: View {

    let title: String
    var subtitle: String? = nil
    @Binding var errorMessage: String?
    let onComplete: (String) -> Void

    @State private var pin = ""
    @State private var shakeAmount: CGFloat = 0

    private let pinLength = 6

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dsTextPrimary)

                let displayText = errorMessage ?? subtitle
                if let displayText {
                    Text(displayText)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(errorMessage != nil ? Color.dsDanger : Color.dsTextTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            pinDots

            Spacer()

            numpad
                .padding(.bottom, 32)
        }
        .onChange(of: errorMessage) { newError in
            guard newError != nil else { return }
            withAnimation(.linear(duration: 0.4)) {
                shakeAmount += 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                pin = ""
            }
        }
    }

    // MARK: - Dots

    private var pinDots: some View {
        let hasError = errorMessage != nil
        return HStack(spacing: 14) {
            ForEach(0..<pinLength, id: \.self) { i in
                let filled = i < pin.count
                Circle()
                    .fill(filled ? (hasError ? Color.dsDanger : Color.dsAccentStrong) : Color.clear)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle().strokeBorder(
                            hasError ? Color.dsDanger : (filled ? Color.dsAccentStrong : Color.dsTextTertiary),
                            lineWidth: 1.5
                        )
                    )
            }
        }
        .modifier(ShakeEffect(animatableData: shakeAmount))
    }

    // MARK: - Numpad

    private var numpad: some View {
        VStack(spacing: 16) {
            ForEach(0..<3) { row in
                HStack(spacing: 24) {
                    ForEach(1...3, id: \.self) { col in
                        let digit = row * 3 + col
                        digitButton("\(digit)") { appendDigit("\(digit)") }
                    }
                }
            }
            HStack(spacing: 24) {
                Color.clear.frame(width: 72, height: 72)
                digitButton("0") { appendDigit("0") }
                deleteButton
            }
        }
    }

    private func digitButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.dsAccentStrong)
                .frame(width: 72, height: 72)
                .background(Color.dsSurface2)
                .clipShape(Circle())
        }
    }

    private var deleteButton: some View {
        Button(action: deleteDigit) {
            Image(systemName: "delete.left")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.dsTextPrimary)
                .frame(width: 72, height: 72)
        }
        .opacity(pin.isEmpty ? 0.35 : 1)
        .disabled(pin.isEmpty)
    }

    // MARK: - Actions

    private func appendDigit(_ digit: String) {
        guard pin.count < pinLength else { return }
        if errorMessage != nil { errorMessage = nil }
        pin += digit
        if pin.count == pinLength {
            let entered = pin
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                onComplete(entered)
            }
        }
    }

    private func deleteDigit() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
    }

}

private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: 10 * sin(animatableData * .pi * 4),
            y: 0
        ))
    }
}
