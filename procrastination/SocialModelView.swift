//  SocialModeView.swift

import SwiftUI
import Supabase

// MARK: - Social Models（不再宣告 SocialMode）

struct GroupGoal: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var description: String
    var targetValue: Int
    var currentValue: Int
    var unit: String
    var deadline: Date

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(Double(currentValue) / Double(targetValue), 1.0)
    }

    var daysRemaining: Int {
        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: now, to: deadline).day ?? 0
        return max(0, days)
    }
}

struct SocialMember: Identifiable, Equatable, Codable {
    var id: UUID
    var userId: String
    var displayName: String
    var avatarColorHex: String
    var procrastinationType: ProcrastinationType
    var completedGroupTasks: Int
    var contributedValue: Int
    var score: Int
    var streakDays: Int
    var isCurrentUser: Bool

    var avatarInitial: String {
        String(displayName.prefix(1)).uppercased()
    }

    var procrastinationTypeTag: String {
        let typeRaw = procrastinationType.rawValue

        if typeRaw.contains("完美") {
            return "完美"
        } else if typeRaw.contains("死線") || typeRaw.contains("戰士") {
            return "死線"
        } else if typeRaw.contains("逃避") {
            return "逃避"
        } else if typeRaw.contains("決策") {
            return "決策"
        } else {
            return "未知"
        }
    }
}

// MARK: - Repository Protocol

protocol SocialGroupRepository {
    func fetchCurrentGroupGoal() async throws -> GroupGoal
    func fetchMembers() async throws -> [SocialMember]
}

// MARK: - Supabase Repository 實作（正式用）

final class SupabaseSocialGroupRepository: SocialGroupRepository {
    private let repo = SupabaseRepository.shared
    private let client = SupabaseManager.shared.client

    // 解析 yyyy-MM-dd 或 ISO8601 的小工具
    private static let yyyyMMdd: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private static func parseDate(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        if let d = yyyyMMdd.date(from: s) {
            return d
        }
        if let d = ISO8601DateFormatter().date(from: s) {
            return d
        }
        return nil
    }

    func fetchCurrentGroupGoal() async throws -> GroupGoal {
        // 先從 Supabase Auth 拿當前使用者 email
        let session = try await client.auth.session
        let email = session.user.email ?? ""

        // 抓這個 email 參與的所有 group_goals
        let rows = try await repo.fetchGroupGoals(forEmail: email)

        guard let row = rows.first else {
            throw NSError(
                domain: "Social",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No group goals found"]
            )
        }

        let deadlineDate = Self.parseDate(row.deadline) ?? Date()
        let desc = row.description ?? ""

        // ⚠️ 目前 group_goals table 還沒有 target / current / unit 欄位
        // 先給一組 placeholder，未來你加欄位後再調整 mapping
        return GroupGoal(
            id: row.id,
            title: row.title,
            description: desc.isEmpty ? "No description yet." : desc,
            targetValue: 100,
            currentValue: 0,
            unit: "%",
            deadline: deadlineDate
        )
    }

    func fetchMembers() async throws -> [SocialMember] {
        let session = try await client.auth.session
        let myEmail = session.user.email ?? ""

        // 一樣先找這個人參與的 group_goals
        let rows = try await repo.fetchGroupGoals(forEmail: myEmail)
        guard let row = rows.first else {
            return []
        }

        // 再抓這個 group 的所有 participants
        let participants = try await repo.fetchParticipants(groupId: row.id)

        let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E2"]

        return participants.enumerated().map { index, p in
            let email = p.email
            let name = email.split(separator: "@").first.map(String.init) ?? email
            let color = colors[index % colors.count]
            let isMe = (email == myEmail)
            let progress = p.progress ?? 0

            return SocialMember(
                id: p.id,
                userId: p.user_id?.uuidString ?? "",
                displayName: name,
                avatarColorHex: color,
                procrastinationType: .unknown,          // 之後可從 user_profiles 接進來
                completedGroupTasks: Int(progress),     // 暫時用 progress 當假資料
                contributedValue: Int(progress),
                score: Int(progress),
                streakDays: 0,
                isCurrentUser: isMe
            )
        }
    }
}

