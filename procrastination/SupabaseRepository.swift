// SupabaseRepository.swift
import Foundation
import Supabase
import PostgREST

// MARK: - AnyEncodable（Supabase 2.x 未內建時可自行加）
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void
    init<T: Encodable>(_ wrapped: T) {
        _encode = wrapped.encode
    }
    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }

    // ✅ 提供方便初始化的靜態方法
    static func string(_ value: String) -> AnyEncodable { AnyEncodable(value) }
    static func bool(_ value: Bool) -> AnyEncodable { AnyEncodable(value) }
    static func int(_ value: Int) -> AnyEncodable { AnyEncodable(value) }
    static func double(_ value: Double) -> AnyEncodable { AnyEncodable(value) }
}


enum SupabaseRepoError: Error {
    case noAuthSession
    case invalidUserId
}

// MARK: - 日期工具
private let yyyyMMdd: DateFormatter = {
    let df = DateFormatter()
    df.calendar = Calendar(identifier: .gregorian)
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(secondsFromGMT: 0)
    df.dateFormat = "yyyy-MM-dd"
    return df
}()

private let iso8601Full: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
}()

private func toDate(_ s: String?) -> Date? {
    guard let s, !s.isEmpty else { return nil }
    return iso8601Full.date(from: s)
        ?? ISO8601DateFormatter().date(from: s)
        ?? yyyyMMdd.date(from: s)
}

private func toDateString(_ d: Date?) -> String? {
    guard let d else { return nil }
    return yyyyMMdd.string(from: d)
}

private func toISO8601String(_ d: Date?) -> String? {
    guard let d else { return nil }
    return iso8601Full.string(from: d)
}

// MARK: - DB Rows（資料表對應）

struct DBGoalRow: Codable {
    let id: UUID
    let user_id: UUID
    let title: String
    let icon: String
    let color_hex: String
    let start_date: String?   // yyyy-MM-dd
    let deadline: String?     // yyyy-MM-dd
    let created_at: String?   // ISO8601
}

struct DBTaskRow: Codable {
    let id: UUID
    let goal_id: UUID
    let title: String
    let is_completed: Bool
    let due_date: String?         // yyyy-MM-dd
    let estimated_duration: String?
}

struct DBMoodRow: Codable {
    let id: UUID
    let user_id: UUID
    let date: String              // ISO8601
    let mood_score: Int
    let note: String
}

struct DBConversationRow: Codable {
    let id: UUID
    let user_id: UUID
    let title: String?
    let last_updated: String?     // ISO8601
}

struct DBMessageRow: Codable {
    let id: UUID
    let conversation_id: UUID
    let role: String             // "user" | "assistant"
    let text: String
    let created_at: String?      // ISO8601
}

// ===== user_profiles（把使用者層級資料集中存）=====

struct PreferencesDTO: Codable {
    var longTask: String
    var arrangeStrategy: String
    var focusSpan: String
    var weekdayWeekend: String
}

struct WorkstyleDTO: Codable {
    var dailyHours: [Double]
}

struct OnboardingDTO: Codable {
    var needExternalPressure: Int
    var anxietyStart: Int
    var pressureNeed: Int
    var researchLoop: Int
    var lastMinute: Int
    var selfBlame: Int
    var perfectionismPrep: Int
    var noPressureIdle: Int
}

struct ActivityDTO: Codable {
    var weekCompletedCount: Int
    var monthCompletedCount: Int
}

struct DBUserProfileRow: Codable {
    let user_id: UUID
    let has_onboarded: Bool?
    let procrastination_type: String?
    let preferences: PreferencesDTO?
    let workstyle: WorkstyleDTO?
    let onboarding: OnboardingDTO?
    let activity: ActivityDTO?
    let achievements: [String]?    // 先用字串清單，如果你未來要更多欄位再拆表
    let updated_at: String?
}

// MARK: - Repository

final class SupabaseRepository {
    static let shared = SupabaseRepository()
    private init() {}

    private let db: SupabaseClient = SupabaseManager.shared.client

    // 取得目前的使用者 UUID
    // - 若已登入 Supabase Auth，優先用 auth.user.id
    // - 否則回退到 DevUser.id（本機測試用）
    private func currentUID() async throws -> UUID {
        do {
            let session = try await db.auth.session
            return session.user.id
        } catch {
            throw SupabaseRepoError.noAuthSession
        }
    }



    // 確保 users 表有這個 dev user（或 auth user）
    // 確保 users 表有這個 dev user（或 auth user）
    func ensureUserRowExistsIfNeeded(displayName: String? = "Dev User", email: String? = nil) async {
        struct UserRow: Encodable { let id: UUID; let email: String?; let display_name: String? }
        do {
            let uid = try await currentUID()
            let row = UserRow(id: uid, email: email, display_name: displayName)
            try await db.from("users").upsert(row).execute()
        } catch {
            print("[ensureUserRowExistsIfNeeded] ignore error:", error)
        }
    }



