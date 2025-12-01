// AuthService.swift

import Foundation
import Supabase
import Auth

enum AuthService {
    private static var client: SupabaseClient {
        SupabaseManager.shared.client
    }
    
    private static func mapSupabaseError(_ error: AuthError) -> AppAuthError {
        // 你可以根據實際的 AuthError 結構調整這裡
        let message = error.localizedDescription.lowercased()

        if message.contains("user already registered")
            || message.contains("email already registered")
            || message.contains("duplicate key value") {
            return .emailTaken
        }

        if message.contains("invalid login credentials")
            || message.contains("invalid email or password") {
            return .invalidCredentials
        }

        if message.contains("password") && message.contains("weak") {
            return .weakPassword
        }

        if message.contains("banned") || message.contains("blocked") {
            return .banned
        }

        if message.contains("too many requests")
            || message.contains("rate limit") {
            return .rateLimited
        }

        return .server
    }

    
    // MARK: - Register
    static func register(
        email: String,
        displayName: String,
        password: String
    ) async throws -> AppUser {

        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: displayName.isEmpty
                    ? nil
                    : ["display_name": AnyJSON.string(displayName)]
            )

            let user = response.user

            // 取出 metadata 中的 display_name（如果有）
            let meta = user.userMetadata
            let displayNameJSON = meta["display_name"]
            let name: String?
            if case let .string(s) = displayNameJSON {
                name = s
            } else {
                name = nil
            }

            return AppUser(
                id: user.id,
                email: user.email ?? email,
                displayName: name
            )

        } catch let authError as AuthError {
                    // 🔥 這裡把 Supabase 的錯誤完整印出來
                    print("[AuthService.register] Supabase AuthError:", authError, authError.localizedDescription)
                    throw mapSupabaseError(authError)    // 轉成我們自己的 AppAuthError
                } catch {
                    print("[AuthService.register] unknown error:", error)
                    throw AppAuthError.server         // 不要硬轉成 .server，保留原始內容
                }
    }

    // MARK: - Login
    static func login(
        email: String,
        password: String
    ) async throws -> AppUser {

        do {
            // 1) 呼叫登入 API
            let _ = try await client.auth.signIn(
                email: email,
                password: password
            )

            // 2) 再從 auth 取出目前 session 的 user
            let session = try await client.auth.session
            let user = session.user

            // metadata 取 display_name
            let meta = user.userMetadata
            let displayNameJSON = meta["display_name"]
            let name: String?
            if case let .string(s) = displayNameJSON {
                name = s
            } else {
                name = nil
            }

            return AppUser(
                id: user.id,
                email: user.email ?? email,
                displayName: name
            )

        } catch let authError as AuthError {
                    print("[AuthService.login] Supabase AuthError:", authError, authError.localizedDescription)
                    throw mapSupabaseError(authError)   // 轉成我們自己的 AppAuthError
                } catch {
                    print("[AuthService.login] unknown error:", error)
                    throw AppAuthError.server
                }
    }

    // MARK: - Get Current User (from saved session, for auto-login)
    static func getCurrentUser() async throws -> AppUser? {
        do {
            let session = try await client.auth.session
            let user = session.user

            let meta = user.userMetadata
            let displayNameJSON = meta["display_name"]
            let name: String?
            if case let .string(s) = displayNameJSON {
                name = s
            } else {
                name = nil
            }

            return AppUser(
                id: user.id,
                email: user.email ?? "",
                displayName: name
            )
        } catch {
            // 通常是「沒有 session」或已過期 → 回傳 nil 即可
            return nil
        }
    }

    // MARK: - Logout
    static func logout() async {
        do {
            try await client.auth.signOut()
        } catch {
            print("[AuthService.logout] error:", error)
        }
    }
}
