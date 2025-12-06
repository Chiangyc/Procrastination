//
//  BreakDownGoalView.swift
//  procrastination
//
//  Created by Iris Tsou on 2025/10/25.
//

import SwiftUI
import MarkdownUI

// MARK: - BreakDownGoalView

struct BreakDownGoalView: View {
    // MARK: Properties
    @Environment(GeminiService.self) private var geminiService
    @EnvironmentObject var store: AppStore

    /// 可選：從建立目標頁帶入，用於自動觸發第一次請求
    var initialGoalID: UUID? = nil
    var initialUserMessage: String? = nil

    // 對話串管理
    @State private var activeThreadID: UUID? = nil
    @State private var showThreadPicker = false
    @State private var hasAutoTriggered = false

    // 輸入與狀態管理
    @State private var input = ""
    @State private var isGenerating = false // AI 是否正在回應

    private let suggestions: [Suggestion] = [
        .init(title: "Will the tasks too hard for you?",
              subtitle: "AI can help you customize your own plan"),
        .init(title: "Tell me the part you want to modify",
              subtitle: "Estimated time, details of the tasks")
    ]

    // MARK: Computed Properties

    /// 只取「非日記」threads
    private var nonJournalThreads: [ChatThread] {
        store.conversations.filter {$0.isJournal != true}
    }

    /// 目前活躍對話的 index
    private var activeIndex: Int {
        guard let id = activeThreadID,
              let idx = nonJournalThreads.firstIndex(where: { $0.id == id }) else {
            return nonJournalThreads.isEmpty ? -1 : 0
        }
        return idx
    }

