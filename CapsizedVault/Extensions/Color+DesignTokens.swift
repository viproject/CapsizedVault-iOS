//
//  Color+DesignTokens.swift
//  CapsizedVault
//
//  Design token colors sourced from design_handoff_onboarding_screen/colors.css
//

import SwiftUI
import UIKit

extension Color {

    // MARK: - Palette

    static let green900 = Color(red: 0.231, green: 0.271, blue: 0.082)  // #3B4515
    static let green700 = Color(red: 0.310, green: 0.369, blue: 0.094)  // #4F5E18
    static let green600 = Color(red: 0.420, green: 0.478, blue: 0.165)  // #6B7A2A
    static let green400 = Color(red: 0.549, green: 0.604, blue: 0.329)  // #8C9A54
    static let green200 = Color(red: 0.871, green: 0.882, blue: 0.792)  // #DEE1CA
    static let green100 = Color(red: 0.929, green: 0.937, blue: 0.886)  // #EDEFE2
    static let cream50  = Color(red: 0.949, green: 0.933, blue: 0.902)  // #F2EEE6
    static let cream100 = Color(red: 0.925, green: 0.906, blue: 0.863)  // #ECE7DC
    static let cream200 = Color(red: 0.882, green: 0.871, blue: 0.843)  // #E1DED7
    static let ink900   = Color(red: 0.106, green: 0.137, blue: 0.125)  // #1B2320
    static let ink600   = Color(red: 27/255, green: 35/255, blue: 32/255, opacity: 0.6)  // rgba(27,35,32,0.6)
    static let ink400   = Color(red: 0.710, green: 0.698, blue: 0.675)  // #B5B2AC
    static let terracotta600 = Color(red: 0.682, green: 0.294, blue: 0.192)  // #AE4B31
    static let terracotta100 = Color(red: 0.949, green: 0.863, blue: 0.827)  // #F2DCD3

    // MARK: - Semantic aliases

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    static var dsBackground: Color {
        dynamic(
            light: UIColor(red: 0.949, green: 0.933, blue: 0.902, alpha: 1),      // cream50 #F2EEE6
            dark:  UIColor(red: 14/255, green: 22/255, blue: 20/255, alpha: 1)    // #0E1614
        )
    }
    static var dsSurface: Color {
        dynamic(
            light: UIColor(red: 0.949, green: 0.933, blue: 0.902, alpha: 1),      // cream50
            dark:  UIColor(red: 22/255, green: 32/255, blue: 29/255, alpha: 1)    // #16201D
        )
    }
    static var dsSurfaceRaised: Color {
        dynamic(
            light: UIColor.white,
            dark:  UIColor(red: 31/255, green: 42/255, blue: 38/255, alpha: 1)    // #1F2A26
        )
    }
    static var dsSurfaceSunken: Color {
        dynamic(
            light: UIColor(red: 0.925, green: 0.906, blue: 0.863, alpha: 1),      // cream100
            dark:  UIColor(red: 31/255, green: 42/255, blue: 38/255, alpha: 1)    // #1F2A26
        )
    }
    static var dsBorder: Color {
        dynamic(
            light: UIColor(red: 0.882, green: 0.871, blue: 0.843, alpha: 1),      // cream200
            dark:  UIColor(red: 240/255, green: 234/255, blue: 224/255, alpha: 0.08) // rgba(240,234,224,0.08)
        )
    }
    static var dsBorderStrong: Color {
        dynamic(
            light: UIColor(red: 0.710, green: 0.698, blue: 0.675, alpha: 1),      // ink400
            dark:  UIColor(red: 240/255, green: 234/255, blue: 224/255, alpha: 0.08) // rgba(240,234,224,0.08)
        )
    }
    static var dsTextPrimary: Color {
        dynamic(
            light: UIColor(red: 0.106, green: 0.137, blue: 0.125, alpha: 1),      // ink900
            dark:  UIColor(red: 240/255, green: 234/255, blue: 224/255, alpha: 1) // #F0EAE0
        )
    }
    static var dsTextSecondary: Color {
        dynamic(
            light: UIColor(red: 27/255, green: 35/255, blue: 32/255, alpha: 0.6),   // ink600
            dark:  UIColor(red: 240/255, green: 234/255, blue: 224/255, alpha: 0.62) // rgba(240,234,224,0.62)
        )
    }
    static var dsTextTertiary: Color {
        dynamic(
            light: UIColor(red: 0.710, green: 0.698, blue: 0.675, alpha: 1),         // ink400
            dark:  UIColor(red: 240/255, green: 234/255, blue: 224/255, alpha: 0.38) // rgba(240,234,224,0.38)
        )
    }
    static var dsTextOnAccent: Color {
        dynamic(
            light: UIColor(red: 0.949, green: 0.933, blue: 0.902, alpha: 1),      // cream50
            dark:  UIColor.white
        )
    }
    static let dsAccent      = green600  // #6B7A2A — same in both modes
    static var dsAccentStrong: Color {
        dynamic(
            light: UIColor(red: 0.310, green: 0.369, blue: 0.094, alpha: 1),      // green700 #4F5E18
            dark:  UIColor(red: 184/255, green: 201/255, blue: 98/255, alpha: 1)  // #B8C962
        )
    }
    static var dsAccentSoft: Color {
        dynamic(
            light: UIColor(red: 0.871, green: 0.882, blue: 0.792, alpha: 1),         // green200
            dark:  UIColor(red: 184/255, green: 201/255, blue: 98/255, alpha: 0.20)  // rgba(184,201,98,0.20)
        )
    }
    static var dsDanger: Color {
        dynamic(
            light: UIColor(red: 0.682, green: 0.294, blue: 0.192, alpha: 1),      // terracotta600 #AE4B31
            dark:  UIColor(red: 224/255, green: 103/255, blue: 78/255, alpha: 1)   // #E0674E — lighter for dark bg
        )
    }
    static var dsDangerSoft: Color {
        dynamic(
            light: UIColor(red: 0.949, green: 0.863, blue: 0.827, alpha: 1),       // terracotta100 #F2DCD3
            dark:  UIColor(red: 174/255, green: 75/255, blue: 49/255, alpha: 0.18) // rgba(174,75,49,0.18)
        )
    }

