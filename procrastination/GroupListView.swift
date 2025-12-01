//  GroupListView.swift
import SwiftUI
import Supabase

/// 簡單的日期字串轉 Date，小工具
private func parseDateFromBackend(_ s: String?) -> Date {
    guard let s, !s.isEmpty else { return Date() }

    let df = DateFormatter()
    df.calendar = Calendar(identifier: .gregorian)
    df.locale = Locale(identifier: "en_US_POSIX")
    df.timeZone = TimeZone(secondsFromGMT: 0)
    df.dateFormat = "yyyy-MM-dd"
    if let d = df.date(from: s) { return d }

    if let d = ISO8601DateFormatter().date(from: s) {
        return d
    }

    return Date()
}

enum GroupStatusFilter: String, CaseIterable, Identifiable {
    case ongoing
    case finished

    var id: Self { self }

    var title: String {
        switch self {
        case .ongoing: return "進行中"
        case .finished: return "已結束"
        }
    }
}

struct GroupListView: View {
    @EnvironmentObject var store: AppStore

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var groupGoals: [GroupGoal] = []
    @State private var statusFilter: GroupStatusFilter = .ongoing
    @State private var membersByGroup: [UUID: [SocialMember]] = [:]   // 🆕 每個 group 的成員

    // ❗️改成用我們專門的 Social repository
    private let socialRepo = SupabaseSocialGroupRepository()
    
    // ---- 過濾邏輯 ----

    /// 依目前 Segmented（進行中 / 已結束）先挑出一批目標
    private var goalsByStatus: [GroupGoal] {
        switch statusFilter {
        case .ongoing:
            return groupGoals.filter { !$0.isFinished }
        case .finished:
            return groupGoals.filter { $0.isFinished }
        }
    }

    /// 在「這個狀態」底下的合作模式
    private var coopGoals: [GroupGoal] {
        goalsByStatus.filter { $0.isCooperation }
    }

    /// 在「這個狀態」底下的競爭模式
    private var compGoals: [GroupGoal] {
        goalsByStatus.filter { $0.isCompetition }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView().scaleEffect(1.3)
                } else if let err = errorMessage {
                    Text(err)
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    if groupGoals.isEmpty {
                        Text("目前還沒有任何社群目標，可以先建立一個試試看！")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ScrollView {
                            VStack(spacing: 24) {

                                // ✅ 上面：進行中 / 已結束 切換
                                Picker("狀態", selection: $statusFilter) {
                                    ForEach(GroupStatusFilter.allCases) { s in
                                        Text(LocalizedStringKey(s.title)).tag(s)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal)

                                // ✅ 合作模式區塊
                                if !coopGoals.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("合作模式")
                                            .font(.headline)
                                            .padding(.horizontal)

                                        ForEach(coopGoals) { goal in
                                            NavigationLink {
                                                GroupDetailView(groupGoal: goal)
                                            } label: {
                                                GroupGoalCard(goal: goal)   // 橘色卡片
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                }

                                // ✅ 競爭模式區塊
                                if !compGoals.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("競爭模式")
                                            .font(.headline)
                                            .padding(.horizontal)

                                        ForEach(compGoals) { goal in
                                            NavigationLink {
                                                GroupDetailView(groupGoal: goal)
                                            } label: {
                                                // 🆕 用藍色的競爭卡片，帶入該 group 的成員
                                                CompetitionSummaryCard(
                                                    goal: goal,
                                                    members: membersByGroup[goal.id] ?? []
                                                )
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                }

                                // ✅ 這個狀態底下，合作＋競爭都沒有
                                if coopGoals.isEmpty && compGoals.isEmpty {
                                    Text("這個狀態目前沒有任何目標 👀")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding()
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                }
            }
            .navigationTitle("Social Boost")
            .task {
                await loadGroups()
            }
        }
    }

    private func loadGroups() async {
        isLoading = true
        errorMessage = nil
        do {
            // 🆕 使用 SupabaseSocialGroupRepository 抓「已算好 progress + members」的資料
            let result = try await socialRepo.fetchGroupGoalsForCurrentUser()

            await MainActor.run {
                self.groupGoals = result.goals
                self.membersByGroup = result.membersByGroup
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "暫時無法取得群組資料"
                self.isLoading = false
            }
        }
    }
}
