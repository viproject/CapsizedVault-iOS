//
//  Font+DesignTokens.swift
//  CapsizedVault
//
//  Typography scale from design_handoff_onboarding_screen/typography.css
//  Uses SF Rounded as the system-native Manrope fallback (per design README).
//  JetBrains Mono → .monospaced design, used for addresses and seed words.
//

import SwiftUI

extension Font {
    static let dsDisplayXL = Font.system(size: 40, weight: .bold,    design: .rounded)    // 700 40/48
    static let dsDisplayLG = Font.system(size: 32, weight: .heavy,   design: .rounded)    // 800 32/40
    static let dsHeadingLG = Font.system(size: 24, weight: .bold,    design: .rounded)    // 700 24/32
    static let dsHeadingMD = Font.system(size: 20, weight: .bold,    design: .rounded)    // 700 20/28
    static let dsBodyLG    = Font.system(size: 17, weight: .medium,  design: .rounded)    // 500 17/26
    static let dsBodyMD    = Font.system(size: 15, weight: .medium,  design: .rounded)    // 500 15/22
    static let dsLabelMD   = Font.system(size: 15, weight: .semibold, design: .rounded)   // 600 14/20
    static let dsLabelMDBold = Font.system(size: 15, weight: .bold,  design: .rounded)   // 700 14/20
    static let dsBodySM    = Font.system(size: 13, weight: .medium,  design: .rounded)    // 500 13/18
    static let dsCaption2   = Font.system(size: 13, weight: .semibold, design: .rounded)   // 600 12/16
    static let dsCaption   = Font.system(size: 12, weight: .semibold, design: .rounded)   // 600 12/16
    static let dsButtonLG  = Font.system(size: 17, weight: .bold,    design: .rounded)    // 700 17pt
    static let dsMonoMD    = Font.system(size: 15, weight: .medium,  design: .monospaced) // 500 15/22
}
