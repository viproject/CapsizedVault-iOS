//
//  SwipeToEditDeleteRow.swift
//  CapsizedVault
//
//  Generic swipe-to-reveal edit/delete actions for a list row. Originally private to
//  NodeSettingsView — hoisted out (pure move, no behavior change) so ZcashServerSettingsView's
//  custom-server list can share it, since there's no coin-specific logic in it.
//

import SwiftUI

struct SwipeToEditDeleteRow<Content: View>: View {
    let isOpen: Bool
    let onOpenChange: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offsetX: CGFloat = 0
    private let revealWidth: CGFloat = 152
    private let actionWidth: CGFloat = 76

    var body: some View {
        ZStack(alignment: .trailing) {
            // Row content — stays in place; the action panel overlays it from the right
            content()
                .background(Color.dsSurfaceRaised)
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            let base: CGFloat = isOpen ? -revealWidth : 0
                            offsetX = max(-revealWidth, min(0, base + value.translation.width))
                        }
                        .onEnded { value in
                            let base: CGFloat = isOpen ? -revealWidth : 0
                            let final = max(-revealWidth, min(0, base + value.translation.width))
                            snap(open: final < -revealWidth / 2)
                        }
                )
                .simultaneousGesture(
                    TapGesture().onEnded {
                        if isOpen { snap(open: false) }
                    }
                )
                .onChange(of: isOpen) { newValue in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                        offsetX = newValue ? -revealWidth : 0
                    }
                }

            // Action panel — overlays the row from the right as it's revealed
            HStack(spacing: 0) {
                Button(action: { snap(open: false); DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onEdit() } }) {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .medium))
                        Text("Edit")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.dsTextPrimary)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.dsSurface2)
                }

                Button(action: { snap(open: false); DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDelete() } }) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .medium))
                        Text("Delete")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.dsDanger)
                }
            }
            .frame(width: revealWidth)
            .offset(x: revealWidth + offsetX)
        }
        .clipped()
    }

    private func snap(open: Bool) {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
            onOpenChange(open)
            offsetX = open ? -revealWidth : 0
        }
    }
}
