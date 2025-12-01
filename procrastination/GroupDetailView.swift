import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject var store: AppStore

    let groupGoal: GroupGoal

    @State private var isLoading = false
    @State private var members: [SocialMember] = []

    // 🔐 防止按多次（本次進入畫面的 state）
    @State private var hasStartedBreakdown = false

    private var mode: SocialMode {
        groupGoal.isCooperation ? .cooperation : .competition
    }

    private let repo = SupabaseRepository.shared

    private var localGoal: Goal? {
        store.goals.first { $0.groupId == groupGoal.id }
    }

    /// ⭐ 確保每一位組員登入後也能看到拆解按鈕（建立 localGoal）
    private func ensureLocalGoalExists() {
        if localGoal != nil { return }

        let newGoal = Goal(
            id: UUID(),
            title: groupGoal.title,
            icon: "person.3.fill",
            colorHex: "#FFE5CC",
            startDate: Date(),
            deadline: groupGoal.deadline,
            reminders: [],
            subTasks: [],
            createdAt: Date(),
            isGroupGoal: true,
            groupId: groupGoal.id
        )

        store.goals.append(newGoal)
    }

    /// ✅ 是否顯示「開始拆解任務」按鈕
    private var shouldShowBreakdownButton: Bool {
        guard let lg = localGoal else { return false }
        return lg.subTasks.isEmpty && !hasStartedBreakdown
    }

    // MARK: - BODY
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // 顯示合作/競爭卡片
                if mode == .cooperation {
                    GroupGoalCard(goal: groupGoal)
                } else {
                    CompetitionSummaryCard(
                        goal: groupGoal,
                        members: members
                    )
                }

                // 拆解按鈕（只顯示一次）
                if shouldShowBreakdownButton, let lg = localGoal {
                    NavigationLink {
                        BreakDownGoalView(
                            initialGoalID: lg.id,
                            initialUserMessage: "Please break down: \(groupGoal.title)"
                        )
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("開始拆解任務")
                        }
                        .font(.subheadline.bold())
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    // ⬅️ 點下去的當下，把 state 設成 true → 回來後按鈕就不見
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            hasStartedBreakdown = true
                        }
                    )
                    .padding(.horizontal)
                }

                // 成員列表
                VStack(alignment: .leading, spacing: 12) {
                    Text(mode == .cooperation ? "成員進度" : "排行榜")
                        .font(.headline)

                    if mode == .cooperation {
                        ForEach(members) { m in
                            MemberRowCooperation(member: m)
                        }
                    } else {
                        let sorted = members.sorted { $0.score > $1.score }
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, m in
                            MemberRowCompetition(member: m, rank: index + 1)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
        .navigationTitle(groupGoal.title)

        // ⭐ 載入成員
        .task { await loadMembers() }

        // ⭐ 第一次進來建立 localGoal
        .onAppear {
            ensureLocalGoalExists()
        }
    }

    // MARK: - Members
    private func loadMembers() async {
        isLoading = true
        do {
            members = try await repo.fetchMembers(forGroupId: groupGoal.id)
        } catch {
            print("fetchMembers error:", error)
        }
        isLoading = false
    }
}
