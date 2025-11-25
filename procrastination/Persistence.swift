import Foundation
import Supabase

/// 負責「整個 app 狀態」在 Supabase 之間的讀寫
final class Persistence {

    // MARK: - Snapshot（整個 App 的雲端資料狀態）
    struct Snapshot: Codable {
        var goals: [Goal]
        var tasksToday: [TaskItem]
        var moods: [MoodRecord]
        var achievements: [Achievement]
        var activity: ActivityStats
        var workstyle: Workstyle
        var preferences: UserPreferences
        var onboarding: Onboarding
        var hasOnboarded: Bool
        var procrastinationType: ProcrastinationType
        var conversations: [ChatThread]
    }

    // 對應 Supabase `user_profiles` 表的一列
    private struct UserProfileRow: Codable {
        var user_id: String
        var snapshot: Snapshot?
        var updated_at: Date?
    }

    // 預設 Snapshot（當 Supabase 沒資料時）
    static var empty: Snapshot {
        Snapshot(
            goals: [],
            tasksToday: [],
            moods: [],
            achievements: [],
            activity: ActivityStats(),
            workstyle: Workstyle(),
            preferences: UserPreferences(),
            onboarding: Onboarding(),
            hasOnboarded: false,
            procrastinationType: .unknown,
            conversations: []
        )
    }

    // MARK: - 依賴的 Supabase client

    private let client: SupabaseClient
    private let tableName = "user_profiles"

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    // MARK: - Load（從 Supabase 載入）

    /// 從 Supabase 載入指定 user 的 Snapshot
    /// - Parameter userId: auth.users.id（字串就好）
    /// - Returns: 該使用者的 Snapshot，若沒有就回傳 .empty
    func load(for userId: String?) async -> Snapshot {
        guard let userId, !userId.isEmpty else {
            print("⛔️ load 時沒有 userId，回傳空 Snapshot")
            return Self.empty
        }

        do {
            print("☁️ 從 Supabase 載入 snapshot for user_id=\(userId)")

            let row: UserProfileRow = try await client
                .from(tableName)
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value

            if let snapshot = row.snapshot {
                print("✅ 取得雲端 snapshot")
                return snapshot
            } else {
                print("ℹ️ 雲端 row 存在，但 snapshot 為空，回傳預設值")
                return Self.empty
            }
        } catch {
            // 如果 `select().single()` 找不到會丟錯（例如 406 or 404），這邊直接當沒資料處理
            print("⛔️ 從 Supabase 載入 snapshot 失敗：\(error)")
            return Self.empty
        }
    }

    // MARK: - Save（存到 Supabase）

    /// 儲存 Snapshot 到 Supabase 的 `user_profiles.snapshot`
    /// - 使用 upsert：第一次會 insert，之後再存會 update 同一列
    func save(snapshot: Snapshot, for userId: String?) async {
        guard let userId, !userId.isEmpty else {
            print("⛔️ save 時沒有 userId，略過")
            return
        }

        let payload = UserProfileRow(
            user_id: userId,
            snapshot: snapshot,
            updated_at: Date()
        )

        do {
            print("☁️ 將 snapshot 儲存到 Supabase for user_id=\(userId)")

            _ = try await client
                .from(tableName)
                .upsert(payload, onConflict: "user_id")
                .execute()

            print("💾 Supabase snapshot 儲存成功")
        } catch {
            print("⛔️ Supabase snapshot 儲存失敗：\(error)")
        }
    }
}
