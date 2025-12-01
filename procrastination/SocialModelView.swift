//  SocialModeView.swift

//
//  SocialModeView.swift
//

import SwiftUI
import Supabase

// MARK: - Models

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
    var completionRate: Double    // 0.0 ~ 1.0，合作模式用

    var avatarInitial: String {
        String(displayName.prefix(1)).uppercased()
    }

    var procrastinationTypeTag: String {
        let typeRaw = procrastinationType.rawValue

        if typeRaw.contains("完美") {
            return "完美"
        } else if typeRaw.contains("死線") || typeRaw.contains("戰士") {
            return "死線"
        } else {
            return "未知"
        }
    }
}

struct GroupGoal: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var description: String
    var targetValue: Int
    var currentValue: Int
    var unit: String
    var deadline: Date
    var socialModeRaw: String        // "cooperate" / "compete" 或 "cooperation" / "competition"
    
    // 合作 / 競爭模式判斷（兼容兩種字串）
    var isCooperation: Bool {
        let v = socialModeRaw.lowercased()
        return v == "cooperate" || v == "cooperation"
    }
    
    var isCompetition: Bool {
        let v = socialModeRaw.lowercased()
        return v == "compete" || v == "competition"
    }
    
    // 進度 0~1
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(Double(currentValue) / Double(targetValue), 1.0)
    }
    
    // 剩餘天數：以「日期」計，不吃小時
    var daysRemaining: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDeadline = calendar.startOfDay(for: deadline)
        let comps = calendar.dateComponents([.day], from: startOfToday, to: startOfDeadline)
        return max(0, comps.day ?? 0)
    }
    
    /// ✅ 判斷是否已結束：deadline 在今天之前的才算結束
    /// ✅ 判斷是否已結束：deadline 在今天「或之前」都算結束
    var isFinished: Bool {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDeadline = calendar.startOfDay(for: deadline)
        return startOfDeadline <= startOfToday
    }
}
    // MARK: - Supabase Repository（正式用）

    final class SupabaseSocialGroupRepository {
        private let repo = SupabaseRepository.shared
        private let client = SupabaseManager.shared.client
        
        // 解析 yyyy-MM-dd 或 ISO8601
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
        
        /// 抓「目前使用者參與的所有 group_goals」，並順便把 progress 算好（用成員完成率平均）
        func fetchGroupGoalsForCurrentUser() async throws -> (goals: [GroupGoal], membersByGroup: [UUID: [SocialMember]]) {
            
            // 1. 取得目前使用者 email
            let session = try await client.auth.session
            let myEmail = (session.user.email ?? "").lowercased()
            
            // 2. 抓這個 email 參與的所有 group_goals
            let rows = try await repo.fetchGroupGoals(forEmail: myEmail)
            
            // 3. 逐個 group 抓參與者，算出平均完成率，更新 currentValue
            var resultGoals: [GroupGoal] = []
            var membersDict: [UUID: [SocialMember]] = [:]
            
            let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A", "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E2"]
            
            for row in rows {
                let deadlineDate = Self.parseDate(row.deadline) ?? Date()
                let desc = row.description ?? ""
                let mode = row.social_mode      // ✅ 不要再用 ??，它是非 optional
                
                // 先做一個基本 GroupGoal，等一下再用成員 completionRate 補上 currentValue
                var goal = GroupGoal(
                    id: row.id,
                    title: row.title,
                    description: desc.isEmpty ? "No description yet." : desc,
                    targetValue: 100,      // 先固定 100，代表百分比
                    currentValue: 0,       // 之後會用平均完成率 * 100 填
                    unit: "%",
                    deadline: deadlineDate,
                    socialModeRaw: mode
                )
                
                // 抓這個 group 的成員
                let participants = try await repo.fetchParticipants(groupId: row.id)
                
                let members: [SocialMember] = participants.enumerated().map { index, p in
                    let email = p.email.lowercased()
                    let name = p.email.split(separator: "@").first.map(String.init) ?? p.email
                    let color = colors[index % colors.count]
                    let isMe = (email == myEmail)
                    
                    let raw = p.progress ?? 0.0
                    
                    // ✅ 向下相容：
                    // 如果 >1，當成舊的「分數 0~1000」
                    // 如果 ≤1，當成新的「比例 0~1」
                    let completionRate: Double
                    let score: Int
                    
                    if raw > 1 {
                        score = Int(raw)
                        completionRate = min(max(raw / 1000.0, 0), 1)  // 142 -> 0.142
                    } else {
                        completionRate = min(max(raw, 0), 1)
                        score = Int(completionRate * 1000)
                    }
                    
                    return SocialMember(
                        id: p.id,
                        userId: p.user_id?.uuidString ?? "",
                        displayName: name,
                        avatarColorHex: color,
                        procrastinationType: .unknown,
                        completedGroupTasks: 0,
                        contributedValue: 0,
                        score: score,
                        streakDays: 0,
                        isCurrentUser: isMe,
                        completionRate: completionRate
                    )
                }
                
                membersDict[row.id] = members
                
                // 用完成率平均，更新 group 的 currentValue
                if !members.isEmpty {
                    let avg = members.reduce(0.0) { $0 + $1.completionRate } / Double(members.count)
                    goal.currentValue = Int(avg * 100)
                }
                
                resultGoals.append(goal)
            }
            
            return (resultGoals, membersDict)
        }
    }

    // MARK: - Mock Repository（Preview 用）
    
    final class MockSocialGroupRepository {
        func sampleData() -> (goals: [GroupGoal], membersByGroup: [UUID: [SocialMember]]) {
            let colors = ["#FF6B6B", "#4ECDC4", "#45B7D1", "#FFA07A", "#98D8C8", "#F7DC6F"]
            
            let coopId = UUID()
            let compId = UUID()
            
            let coopGoal = GroupGoal(
                id: coopId,
                title: "一起讀完 3 章教科書",
                description: "這週大家一起把總體經濟學第 10–12 章讀完。",
                targetValue: 100,
                currentValue: 60,
                unit: "%",
                deadline: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
                socialModeRaw: "cooperate"
            )
            
            let compGoal = GroupGoal(
                id: compId,
                title: "專注挑戰賽",
                description: "這週看誰專注時間最長。",
                targetValue: 100,
                currentValue: 30,
                unit: "%",
                deadline: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
                socialModeRaw: "compete"
            )
            
            let coopMembers = [
                SocialMember(
                    id: UUID(),
                    userId: "u1",
                    displayName: "iris",
                    avatarColorHex: colors[0],
                    procrastinationType: .unknown,
                    completedGroupTasks: 0,
                    contributedValue: 0,
                    score: 600,
                    streakDays: 3,
                    isCurrentUser: true,
                    completionRate: 0.6
                ),
                SocialMember(
                    id: UUID(),
                    userId: "u2",
                    displayName: "ander",
                    avatarColorHex: colors[1],
                    procrastinationType: .unknown,
                    completedGroupTasks: 0,
                    contributedValue: 0,
                    score: 500,
                    streakDays: 2,
                    isCurrentUser: false,
                    completionRate: 0.5
                )
            ]
            
            let compMembers = [
                SocialMember(
                    id: UUID(),
                    userId: "u3",
                    displayName: "iris",
                    avatarColorHex: colors[2],
                    procrastinationType: .unknown,
                    completedGroupTasks: 0,
                    contributedValue: 0,
                    score: 800,
                    streakDays: 4,
                    isCurrentUser: true,
                    completionRate: 0.8
                ),
                SocialMember(
                    id: UUID(),
                    userId: "u4",
                    displayName: "ander",
                    avatarColorHex: colors[3],
                    procrastinationType: .unknown,
                    completedGroupTasks: 0,
                    contributedValue: 0,
                    score: 650,
                    streakDays: 3,
                    isCurrentUser: false,
                    completionRate: 0.65
                )
            ]
            
            return (
                [coopGoal, compGoal],
                [coopId: coopMembers, compId: compMembers]
            )
        }
    }
    
    // MARK: - 主畫面：社群模式列表 + 模式切換
    
    struct SocialModeView: View {
        @EnvironmentObject var store: AppStore
        
        @State private var mode: SocialMode = .cooperation
        @State private var isLoading = false
        @State private var errorMessage: String?
        @State private var groupGoals: [GroupGoal] = []
        @State private var membersByGroup: [UUID: [SocialMember]] = [:]
        
        private let repository = SupabaseSocialGroupRepository()
        
        // 依照目前模式（合作 / 競爭）篩選 group goals
        private var filteredGoals: [GroupGoal] {
            switch mode {
            case .cooperation:
                return groupGoals.filter { $0.isCooperation }
            case .competition:
                return groupGoals.filter { $0.isCompetition }
            }
        }
        
        var body: some View {
            NavigationStack {
                ZStack {
                    if isLoading {
                        ProgressView().scaleEffect(1.5)
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
                    
                    // 模式切換：合作 / 競爭（只影響「顯示哪一些 group」）
                    Picker("模式", selection: $mode) {
                        ForEach(SocialMode.allCases) { m in
                            Text(m.displayName).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if filteredGoals.isEmpty {
                        Text("這個模式目前還沒有群組目標，可以先建立一個試試看 👀")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        VStack(spacing: 16) {
                            ForEach(filteredGoals) { goal in
                                NavigationLink {
                                    GroupDetailView(groupGoal: goal)
                                } label: {
                                    GroupGoalCard(goal: goal)
                                }
                                
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        
        private func loadData() async {
            isLoading = true
            errorMessage = nil
            
            do {
                let result = try await repository.fetchGroupGoalsForCurrentUser()
                await MainActor.run {
                    self.groupGoals = result.goals
                    self.membersByGroup = result.membersByGroup
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
    // MARK: - Group Goal Card（合作模式）
    
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
    
    // MARK: - Competition Summary Card（競爭模式）
    
    struct CompetitionSummaryCard: View {
        let goal: GroupGoal
        let members: [SocialMember]
        
        // 依分數高到低排序
        private var sortedMembers: [SocialMember] {
            members.sorted { $0.score > $1.score }
        }
        
        // 找出自己 & 名次
        private var me: (member: SocialMember, rank: Int)? {
            guard let idx = sortedMembers.firstIndex(where: { $0.isCurrentUser }) else {
                return nil
            }
            return (sortedMembers[idx], idx + 1)
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // 標題：目標名稱
                Text(goal.title)
                    .font(.title3.bold())
                
                // 自己的名次 & 分數
                if let me {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("目前第 \(me.rank) 名")
                            .font(.headline)
                        
                        Text("·")
                            .foregroundColor(.secondary)
                        
                        Text("\(me.member.score) 分")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let first = sortedMembers.first, first.id != me.member.id {
                        let diff = max(0, first.score - me.member.score)
                        Text("距離第一名還差 \(diff) 分")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("你現在就是第一名！🔥")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                } else {
                    Text("加入挑戰後就會顯示你的名次 👀")
                        .font(.subheadline)
                }
                
                // Deadline / 剩餘天數
                HStack {
                    if goal.daysRemaining > 0 {
                        Text("剩下 \(goal.daysRemaining) 天")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("本輪挑戰已結束")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#E0F2FE"),    // 淺藍
                                Color(hex: "#DBEAFE")     // 再淺一點藍
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
        }
    }
    
    // MARK: - Member Row（合作）
    
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
//                    Text("完成 \(Int(member.completionRate * 100))%")
//                        .font(.subheadline)
//                        .fontWeight(.semibold)
//                        .foregroundColor(.primary)
                    
                    Text("一起慢慢推進 ✨")
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
    
    // MARK: - Member Row（競爭）
    
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
                    
//                    Text(member.procrastinationTypeTag)
//                        .font(.caption)
//                        .padding(.horizontal, 6)
//                        .padding(.vertical, 2)
//                        .background(Color(.systemGray5))
//                        .cornerRadius(4)
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
        
        let mock = MockSocialGroupRepository().sampleData()
        
        return NavigationStack {
            SocialModeView()
                .environmentObject(store)
        }
    }

