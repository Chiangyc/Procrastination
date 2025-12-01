// AuthModels.swift

import Foundation

/// 專門給登入 / 註冊用的使用者型別
struct AppUser: Identifiable, Codable {
    let id: UUID
    let email: String
    let displayName: String?
}

/// 登入 / 註冊常見錯誤
enum AppAuthError: LocalizedError {
    case emailTaken
    case invalidCredentials
    case weakPassword
    case banned
    case rateLimited
    case server

    var errorDescription: String? {
        switch self {
        case .emailTaken:
            return "這個 Email 已經被註冊過了"
        case .invalidCredentials:
            return "Email 或密碼錯誤"
        case .weakPassword:
            return "密碼太簡單，請再複雜一點"
        case .banned:
            return "此帳號已被停用，如有疑問請聯絡客服"
        case .rateLimited:
            return "請求太頻繁，請稍後再試"
        case .server:
            return "伺服器錯誤，請稍後再試"
        }
    }
}


