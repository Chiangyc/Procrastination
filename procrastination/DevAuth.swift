// DevAuth.swift
import Supabase

enum DevAuth {
    static func signInIfNeeded(client: SupabaseClient) async {
        // 已有 session 就直接返回
        if (try? await client.auth.session) != nil {
            print("🔐 Already signed in")
            return
        }
        print("ℹ️ No session, will sign in a dev account…")

        // 👇 換成有效 email！
        let email = "你的真實Email@example.com"
        let password = "DevPass123!"   // 自訂

        do {
            try await client.auth.signIn(email: email, password: password)
            print("✅ Signed in with dev account")
        } catch {
            print("ℹ️ Sign in failed, trying sign up… error:", error)
            do {
                _ = try await client.auth.signUp(email: email, password: password)
                try await client.auth.signIn(email: email, password: password)
                print("✅ Signed up & signed in dev account")
            } catch {
                print("❌ Dev sign-in/sign-up failed:", error)
            }
        }
    }
}