    // 開發用：最小 smoke 測試（避免複雜 JSON 先擾亂）
    func smokeInsertUserProfilesMinimal() async {
        do {
            let uid = try await currentUID()
            let mini: [String: AnyEncodable] = [
                "user_id": .string(uid.uuidString),
                "has_onboarded": .bool(true)
            ]
            let resp = try await db
                .from("user_profiles")
                .insert(mini)   // 只插兩欄
                .select()       // 選回插入列
                .single()       // 注意：若 RLS/constraint 阻擋會 throw
                .execute()
            print("[SMOKE] insert OK bytes:", resp.data.count)
            print("[SMOKE] body:", String(data: resp.data, encoding: .utf8) ?? "<non-utf8>")
        } catch {
            print("[SMOKE] ❌ insert error:", error)
        }
    }

    // MARK: - 上傳（Upsert / Insert）

    func upsertGoal(_ g: Goal) async throws {
        let uid = try await currentUID()
        let row = DBGoalRow(
            id: g.id,
            user_id: uid,
            title: g.title,
            icon: g.icon,
            color_hex: g.colorHex,
            start_date: toDateString(g.startDate),
            deadline: toDateString(g.deadline),
            created_at: toISO8601String(g.createdAt)
        )
        do {
            try await db.from("goals").upsert(row).execute()
        } catch {
            print("[Supabase] upsertGoal error:", error)
            throw error
        }

        // 同步子任務
        for t in g.subTasks {
            try await upsertTask(t, goalId: g.id)
        }
    }

    func upsertTask(_ t: TaskItem, goalId: UUID) async throws {
        let row = DBTaskRow(
            id: t.id,
            goal_id: goalId,
            title: t.title,
            is_completed: t.isCompleted,
            due_date: toDateString(t.dueDate),
            estimated_duration: t.estimatedDuration
        )
        do {
            try await db.from("tasks").upsert(row).execute()
        } catch {
            print("[Supabase] upsertTask error:", error)
            throw error
        }
    }

    func upsertMood(_ m: MoodRecord) async throws {
        let uid = try await currentUID()
        let row = DBMoodRow(
            id: m.id,
            user_id: uid,
            date: toISO8601String(m.date) ?? ISO8601DateFormatter().string(from: m.date),
            mood_score: m.moodScore,
            note: m.note
        )
        do {
            try await db.from("moods").upsert(row).execute()
        } catch {
            print("[Supabase] upsertMood error:", error)
            throw error
        }
    }

    func upsertConversation(_ c: ChatThread) async throws {
        let uid = try await currentUID()
        let row = DBConversationRow(
            id: c.id,
            user_id: uid,
            title: c.title,
            last_updated: toISO8601String(c.lastUpdated)
        )
        do {
            try await db.from("conversations").upsert(row).execute()
        } catch {
            print("[Supabase] upsertConversation error:", error)
            throw error
        }

        // 連同訊息一起上傳（避免忘記另外呼叫）
        for m in c.messages {
            try await upsertMessage(m, conversationId: c.id)
        }
    }

    func upsertMessage(_ m: ChatMessage, conversationId: UUID) async throws {
        let row = DBMessageRow(
            id: m.id,
            conversation_id: conversationId,
            role: (m.role == .user ? "user" : "assistant"),
            text: m.text,
            created_at: toISO8601String(m.date)
        )
        do {
            try await db.from("messages").upsert(row).execute()
        } catch {
            print("[Supabase] upsertMessage error:", error)
            throw error
        }
    }

    // user_profiles：把 AppStore 的使用者層級資料一次上傳
    func upsertUserProfile(from store: AppStore) async throws {
        let uid = try await currentUID()

        // 1) 把 enum 轉成 String
        let pref = PreferencesDTO(
            longTask: store.preferences.longTask.rawValue,
            arrangeStrategy: store.preferences.arrangeStrategy.rawValue,
            focusSpan: store.preferences.focusSpan.rawValue,
            weekdayWeekend: store.preferences.weekdayWeekend.rawValue
        )
        let work = WorkstyleDTO(dailyHours: store.workstyle.dailyHours)
        let onbd = OnboardingDTO(
            needExternalPressure: store.onboarding.needExternalPressure,
            anxietyStart: store.onboarding.anxietyStart,
            pressureNeed: store.onboarding.pressureNeed,
            researchLoop: store.onboarding.researchLoop,
            lastMinute: store.onboarding.lastMinute,
            selfBlame: store.onboarding.selfBlame,
            perfectionismPrep: store.onboarding.perfectionismPrep,
            noPressureIdle: store.onboarding.noPressureIdle
        )
        let act = ActivityDTO(
            weekCompletedCount: store.activity.weekCompletedCount,
            monthCompletedCount: store.activity.monthCompletedCount
        )
        let achievementTitles: [String] = store.achievements.map { $0.title }

        // 2) updated_at 寫入，方便在後台看更新時間
        let row = DBUserProfileRow(
            user_id: uid,
            has_onboarded: store.hasOnboarded,
            procrastination_type: store.procrastinationType.rawValue,
            preferences: pref,
            workstyle: work,
            onboarding: onbd,
            activity: act,
            achievements: achievementTitles,
            updated_at: toISO8601String(Date())
        )

        // 3) onConflict: "user_id"（存在則更新，不存在則插入）
        do {
            try await db
                .from("user_profiles")
                .upsert(row, onConflict: "user_id")
                .execute()
        } catch {
            print("[Supabase] upsertUserProfile error:", error)
            throw error
        }
    }

