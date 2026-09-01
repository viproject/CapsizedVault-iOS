//
//  AddWalletViewModel.swift
//  CapsizedVault
//
//  Created by Dmitrij on 13/01/2026.
//

import Foundation
import Combine

enum SeedType: String, CaseIterable, Identifiable {
    case polyseed = "Polyseed"
    case legacy = "Legacy"

    var id: String { rawValue }

    var wordCount: Int {
        switch self {
        case .polyseed: return 16
        case .legacy: return 25
        }
    }
}

enum PolyseedLanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case spanish = "Spanish"
    case french = "French"
    case italian = "Italian"
    case portuguese = "Portuguese"
    case japanese = "Japanese"
    case korean = "Korean"
    case czech = "Czech"
    case chineseSimplified = "Chinese (Simplified)"
    case chineseTraditional = "Chinese (Traditional)"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .czech: return "Czech"
        case .chineseSimplified: return "Chinese (Simplified)"
        case .chineseTraditional: return "Chinese (Traditional)"
        }
    }

    // Native names as registered in the polyseed C library (.name field in lang_*.c)
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "español"
        case .french: return "français"
        case .italian: return "italiano"
        case .portuguese: return "português"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .czech: return "čeština"
        case .chineseSimplified: return "中文(简体)"
        case .chineseTraditional: return "中文(繁體)"
        }
    }
}

enum LegacySeedLanguage: String, CaseIterable, Identifiable {
    case english = "English"
    case spanish = "Spanish"
    case french = "French"
    case italian = "Italian"
    case portuguese = "Portuguese"
    case japanese = "Japanese"
    case chineseSimplified = "Chinese (Simplified)"
    case dutch = "Dutch"
    case german = "German"
    case russian = "Russian"
    case esperanto = "Esperanto"
    case lojban = "Lojban"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .japanese: return "Japanese"
        case .chineseSimplified: return "Chinese (Simplified)"
        case .dutch: return "Dutch"
        case .german: return "German"
        case .russian: return "Russian"
        case .esperanto: return "Esperanto"
        case .lojban: return "Lojban"
        }
    }

    // Language name as expected by the Monero C library (MONERO_WalletManager_createWallet / recoveryWallet).
    // Most match rawValue exactly. Chinese Simplified is the exception: the C library registers the
    // language with get_language_name() == "Chinese (simplified)" (lowercase 's'). The rawValue
    // "Chinese (Simplified)" (capital S) is the english_language_name which may not be checked for
    // matching in this xcframework build, resulting in bytes_to_words() returning an empty seed.
    var cLibraryName: String {
        switch self {
        case .chineseSimplified: return "Chinese (simplified)"
        default: return rawValue
        }
    }
}

class AddWalletViewModel: ObservableObject {

    class AWNewMoneroWallet {
        var title: String? = nil
        var seed: String? = nil
        var passphrase = ""
        var backedUp: Bool = false
        var seedType: SeedType = .polyseed
        var polyseedLanguage: PolyseedLanguage = .english
        var legacySeedLanguage: LegacySeedLanguage = .english
    }
    
    class AWRestoreMoneroWallet {
        var title: String? = nil
        var isFromSeed = true
        var seed: String? = nil
        var passphrase = ""
        var publicAddress: String? = nil
        var viewKey: String? = nil
        var spendKey: String? = nil
        var restoreHeight = 0
        var restoreDate: Date? = nil
        
        func canUseRestoreOptions () -> Bool {
            if isFromSeed && seed?.split(separator: " ").count == 16 {
                return false
            }
            return true
        }
    }
    
    var newMoneroWalletData: AWNewMoneroWallet = AWNewMoneroWallet()
    var restoreMoneroWalletData: AWRestoreMoneroWallet = AWRestoreMoneroWallet()
    
}
