// SupabaseSyncService.swift
import Foundation

final class SupabaseSyncService {
    static let shared = SupabaseSyncService()
    let repo = SupabaseRepository.shared


    // 啟動用：確保 user 存在，拉雲端 → 回填到本地 Store
    func syncDownInto(store: AppStore) async {
        await repo.ensureUserRowExistsIfNeeded()

        do {
            let goals = try await repo.fetchGoals()
            var mergedGoals: [Goal] = []
            for g in goals {
                let tasks = try await repo.fetchTasks(goalId: g.id)
                var ng = g
                ng.subTasks = tasks
                mergedGoals.append(ng)
            }

            let moods = try await repo.fetchMoods()

            // 回寫到 store（不再存本地 JSON）
            await MainActor.run {
                store.goals = mergedGoals
                store.moods = moods
            }

        } catch {
            print("⚠️ syncDown failed:", error)
        }
    }


    // 單筆上傳（新增 Goal 時呼叫）
    func pushGoal(_ g: Goal) async {
        do { try await repo.upsertGoal(g) } catch { print("⚠️ pushGoal failed:", error) }
    }

    // 單筆上傳（新增 Mood 時呼叫）
    func pushMood(_ m: MoodRecord) async {
        do { try await repo.upsertMood(m) } catch { print("⚠️ pushMood failed:", error) }
    }
}
//
//  SupabaseSyncService.swift
//  procrastination
//
//  Created by 江怡臻 on 2025/11/5.
//