// MARK: - Mock Repository（Preview / 假資料用）

final class MockSocialGroupRepository: SocialGroupRepository {
    func fetchCurrentGroupGoal() async throws -> GroupGoal {
        try await Task.sleep(nanoseconds: 500_000_000)

        return GroupGoal(
            id: UUID(),
            title: "本週共同目標：累積 600 分鐘專注時間",
            description: "大家一起努力，在下週五之前完成通識課的讀書心得報告",
            targetValue: 600,
            currentValue: 390,
            unit: "分鐘",
            deadline: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date()
        )
    }

    func fetchMembers() async throws -> [SocialMember] {
        try await Task.sleep(nanoseconds: 500_000_000)

        let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E2"]

        return [
            SocialMember(
                id: UUID(),
                userId: "user1",
                displayName: "小明",
                avatarColorHex: colors[0],
                procrastinationType: .unknown,
                completedGroupTasks: 12,
                contributedValue: 95,
                score: 120,
                streakDays: 5,
                isCurrentUser: true
            ),
            SocialMember(
                id: UUID(),
                userId: "user2",
                displayName: "小華",
                avatarColorHex: colors[1],
                procrastinationType: .unknown,
                completedGroupTasks: 15,
                contributedValue: 110,
                score: 150,
                streakDays: 7,
                isCurrentUser: false
            ),
            SocialMember(
                id: UUID(),
                userId: "user3",
                displayName: "小美",
                avatarColorHex: colors[2],
                procrastinationType: .unknown,
                completedGroupTasks: 8,
                contributedValue: 65,
                score: 80,
                streakDays: 3,
                isCurrentUser: false
            ),
            SocialMember(
                id: UUID(),
                userId: "user4",
                displayName: "小強",
                avatarColorHex: colors[3],
                procrastinationType: .unknown,
                completedGroupTasks: 10,
                contributedValue: 80,
                score: 100,
                streakDays: 4,
                isCurrentUser: false
            ),
            SocialMember(
                id: UUID(),
                userId: "user5",
                displayName: "小雯",
                avatarColorHex: colors[4],
                procrastinationType: .unknown,
                completedGroupTasks: 9,
                contributedValue: 70,
                score: 90,
                streakDays: 6,
                isCurrentUser: false
            ),
            SocialMember(
                id: UUID(),
                userId: "user6",
                displayName: "小傑",
                avatarColorHex: colors[5],
                procrastinationType: .unknown,
                completedGroupTasks: 6,
                contributedValue: 50,
                score: 60,
                streakDays: 2,
                isCurrentUser: false
            )
        ]
    }
}

// MARK: - Main View

struct SocialModeView: View {
    @EnvironmentObject var store: AppStore
    @State private var mode: SocialMode = .cooperation
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var groupGoal: GroupGoal?
    @State private var members: [SocialMember] = []

    private let repository: SocialGroupRepository