    // MARK: - Surface layers

    /// Subtle fills: icon tile bg, skeleton blocks, account avatar bg (≈ #ECE7DC / #1F2A26)
    static var dsSurface2: Color {
        dynamic(
            light: UIColor(red: 0.925, green: 0.906, blue: 0.863, alpha: 1),      // cream100
            dark:  UIColor(red: 44/255, green: 61/255, blue: 55/255, alpha: 1)    // #2C3D37
        )
    }

    // MARK: - Jade tint

    /// Jade at 14% opacity — account pill border/fill, icon tile tints
    static let dsJadeSoft = Color(red: 107/255, green: 122/255, blue: 42/255, opacity: 0.14)

    // MARK: - Sync state palette

    static let syncConnecting = Color(red: 0.757, green: 0.475, blue: 0.227)  // #C1793A
    static var syncConnectingSoft: Color {
        dynamic(
            light: UIColor(red: 0.961, green: 0.894, blue: 0.824, alpha: 1),       // #F5E4D2
            dark:  UIColor(red: 193/255, green: 121/255, blue: 58/255, alpha: 0.18) // rgba(193,121,58,0.18)
        )
    }
    static let syncSyncing = Color(red: 0.549, green: 0.478, blue: 0.165)  // #8C7A2A
    static var syncSyncingSoft: Color {
        dynamic(
            light: UIColor(red: 0.929, green: 0.902, blue: 0.788, alpha: 1),       // #EDE6C9
            dark:  UIColor(red: 140/255, green: 122/255, blue: 42/255, alpha: 0.18) // rgba(140,122,42,0.18)
        )
    }
    static var syncIdleSoft: Color {
        dynamic(
            light: UIColor(red: 0.906, green: 0.898, blue: 0.878, alpha: 1),       // #E7E5E0
            dark:  UIColor(red: 240/255, green: 234/255, blue: 224/255, alpha: 0.08) // rgba(240,234,224,0.08)
        )
    }
}