    // MARK: - 下載（Fetch）

    func fetchGoals() async throws -> [Goal] {
        let uid = try await currentUID()
        let resp = try await db.from("goals")
            .select()
            .eq("user_id", value: uid.uuidString)
            .order("created_at", ascending: true)
            .execute()

        let rows = try JSONDecoder().decode([DBGoalRow].self, from: resp.data)
        return rows.map { r in
            Goal(
                id: r.id,
                title: r.title,
                icon: r.icon,
                colorHex: r.color_hex,
                startDate: toDate(r.start_date),
                deadline: toDate(r.deadline),
                reminders: [],
                subTasks: [],
                createdAt: toDate(r.created_at) ?? Date()
            )
        }
    }

    func fetchTasks(goalId: UUID) async throws -> [TaskItem] {
        let resp = try await db.from("tasks")
            .select()
            .eq("goal_id", value: goalId.uuidString)
            .order("due_date", ascending: true)
            .execute()

        let rows = try JSONDecoder().decode([DBTaskRow].self, from: resp.data)
        return rows.map { r in
            TaskItem(
                id: r.id,
                title: r.title,
                isCompleted: r.is_completed,
                dueDate: toDate(r.due_date),
                estimatedDuration: r.estimated_duration
            )
        }
    }

    func fetchMoods() async throws -> [MoodRecord] {
        let uid = try await currentUID()
        let resp = try await db.from("moods")
            .select()
            .eq("user_id", value: uid.uuidString)
            .order("date", ascending: true)
            .execute()

        let rows = try JSONDecoder().decode([DBMoodRow].self, from: resp.data)
        return rows.map { r in
            MoodRecord(
                id: r.id,
                date: toDate(r.date) ?? Date(),
                moodScore: r.mood_score,
                note: r.note
            )
        }
    }

    func fetchConversations() async throws -> [ChatThread] {
        let uid = try await currentUID()
        let resp = try await db.from("conversations")
            .select()
            .eq("user_id", value: uid.uuidString)
            .order("last_updated", ascending: false)
            .execute()

        let rows = try JSONDecoder().decode([DBConversationRow].self, from: resp.data)
        return rows.map { r in
            ChatThread(
                id: r.id,
                title: r.title ?? "Untitled",
                messages: [],
                relatedGoalID: nil,
                lastUpdated: toDate(r.last_updated) ?? Date()
            )
        }
    }

    func fetchMessages(conversationId: UUID) async throws -> [ChatMessage] {
        let resp = try await db.from("messages")
            .select()
            .eq("conversation_id", value: conversationId.uuidString)
            .order("created_at", ascending: true)
            .execute()

        let rows = try JSONDecoder().decode([DBMessageRow].self, from: resp.data)
        return rows.map { r in
            ChatMessage(
                id: r.id,
                role: r.role == "user" ? .user : .assistant,
                text: r.text,
                date: toDate(r.created_at) ?? Date()
            )
        }
    }

    func fetchUserProfile() async throws -> DBUserProfileRow? {
        let uid = try await currentUID()
        let resp = try await db.from("user_profiles")
            .select()
            .eq("user_id", value: uid.uuidString)
            .limit(1)
            .execute()

        let arr = try JSONDecoder().decode([DBUserProfileRow].self, from: resp.data)
        return arr.first
    }

    // MARK: - 批次：一次抓／一次推

    /// 從雲端抓回全部（Goals 附 Tasks、Conversations 附 Messages）
    func fetchAll() async throws -> (goals: [Goal], moods: [MoodRecord], conversations: [ChatThread], profile: DBUserProfileRow?) {
        var goals = try await fetchGoals()
        for i in goals.indices {
            let gid = goals[i].id
            goals[i].subTasks = try await fetchTasks(goalId: gid)
        }
        let moods = try await fetchMoods()

        var convos = try await fetchConversations()
        for i in convos.indices {
            let cid = convos[i].id
            convos[i].messages = try await fetchMessages(conversationId: cid)
        }

        let profile = try await fetchUserProfile()
        return (goals, moods, convos, profile)
    }

