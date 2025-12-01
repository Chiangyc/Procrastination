//
//  Questionnaire.swift
//  procrastination
//
//  Created by Iris Tsou on 2025/10/17.
//

import SwiftUI

struct OnboardingQuestionsView: View {
    @EnvironmentObject var store: AppStore
    @State private var step: Int = 0   // 0: 第一頁, 1: 第二頁
    @State private var showTieBreaker = false

    var body: some View {
        VStack(spacing: 16) {
            // 進度條
            ProgressView(value: step == 0 ? 0.5 : 1.0)
                .progressViewStyle(.linear)
                .tint(.blue)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Personalise your\npreference")
                    .font(.largeTitle.bold())
                    .lineSpacing(2)
                Text("Choose what kind of people you are.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 16) {
                    if step == 0 {
                        // 第一頁：（一）動機面、（二）情緒面
                        QuestionCard(
                            index: 1,
                            text: "我通常想等自己「準備得更好」再開始做事情",
                            value: $store.onboarding.perfectionismPrep
                        )
                        QuestionCard(
                            index: 2,
                            text: "我常覺得「要給我施加壓力，我才能進入狀態」",
                            value: $store.onboarding.pressureNeed
                        )
                        QuestionCard(
                            index: 3,
                            text: "當我想到要開始一件重要的事時，會感到焦慮或害怕",
                            value: $store.onboarding.anxietyStart
                        )
                        QuestionCard(
                            index: 4,
                            text: "若沒有時間壓力，我通常提不起勁行動",
                            value: $store.onboarding.noPressureIdle
                        )
                    } else {
                        // 第二頁：（三）行為面、（四）自我觀察
                        QuestionCard(
                            index: 5,
                            text: "我會一直查資料、準備、修正，但很難真正開始",
                            value: $store.onboarding.researchLoop
                        )
                        QuestionCard(
                            index: 6,
                            text: "我常拖到最後一天才動手，但仍能在期限內完成",
                            value: $store.onboarding.lastMinute
                        )
                        QuestionCard(
                            index: 7,
                            text: "當我沒達到自己預期的標準時，會很沮喪或自責",
                            value: $store.onboarding.selfBlame
                        )
                        QuestionCard(
                            index: 8,
                            text: "若沒有外在壓力或他人督促，我就很難集中注意力",
                            value: $store.onboarding.needExternalPressure
                        )
                    }
                }
                .padding(.vertical, 8)
            }

            // 底部按鈕
            if step == 0 {
                Button("Next") {
                    step = 1
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.bottom, 12)
            } else {
                HStack(spacing: 12) {
                    Button {
                        // 回到上一頁
                        step = 0
                    } label: {
                        Text("Back")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemBackground))
                            .foregroundStyle(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button {
                        let ob = store.onboarding
                        
                        // a = 完美主義者
                        let scoreA = ob.perfectionismPrep + ob.anxietyStart + ob.researchLoop + ob.selfBlame

                        // b = 死線戰士
                        let scoreB = ob.pressureNeed + ob.lastMinute + ob.needExternalPressure + ob.noPressureIdle

                        if scoreA > scoreB {
                            store.procrastinationType = .perfectionist
                            completeOnboarding()
                        } else if scoreB > scoreA {
                            store.procrastinationType = .deadlineFighter
                            completeOnboarding()
                        } else {
                            // a == b，顯示平手題
                            showTieBreaker = true
                        }
                    } label: {
                        Text("Submit")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showTieBreaker) {
                TieBreakerView(
                    onSelectPerfectionist: {
                        store.procrastinationType = .perfectionist
                        completeOnboarding()
                        showTieBreaker = false
                    },
                    onSelectDeadlineFighter: {
                        store.procrastinationType = .deadlineFighter
                        completeOnboarding()
                        showTieBreaker = false
                    }
                )
                .presentationDetents([.medium]) // 讓它只佔一半
                .presentationDragIndicator(.visible)
        }
        .background(Color(uiColor: .systemBackground))
    }
    
    private func completeOnboarding() {
        store.hasOnboarded = true
        store.saveProfileToCloud()

        // 🚀 將最新問卷結果上傳到 Supabase
        Task {
            do {
                try await SupabaseRepository.shared.upsertUserProfile(from: store)
                print("✅ Uploaded updated onboarding profile to Supabase")
            } catch {
                print("❌ Failed to upload onboarding profile:", error)
            }
        }

        // App 會自動因為 hasOnboarded 變為 true 而切換到 ContentView
    }

}

struct TieBreakerView: View {
    var onSelectPerfectionist: () -> Void
    var onSelectDeadlineFighter: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("最後一個問題！")
                .font(.largeTitle.bold())

            Text("當你面對任務時，你通常是因為擔心結果不完美而拖延，還是因為沒有壓力就提不起勁開始？")
                .font(.title3)
                .lineSpacing(6)
                .padding(.bottom)

            Button(action: onSelectPerfectionist) {
                Text("擔心結果不完美")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button(action: onSelectDeadlineFighter) {
                Text("沒有壓力提不起勁")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Spacer()
        }
        .padding(30)
    }
}


struct QuestionCard: View {
    let index: Int
    let text: LocalizedStringKey
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(index).")
                    .font(.title3).bold()
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 0..5 的底線，可改成 1..5（下面滑桿是 1..5）
            HStack {
                Text("1").foregroundStyle(.secondary)
                Spacer()
                Text("5").foregroundStyle(.secondary)
            }
            .font(.caption)

            // 滑桿（1..5，步進 1）
            VStack(alignment: .leading, spacing: 8) {
                Slider(value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0.rounded()) }
                ), in: 1...5, step: 1)
                Text("\(value)")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.black.opacity(0.06)))
    }
}
