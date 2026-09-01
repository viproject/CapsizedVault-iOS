//
//  QRScannerContainerView.swift
//  CapsizedVault
//
//  Created by Dmitrij on 16/04/2026.
//

import SwiftUI

import SwiftUI
import VisionKit
import Vision

// MARK: - QR Scanner Wrapper View

struct QRScannerContainerView: View {
    @State private var scannedValue: String? = nil
    @State private var showSaveButton = false
    @State private var isScanning = true
    
    var onResult: (String) -> Void

    var body: some View {
        ZStack {
            // Camera + DataScanner
            VisionQRScannerView(isScanning: $isScanning) { result in
                scannedValue = result
                withAnimation(.easeInOut) {
                    showSaveButton = true
                }
            }
            .ignoresSafeArea()

            // Overlay
            ScannerOverlayView(isRecognised: showSaveButton)

            // Save Button
            if showSaveButton, let value = scannedValue {
                VStack {
                    Spacer()
                    SaveButtonView(scannedValue: value) {
                        // Reset for next scan
                        scannedValue = nil
                        withAnimation(.easeInOut) {
                            showSaveButton = false
                        }
                        isScanning = true
                    } onSave: { value in
                        onResult(value)
                    }
                    .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

// MARK: - Scanner Overlay (Guide Frame)

struct ScannerOverlayView: View {
    var isRecognised: Bool

    var body: some View {
        GeometryReader { geo in
            let frameSize: CGFloat = 250
            let originX = (geo.size.width - frameSize) / 2
            let originY = (geo.size.height - frameSize) / 2

            ZStack {
                // Dimmed background with cutout
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .frame(width: frameSize, height: frameSize)
                                    .position(x: originX + frameSize / 2, y: originY + frameSize / 2)
                                    .blendMode(.destinationOut)
                            )
                            .compositingGroup()
                    )
                    .ignoresSafeArea()

                // Corner guides
                CornerGuideView(isRecognised: isRecognised)
                    .frame(width: frameSize, height: frameSize)
                    .position(x: originX + frameSize / 2, y: originY + frameSize / 2)

                // Label
                VStack(spacing: 8) {
                    Spacer()
                        .frame(height: originY + frameSize + 20)

                    Text(isRecognised ? "QR Code Detected!" : "Align QR code within the frame")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isRecognised ? Color.green.opacity(0.85) : Color.black.opacity(0.5))
                        )
                        .animation(.easeInOut, value: isRecognised)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Corner Guides

struct CornerGuideView: View {
    var isRecognised: Bool
    private let lineLength: CGFloat = 30
    private let lineWidth: CGFloat = 4
    private let cornerRadius: CGFloat = 6

    var guideColor: Color { isRecognised ? .green : .white }

    var body: some View {
        ZStack {
            // Top-left
            CornerShape(corner: .topLeft, length: lineLength, lineWidth: lineWidth, radius: cornerRadius)
            // Top-right
            CornerShape(corner: .topRight, length: lineLength, lineWidth: lineWidth, radius: cornerRadius)
            // Bottom-left
            CornerShape(corner: .bottomLeft, length: lineLength, lineWidth: lineWidth, radius: cornerRadius)
            // Bottom-right
            CornerShape(corner: .bottomRight, length: lineLength, lineWidth: lineWidth, radius: cornerRadius)
        }
        .foregroundStyle(guideColor)
        .animation(.easeInOut, value: isRecognised)
    }
}

// MARK: - Corner Shape

enum CornerPosition { case topLeft, topRight, bottomLeft, bottomRight }

struct CornerShape: Shape {
    let corner: CornerPosition
    let length: CGFloat
    let lineWidth: CGFloat
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = radius
        let l = length
        let hw = lineWidth / 2

        switch corner {
        case .topLeft:
            path.move(to: CGPoint(x: rect.minX + hw, y: rect.minY + l))
            path.addLine(to: CGPoint(x: rect.minX + hw, y: rect.minY + r))
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r),
                        radius: r - hw, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY + hw))

        case .topRight:
            path.move(to: CGPoint(x: rect.maxX - l, y: rect.minY + hw))
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY + hw))
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
                        radius: r - hw, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX - hw, y: rect.minY + l))

        case .bottomLeft:
            path.move(to: CGPoint(x: rect.minX + hw, y: rect.maxY - l))
            path.addLine(to: CGPoint(x: rect.minX + hw, y: rect.maxY - r))
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                        radius: r - hw, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX + l, y: rect.maxY - hw))

        case .bottomRight:
            path.move(to: CGPoint(x: rect.maxX - l, y: rect.maxY - hw))
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.maxY - hw))
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                        radius: r - hw, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX - hw, y: rect.maxY - l))
        }

        return path
    }
}

// MARK: - Save Button

struct SaveButtonView: View {
    let scannedValue: String
    let onReset: () -> Void
    let onSave: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(scannedValue)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 16) {
                Button(action: onReset) {
                    Label("Scan Again", systemImage: "arrow.counterclockwise")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.white.opacity(0.2)))
                }

                Button {
                    onSave(scannedValue)
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.green))
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.6)))
        .padding(.horizontal, 24)
    }
}

// MARK: -  Scanner

struct VisionQRScannerView: UIViewControllerRepresentable {
    
    @Binding var isScanning: Bool

    var onResult: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        
        if isScanning {
            if uiViewController.isScanning {
                uiViewController.stopScanning()
            }
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {

        var onResult: (String) -> Void

        init(onResult: @escaping (String) -> Void) {
            self.onResult = onResult
        }

        func dataScanner(_ scanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let value = barcode.payloadStringValue {
                    onResult(value)
                    break
                }
            }
        }
    }
}
