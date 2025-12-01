//
//  GroupDetailView.swift
//
import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject var store: AppStore

    let groupGoal: GroupGoal

    //@State private var mode: SocialMode = .cooperation
    @State private var isLoading = false
    @State private var members: [SocialMember] = []
    private var mode: SocialMode {
          groupGoal.isCooperation ? .cooperation : .competition
      }

    private let repo = SupabaseRepository.shared

    private var localGoal: Goal? {
        store.goals.first { $0.groupId == groupGoal.id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ✅ 直接依 groupGoal 的模式決定要顯示哪一種卡片
                if mode == .cooperation {
                    GroupGoalCard(goal: groupGoal)
                } else {
                    CompetitionSummaryCard(
                        goal: groupGoal,
                        members: members
                    )
                }

                if let lg = localGoal, lg.subTasks.isEmpty {
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
                    .padding(.horizontal)
                }

                // Member List
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
        .task { await loadMembers() }
    }


    private func loadMembers() async {
        isLoading = true
        do {
            members = try await repo.fetchMembers(forGroupId: groupGoal.id)
            isLoading = false
        } catch {
            isLoading = false
        }
    }
}

