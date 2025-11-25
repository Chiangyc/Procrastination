// SupabaseManager.swift

import Foundation
import Supabase
import Auth
import PostgREST   // ✅ 給 db: .init(schema:) 用

enum SupabaseConfig {
    static let url = URL(string: "https://wsmchsycxszigctdkvvd.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndzbWNoc3ljeHN6aWdjdGRrdnZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjIzMjI5ODAsImV4cCI6MjA3Nzg5ODk4MH0.DPWSwMrpqDk9bNJNdpXkpiCAG4i1FtyKXSxUnMYaqJI"
}

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey,
            options: .init(
                // ✅ 只設定 DB schema，其他都用預設
                db: .init(schema: "public")
                // auth, global 都先用預設值：
                // 預設其實就會自動 refresh + 存 session
            )
        )
    }
}