    /// 目前活躍對話
    private var active: ChatThread? {
        guard activeIndex != -1, nonJournalThreads.indices.contains(activeIndex) else { return nil }
        return nonJournalThreads[activeIndex]
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ===== 訊息列表 =====
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if let messages = active?.messages {
                                ForEach(messages) { msg in
                                    MessageRow(msg: msg)
                                        .id(msg.id)
                                }
                            } else {
                                Text("Select or start a conversation.")
                                    .padding()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 6)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .onChange(of: active?.messages.count) { _ in
                        withAnimation {
                            if let lastID = active?.messages.last?.id {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }

                // ===== 建議卡 + 輸入列 =====
                bottomComposer
            }
            .navigationTitle("Break Down the Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showThreadPicker = true
                    } label: {
                        Image(systemName: "ellipsis.bubble")
                            .font(.title3)
                            .foregroundColor(Color.themeBlue)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color(.white)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Switch conversation")
                }
            }
            // 會話選擇器：只顯示「非日記」threads
            .sheet(isPresented: $showThreadPicker) {
                ConversationPickerSheet(activeThreadID: $activeThreadID)
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
            }
            .onAppear {
                configureActiveThreadOnAppear()
            }
        }
    }

    // MARK: - Bottom Composer

    private var bottomComposer: some View {
        VStack(spacing: 12) {
            // 建議卡
            GeometryReader { geo in
                let cardW = geo.size.width * 0.82
                ScrollView(.horizontal) {
                    HStack(spacing: 16) {
                        ForEach(suggestions) { s in
                            SuggestionCard(s, width: cardW) {
                                input = s.title
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .contentMargins(.horizontal, 16)
                .scrollIndicators(.hidden)
            }
            .frame(height: 128)

            // 輸入列
            HStack(spacing: 10) {
                TextField("Ask me anything…", text: $input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.send)
                    .onSubmit { send() }   // Enter（完成選字）即送出

                if isGenerating {
                    ProgressView()
                        .frame(width: 42, height: 42)
                } else {
                    Button(action: send) {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Color.accentColor))
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Lifecycle helpers

    private func configureActiveThreadOnAppear() {
        // 如果帶了目標 ID，優先用「與此目標綁定」的對話
        if let gid = initialGoalID {
            if let existing = store.conversations.first(where: { $0.relatedGoalID == gid }) {
                activeThreadID = existing.id
            } else if let g = store.goals.first(where: { $0.id == gid }) {
                // 為此目標建立一條新的對話，名稱 = 目標標題
                let t = ChatThread(
                    title: g.title,
                    messages: [
                        .init(role: .assistant,
                              text: "Hi! Tell me more about **\(g.title)** and I’ll break it down for you. ✨")
                    ],
                    relatedGoalID: g.id
                )
                store.upsertThread(t)
                activeThreadID = t.id

                // 立刻上傳到雲端（對話 + 第一則訊息）
                Task {
                    try? await SupabaseRepository.shared.upsertConversation(t)
                    if let first = t.messages.first {
                        try? await SupabaseRepository.shared.upsertMessage(first, conversationId: t.id)
                    }
                }
            }
        } else {
            // 沒帶目標 ID 的情況：用第一條「非日記」對話（如果有）
            if activeThreadID == nil {
                activeThreadID = store.conversations
                    .filter { $0.isJournal != true }
                    .first?.id
            }
        }

        // 自動送出第一則（若有帶參數）
        if hasAutoTriggered == false,
           let goalID = initialGoalID,
           let message = initialUserMessage {
            hasAutoTriggered = true
            autoSendInitial(goalID: goalID, message: message)
        }
    }

    // MARK: - Auto first message

    private func autoSendInitial(goalID: UUID, message: String) {
        appendMessage(role: .user, text: message)
        isGenerating = true

        Task {
            defer { isGenerating = false }

            guard let goal = store.goals.first(where: { $0.id == goalID }) else {
                appendMessage(role: .assistant, text: "Error: Could not find the goal to work on.")
                return
            }
            do {
                // enum → 字串 DTO（提供給 Gemini）
                let prefDTO = PreferenceDTO(
                    arrangeStrategy: store.preferences.arrangeStrategy.rawValue,
                    weekdayWeekend: store.preferences.weekdayWeekend.rawValue,
                    focusSpan: store.preferences.focusSpan.rawValue,
                    longTask: store.preferences.longTask.rawValue
                )

                let response = try await geminiService.breakDownGoal(
                    goalTitle: goal.title,
                    description: message,
                    preferences: prefDTO,
                    onboarding: store.onboarding,
                    workstyle: store.workstyle,
                    type: store.procrastinationType,
                    deadline: goal.deadline,
                    language: store.language.rawValue
                )

                let subTasks = response.tasks
                let chatReply = response.chatReply

                if let goalIndex = store.goals.firstIndex(where: { $0.id == goal.id }) {
                    // 寫入本機（Goal 子任務）
                    store.goals[goalIndex].subTasks = subTasks
                    store.saveProfileToCloud()

                    // 把剛產生的任務推上 Supabase
                    for t in subTasks {
                        Task { try? await SupabaseRepository.shared.upsertTask(t, goalId: goal.id) }
                    }

                    // 顯示 AI 的回覆
                    appendMessage(role: .assistant, text: chatReply)
                }
            } catch {
                appendMessage(role: .assistant, text: "I'm sorry, I had trouble breaking down your goal. Please check your network and try again. Error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Manual send

    private func send() {
        guard !isGenerating else { return }

        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        appendMessage(role: .user, text: text)
        let userInput = input
        input = ""
        isGenerating = true

        Task {
            defer { isGenerating = false }

            // 這裡選擇最後一個 goal 作為上下文（你也可以改成與 activeThread 相關的 goal）
            guard let goal = store.goals.last else {
                appendMessage(role: .assistant, text: "Error: Could not find the goal to work on.")
                return
            }

            do {
                // enum → 字串 DTO（提供給 Gemini）
                let prefDTO = PreferenceDTO(
                    arrangeStrategy: store.preferences.arrangeStrategy.rawValue,
                    weekdayWeekend: store.preferences.weekdayWeekend.rawValue,
                    focusSpan: store.preferences.focusSpan.rawValue,
                    longTask: store.preferences.longTask.rawValue
                )

                let response = try await geminiService.breakDownGoal(
                    goalTitle: goal.title,
                    description: userInput,
                    preferences: prefDTO,
                    onboarding: store.onboarding,
                    workstyle: store.workstyle,
                    type: store.procrastinationType,
                    deadline: goal.deadline,
                    language: store.language.rawValue
                )

                let subTasks = response.tasks
                let chatReply = response.chatReply

                if let goalIndex = store.goals.firstIndex(where: { $0.id == goal.id }) {
                    // 寫入本機（Goal 子任務）
                    store.goals[goalIndex].subTasks = subTasks
                    store.saveProfileToCloud()

                    // 任務推上雲端
                    for t in subTasks {
                        Task { try? await SupabaseRepository.shared.upsertTask(t, goalId: goal.id) }
                    }

                    // 顯示 AI 的回覆
                    appendMessage(role: .assistant, text: chatReply)
                }
            } catch {
                appendMessage(role: .assistant, text: "I'm sorry, I had trouble breaking down your goal. Please check your network and try again. Error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 儲存 + 上傳雲端

    private func appendMessage(role: ChatMessage.Role, text: String) {
        guard var t = active else { return }

        // 1) 本地新增訊息
        t.messages.append(.init(role: role, text: text))
        t.lastUpdated = Date()
        store.upsertThread(t)  // 存回 AppStore 並寫入 JSON

        // 2) 雲端同步（上傳對話與最新訊息）
        Task {
            do {
                try await SupabaseRepository.shared.upsertConversation(t)
                if let last = t.messages.last {
                    try await SupabaseRepository.shared.upsertMessage(last, conversationId: t.id)
                }
            } catch {
                print("❌ 上傳訊息失敗:", error)
            }
        }
    }
}

// MARK: - Conversation Picker（只顯示非日記）

private struct ConversationPickerSheet: View {
    @EnvironmentObject var store: AppStore
    @Binding var activeThreadID: UUID?
    @Environment(\.dismiss) private var dismiss

    private var nonJournalThreads: [ChatThread] {
        store.conversations
            .filter { $0.isJournal != true }
            .sorted(by: { $0.lastUpdated > $1.lastUpdated })
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(nonJournalThreads) { t in
                    Button {
                        activeThreadID = t.id
                        dismiss()
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .foregroundStyle(Color.themeBlue)
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t.title).bold()
                                    .foregroundStyle(.black)
                                Text(t.messages.last?.text ?? "No messages yet")
                                    .lineLimit(2)
                                    .foregroundStyle(.black.opacity(0.6))
                                    .font(.caption)
                            }
                            Spacer()
                            if activeThreadID == t.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
                .onDelete { idx in
                    let toDelete = idx.map { nonJournalThreads[$0].id }
                    var storeOffsets = IndexSet()
                    for id in toDelete {
                        if let i = store.conversations.firstIndex(where: { $0.id == id }) {
                            storeOffsets.insert(i)
                        }
                    }
                    store.deleteThreads(at: storeOffsets)

                    let stillValid = store.conversations.contains(where: { $0.id == activeThreadID })
                    if !stillValid {
                        activeThreadID = store.conversations.first(where: { $0.id != Constants.journalThreadID })?.id
                    }
                }
            }
            .navigationTitle("Conversations")
            .tint(.black)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let new = ChatThread(title: "New chat", messages: [
                            .init(role: .assistant, text: "Tell me your goal ✨")
                        ])
                        store.upsertThread(new)
                        activeThreadID = new.id
                        dismiss()

                        // 雲端建立新對話與第一則訊息
                        Task {
                            try? await SupabaseRepository.shared.upsertConversation(new)
                            if let first = new.messages.first {
                                try? await SupabaseRepository.shared.upsertMessage(first, conversationId: new.id)
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
    }
}

// MARK: - UI bits

struct MessageRow: View {
    let msg: ChatMessage
    var body: some View {
        HStack {
            if msg.role == .assistant {
                HStack(alignment: .top) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.themeDarkBlue)
                    Markdown(msg.text)
                    .markdownTheme(.gitHub.text {
                        ForegroundColor(.primary)
                        BackgroundColor(.clear)
                    })
                    .textSelection(.enabled) // 讓使用者可以長按選取文字
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contextMenu {
                    Button("Copy", systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = msg.text
                    }
                }
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                Text(msg.text)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(0.15)))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .contextMenu {
                        Button("Copy", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = msg.text
                        }
                    }
            }
        }
    }
}

private struct SuggestionCard: View {
    let s: Suggestion
    let width: CGFloat
    var tap: () -> Void

    init(_ s: Suggestion, width: CGFloat, tap: @escaping () -> Void) {
        self.s = s; self.width = width; self.tap = tap
    }

    var body: some View {
        Button(action: tap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(s.title))
                    .font(.subheadline.bold())
                Text(LocalizedStringKey(s.subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(width: width, height: 110, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.gray.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let store = AppStore()
    let gemini = GeminiService()
    return NavigationStack {
        BreakDownGoalView()
            .environmentObject(store)
            .environment(gemini) // 👈 一定要加
    }
}
