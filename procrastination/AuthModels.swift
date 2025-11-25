// AuthModels.swift

import Foundation

/// 專門給登入 / 註冊用的使用者型別
struct AppUser: Identifiable, Codable {
    let id: UUID
    let email: String
    let displayName: String?
}

/// 登入 / 註冊常見錯誤
enum AuthError: LocalizedError {
    case emailTaken
    case invalidCredentials
    case server

    var errorDescription: String? {
        switch self {
        case .emailTaken:
            return "這個 Email 已經被註冊過了"
        case .invalidCredentials:
            return "Email 或密碼錯誤"
        case .server:
            return "伺服器錯誤，請稍後再試"
        }
    }
}