    // ✅ 正式執行用 SupabaseSocialGroupRepository
    init(repository: SocialGroupRepository = SupabaseSocialGroupRepository()) {
        self.repository = repository
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    contentView
                }
            }
            .navigationTitle("Social Boost")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadData()
            }
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Mode Picker
                Picker("模式", selection: $mode) {
                    ForEach(SocialMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Group Goal Card
                if let goal = groupGoal {
                    GroupGoalCard(goal: goal)
                        .padding(.horizontal)
                }

                // Mode Description
                modeDescriptionView
                    .padding(.horizontal)

                // Members List
                membersListView
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private var modeDescriptionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(modeDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }

    private var modeDescription: String {
        let baseText: String
        let typeAdjustment: String

        switch mode {
        case .cooperation:
            baseText = "這裡不排名，只看大家一共推了多少，慢慢一起把進度推上去。"
        case .competition:
            baseText = "完成社群任務會拿積分，本週誰會是第一名？（但也要記得照顧自己哦）"
        }

        let typeRaw = store.procrastinationType.rawValue

        if typeRaw.contains("完美") {
            typeAdjustment = "不用完美，一點點前進就很棒了。"
        } else if typeRaw.contains("死線") || typeRaw.contains("戰士") {
            typeAdjustment = "提前一點點動起來就好，不用等到最後一刻。"
        } else if typeRaw.contains("逃避") {
            typeAdjustment = "每次完成一小步，都是很大的進步。"
        } else if typeRaw.contains("決策") {
            typeAdjustment = "先從最簡單的開始，慢慢來。"
        } else {
            typeAdjustment = ""
        }

        return baseText + (typeAdjustment.isEmpty ? "" : "\n\n" + typeAdjustment)
    }

    private var membersListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(mode == .competition ? "排行榜" : "成員貢獻")
                .font(.headline)
                .padding(.horizontal, 4)

            if mode == .competition {
                competitionMembersList
            } else {
                cooperationMembersList
            }
        }
    }

    private var competitionMembersList: some View {
        let sortedMembers = members.sorted { $0.score > $1.score }

        return VStack(spacing: 8) {
            ForEach(Array(sortedMembers.enumerated()), id: \.element.id) { index, member in
                MemberRowCompetition(
                    member: member,
                    rank: index + 1
                )
            }
        }
    }

    private var cooperationMembersList: some View {
        VStack(spacing: 8) {
            ForEach(members) { member in
                MemberRowCooperation(member: member)
            }
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            async let goal = repository.fetchCurrentGroupGoal()
            async let membersData = repository.fetchMembers()

            let (fetchedGoal, fetchedMembers) = try await (goal, membersData)

            await MainActor.run {
                self.groupGoal = fetchedGoal
                self.members = fetchedMembers
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "暫時抓不到社群資料，可以晚點再試看看"
                self.isLoading = false
            }
        }
    }
}

// MARK: - Group Goal Card

struct GroupGoalCard: View {
    let goal: GroupGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(goal.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(goal.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("進度")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(goal.currentValue) / \(goal.targetValue) \(goal.unit)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 12)
                            .cornerRadius(6)

                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#FF6B6B"), Color(hex: "#FFA07A")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * goal.progress, height: 12)
                            .cornerRadius(6)
                    }
                }
                .frame(height: 12)

                HStack {
                    Text("\(Int(goal.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if goal.daysRemaining > 0 {
                        Text("剩下 \(goal.daysRemaining) 天")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("已到期")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#FFF5E6"),
                            Color(hex: "#FFE5CC")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Member Row (Cooperation)

struct MemberRowCooperation: View {
    let member: SocialMember

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: member.avatarColorHex))
                    .frame(width: 50, height: 50)

                Text(member.avatarInitial)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(member.displayName)
                        .font(.headline)

                    if member.isCurrentUser {
                        Text("You")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    Text(member.procrastinationTypeTag)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)

                    Text("連續 \(member.streakDays) 天")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(member.completedGroupTasks) 任務")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(member.contributedValue) 分鐘")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(member.isCurrentUser ? Color.blue.opacity(0.1) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(member.isCurrentUser ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Member Row (Competition)

struct MemberRowCompetition: View {
    let member: SocialMember
    let rank: Int

    private var rankIcon: String? {
        switch rank {
        case 1: return "trophy.fill"
        case 2: return "trophy.fill"
        case 3: return "trophy.fill"
        default: return nil
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "#FFD700")
        case 2: return Color(hex: "#C0C0C0")
        case 3: return Color(hex: "#CD7F32")
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            ZStack {
                if let icon = rankIcon {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(rankColor)
                } else {
                    Text("\(rank)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 40)

            // Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: member.avatarColorHex))
                    .frame(width: 50, height: 50)

                Text(member.avatarInitial)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(member.displayName)
                        .font(.headline)

                    if member.isCurrentUser {
                        Text("You")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }

                    Spacer()
                }

                Text(member.procrastinationTypeTag)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }

            Spacer()

            // Score
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(member.score) 分")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(rank <= 3 ? rankColor : .primary)

                Text("\(member.completedGroupTasks) 任務")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(member.isCurrentUser ? Color.blue.opacity(0.1) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(member.isCurrentUser ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    let store = AppStore()
    store.procrastinationType = .unknown

    return SocialModeView(repository: MockSocialGroupRepository())
        .environmentObject(store)
}
