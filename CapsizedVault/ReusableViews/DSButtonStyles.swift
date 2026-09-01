//
//  DSButtonStyles.swift
//  CapsizedVault
//
//  Shared ButtonStyle conformances for the design system's two pill button variants.
//  Usage:
//    Button("Create a new wallet", action: ...).buttonStyle(.dsPrimary)
//    Button("I have a seed phrase", action: ...).buttonStyle(.dsSecondary)
//

import SwiftUI

// MARK: - Primary — green600 fill, white text, h56 capsule

struct DSPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dsButtonLG)
            .foregroundColor(.dsTextOnAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.dsAccent.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Secondary — transparent fill, ink400 border, ink900 text, h56 capsule

struct DSSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dsButtonLG)
            .foregroundColor(.dsTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .overlay(Capsule().stroke(Color.dsTextTertiary, lineWidth: 1))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Soft — opacity feedback for custom-styled icon or small action buttons

struct DSSoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Convenience extensions

extension ButtonStyle where Self == DSPrimaryButtonStyle {
    static var dsPrimary: DSPrimaryButtonStyle { DSPrimaryButtonStyle() }
}

extension ButtonStyle where Self == DSSecondaryButtonStyle {
    static var dsSecondary: DSSecondaryButtonStyle { DSSecondaryButtonStyle() }
}

extension ButtonStyle where Self == DSSoftButtonStyle {
    static var dsSoft: DSSoftButtonStyle { DSSoftButtonStyle() }
}
