//
//  HoldToSendButton.swift
//  CapsizedVault
//
//  Pure move out of SendXMRSummaryView.swift so SendZECSummaryView can share it too — no
//  behavior change. Generic "hold to confirm" affordance, no coin-specific logic.
//

import SwiftUI

// MARK: - HoldTimer

final class HoldTimer {
    var timer: Timer?

    func start(interval: TimeInterval, block: @escaping (Timer) -> Void) {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: block)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - HoldToSendButton

struct HoldToSendButton: View {
    let isSending: Bool
    let showError: Bool
    let resetTrigger: Int
    let action: () -> Void

    @State private var progress: CGFloat = 0
    @State private var didFire = false
    @State private var timerHolder = HoldTimer()

    private let holdDuration: Double = 1.5
    private let tickInterval: Double = 1.0 / 60.0

    var body: some View {
        ZStack {
            // Background track
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.dsAccent.opacity(0.5))

            // Progress fill — plain Rectangle clipped to rounded shape so the
            // right edge stays straight while filling, rounds fully when complete
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.dsAccent)
                    .frame(width: geo.size.width * progress, height: geo.size.height)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Label
            if isSending {
                ProgressView()
                    .tint(.white)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(progress > 0 ? "Keep holding..." : "Hold to send")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
            }
        }
        .frame(height: 52)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in startHolding() }
                .onEnded { _ in endHolding() }
        )
        .disabled(isSending)
        // Reset when a send error is shown.
        .onChange(of: showError) { hasError in
            if hasError {
                didFire = false
                progress = 0
            }
        }
        // Reset when auth is cancelled so the user can hold again.
        .onChange(of: resetTrigger) { _ in
            didFire = false
            withAnimation(.easeOut(duration: 0.3)) { progress = 0 }
        }
    }

    private func startHolding() {
        guard !didFire, !isSending else { return }
        timerHolder.start(interval: tickInterval) { _ in
            let increment = CGFloat(tickInterval / holdDuration)
            if progress + increment >= 1.0 {
                progress = 1.0
                timerHolder.stop()
                didFire = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                action()
            } else {
                progress += increment
            }
        }
    }

    private func endHolding() {
        timerHolder.stop()
        guard !didFire else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            progress = 0
        }
    }
}
