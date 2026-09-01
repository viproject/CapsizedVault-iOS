//
//  View+Extensions.swift
//  CapsizedVault
//
//  Created by Dmitrij on 14/01/2026.
//

import Foundation
import SwiftUI
import UIKit


//MARK: - Toast Message

struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String
    
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            
            if isPresented {
                Text(message)
                    .font(.system(size: 18))
                    .padding(15)
                    .background(Color(.systemGray5))
                    .foregroundColor(Color(.label))
                    .cornerRadius(15)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                            withAnimation {
                                isPresented = false
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isPresented)
    }
}

extension View {
    func toast(message: String, isPresented: Binding<Bool>) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message))
    }
}

// MARK: - ScrollView instant touch response

/// Apply to the content VStack inside a ScrollView.
/// Walks up the UIKit hierarchy to find the UIScrollView and sets
/// `delaysContentTouches = false`, so buttons respond instantly instead
/// of waiting for scroll-intent detection.
extension View {
    func instantScrollViewTouches() -> some View {
        background(InstantTouchScrollViewBridge())
    }
}

private struct InstantTouchScrollViewBridge: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            var view: UIView? = uiView.superview
            while let v = view {
                if let scrollView = v as? UIScrollView {
                    scrollView.delaysContentTouches = false
                    return
                }
                view = v.superview
            }
        }
    }
}

// MARK: - Top-only rounded corners (used for bottom sheets)

/// A shape that rounds only the top two corners — used to clip bottom sheet containers.
struct TopRoundedShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            p.addArc(
                center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
            p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            p.addArc(
                center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                radius: radius,
                startAngle: .degrees(270),
                endAngle: .degrees(0),
                clockwise: false
            )
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}