    /// 把本地的所有資料一次上傳（含 subtasks / messages / profile）
    func pushAll(from store: AppStore) async throws {
        // ✅ 1. 一進來就檢查有沒有登入
        let uid: UUID
        do {
            uid = try await currentUID()
        } catch {
            print("❌ pushAll: no auth session, skip cloud sync")
            throw error
        }

        await ensureUserRowExistsIfNeeded(displayName: "App User")


        // user profile 先上傳（避免沒有 profile 的情況）
        try await upsertUserProfile(from: store)

        // goals + tasks
        for g in store.goals {
            try await upsertGoal(g)
        }

        // moods
        for m in store.moods {
            try await upsertMood(m)
        }

        // conversations + messages
        for c in store.conversations {
            try await upsertConversation(c) // 會順帶上傳 messages
        }
    }
}
// MARK: - Group Goals（社群任務，多人合作/競爭）
extension SupabaseRepository {

    // 對應 Supabase 的 group_goals
    struct GroupGoalRow: Codable {
        var id: UUID
        var title: String
        var description: String?
        var icon: String?
        var color_hex: String?
        var start_date: String?    // yyyy-MM-dd
        var deadline: String?      // yyyy-MM-dd
        var social_mode: String    // "cooperate" / "compete"
        var creator_id: UUID
        var created_at: String?    // ISO8601
    }

    // 對應 Supabase 的 group_participants
    struct GroupParticipantRow: Codable {
        var id: UUID
        var group_id: UUID
        var user_id: UUID?
        var email: String
        var role: String           // "owner" / "member"
        var progress: Double?
        var joined_at: String?     // ISO8601
    }

    // ⭐ 1) 建立 group goal + participants
    func createGroupGoal(
        groupId: UUID,
        title: String,
        description: String?,
        icon: String?,
        colorHex: String?,
        startDate: Date,
        deadline: Date,
        socialMode: String,
        ownerUserId: UUID,
        ownerEmail: String,
        participantEmails: [String]
    ) async throws {

        // ---- A. 建立 group_goals 的一列 ----
        let groupRow = GroupGoalRow(
            id: groupId,
            title: title,
            description: description,
            icon: icon,
            color_hex: colorHex,
            start_date: toDateString(startDate),
            deadline: toDateString(deadline),
            social_mode: socialMode,
            creator_id: ownerUserId,
            created_at: toISO8601String(Date())
        )

        try await db
            .from("group_goals")
            .insert(groupRow)
            .execute()

        // ---- B. 建立 group_participants 多列 ----
        let rows: [GroupParticipantRow] = participantEmails.map { email in
            GroupParticipantRow(
                id: UUID(),
                group_id: groupId,
                user_id: nil, // 之後可以用 email → user_id mapping 再補
                email: email,
                role: (email == ownerEmail ? "owner" : "member"),
                progress: 0,
                joined_at: toISO8601String(Date())
            )
        }

        try await db
            .from("group_participants")
            .insert(rows)
            .execute()

        print("🍏 Successfully created group_goal + participants")
    }

    // ⭐ 2) 抓這個 email 參與的所有 group_goals
    func fetchGroupGoals(forEmail email: String) async throws -> [GroupGoalRow] {

        // 先從 group_participants 找出所有 group_id
        let participantResp = try await db
            .from("group_participants")
            .select()
            .eq("email", value: email)
            .execute()

        let participants = try JSONDecoder().decode(
            [GroupParticipantRow].self,
            from: participantResp.data
        )

        let groupIds = participants.map { $0.group_id }
        if groupIds.isEmpty { return [] }

        // 再用這些 group_id 去 group_goals 抓資料
        let goalsResp = try await db
            .from("group_goals")
            .select()
            .in("id", values: groupIds.map { $0.uuidString })
            .execute()

        let goals = try JSONDecoder().decode(
            [GroupGoalRow].self,
            from: goalsResp.data
        )

        return goals
    }

    // ⭐ 3) 抓某個 group 的所有成員
    func fetchParticipants(groupId: UUID) async throws -> [GroupParticipantRow] {
        let resp = try await db
            .from("group_participants")
            .select()
            .eq("group_id", value: groupId.uuidString)
            .execute()

        let rows = try JSONDecoder().decode(
            [GroupParticipantRow].self,
            from: resp.data
        )

        return rows
    }

    // ⭐ 4) 更新某個成員在 group 中的 progress
    func updateParticipantProgress(
        _ progress: Double,
        groupId: UUID,
        email: String
    ) async throws {

        try await db
            .from("group_participants")
            .update(["progress": progress])
            .eq("group_id", value: groupId.uuidString)
            .eq("email", value: email)
            .execute()
    }
}


