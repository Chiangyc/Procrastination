//
//  JournalView.swift
//  procrastination
//

import SwiftUI

struct JournalView: View {
    @Environment(GeminiService.self) private var geminiService
    @EnvironmentObject var store: AppStore

    @State private var activeThreadID: UUID? = nil
    @State private var showIndexSheet = false

    @State private var input = ""
    @State private var isGenerating = false

    private let suggestions: [JournalSuggestion] = [
        .init(title: "Tell me how you feel when completing tasks?",
              subtitle: "Sense of achievement, exhausted…"),
        .init(title: "Do you face any bottlenecks?",
              subtitle: "Lack of motivation, outcome wasn’t as good as expected…"),
        .init(title: "What small win did you have today?",
              subtitle: "Finished a subtask, stayed focused…")
    ]

    // 只取日記 threads，按日期新到舊
    private var journalThreads: [ChatThread] {
        store.conversations
            .filter { $0.isJournalThread }
            .sorted { $0.effectiveJournalDate > $1.effectiveJournalDate }
    }

    private var activeThread: ChatThread? {
        guard let id = activeThreadID else { return nil }
        return store.conversations.first(where: { $0.id == id })
    }

    private var messages: [ChatMessage] {
        activeThread?.messages ?? []
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 訊息列表
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
                            MessageRow(msg: msg)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
                .scrollDismissesKeyboard(.immediately)

                // 下方輸入與建議
                bottomComposer
            }
//            .navigationTitle("Mood Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Mood Journal")
                        .font(.headline.bold())
                        .foregroundColor(.themeBlue)   // 這裡改標題顏色
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showIndexSheet = true
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.title3)
                            .foregroundStyle(Color.themeBlue)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color(.secondarySystemBackground)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Journal index")
                }
            }
            .sheet(isPresented: $showIndexSheet) {
                JournalIndexSheetSimple(activeThreadID: $activeThreadID)
                    .environmentObject(store)
            }
            .onAppear {
                // 確保今天有一個日記聊天室
                if activeThreadID == nil {
                    activeThreadID = ensureTodayThread()
                } else if store.conversations.first(where: { $0.id == activeThreadID }) == nil {
                    activeThreadID = ensureTodayThread()
                }
            }
        }
    }

    // MARK: - 下方輸入區

    private var bottomComposer: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(suggestions) { s in
                        JournalSuggestionCard(s, width: 260) {
                            input = s.title
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .frame(height: 130)

            ChatInputBar(
                text: $input,
                isLoading: isGenerating,
                placeholder: String(localized: "Write anything about your day…"),
                onSend: { send() }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - 一天一個日記 thread

    private func ensureTodayThread() -> UUID {
        let today = Date().startOfDayLocal

        if let existing = journalThreads.first(where: { $0.effectiveJournalDate == today }) {
            return existing.id
        }

        // 1. 取得目前 App 設定的語言代碼 (例如 "zh-Hant" 或 "en")
        let langCode = store.language.rawValue
        
        // 2. 嘗試找出該語言的翻譯檔案路徑
        var bundle = Bundle.main
        if let path = Bundle.main.path(forResource: langCode, ofType: "lproj") {
            bundle = Bundle(path: path) ?? Bundle.main
        }

        // 3. 使用該 Bundle 進行翻譯 (如果找不到就會回傳原本的 Key)
        let titleText = NSLocalizedString("Mood Journal", bundle: bundle, comment: "")
        let messageText = NSLocalizedString("How are you feeling today? You can tell me anything.", bundle: bundle, comment: "")

        var thread = ChatThread(
            title: titleText, // 存入翻譯後的中文標題
            messages: [
                ChatMessage(
                    role: .assistant,
                    text: messageText // 存入翻譯後的中文訊息
                )
            ],
            relatedGoalID: nil,
            lastUpdated: Date()
        )
        thread.isJournal = true
        thread.journalDate = today

        store.upsertThread(thread)
        return thread.id
    }

    // MARK: - Send

    private func send() {
        guard !isGenerating else { return }

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let id = activeThreadID ?? ensureTodayThread()
        activeThreadID = id

        guard var thread = store.conversations.first(where: { $0.id == id }) else { return }

        let userMessage = ChatMessage(role: .user, text: trimmed)
        thread.messages.append(userMessage)
        thread.lastUpdated = Date()

        // 日記命名：第一次 user 訊息
        if thread.isJournalThread {
            if thread.journalDate == nil {
                thread.journalDate = Date().startOfDayLocal
            }
            if let firstUser = thread.firstUserMessage {
                if thread.title.isEmpty || thread.title == "Mood Journal" {
                    thread.title = firstUser.journalTitleCandidate()
                }
            }
        }

        store.upsertThread(thread)

        input = ""
        isGenerating = true

        Task {
            defer { isGenerating = false }

            do {
                // 準備 PreferenceDTO 給 Gemini
                let prefDTO = PreferenceDTO(
                    arrangeStrategy: store.preferences.arrangeStrategy.rawValue,
                    weekdayWeekend: store.preferences.weekdayWeekend.rawValue,
                    focusSpan: store.preferences.focusSpan.rawValue,
                    longTask: store.preferences.longTask.rawValue
                )

                let responseText = try await geminiService.getJournalResponsePersonalized(
                    history: thread.messages,
                    newMessage: userMessage.text,
                    preferences: prefDTO,
                    onboarding: store.onboarding,
                    workstyle: store.workstyle,
                    type: store.procrastinationType
                )

                // 新增 AI 訊息並更新本地 store
                guard var updatedThread = store.conversations.first(where: { $0.id == id }) else { return }
                let aiMessage = ChatMessage(role: .assistant, text: responseText)
                updatedThread.messages.append(aiMessage)
                updatedThread.lastUpdated = Date()
                store.upsertThread(updatedThread)

            } catch {
                print("❌ Journal error:", error)
                guard var errorThread = store.conversations.first(where: { $0.id == id }) else { return }
                let errorMsg = ChatMessage(
                    role: .assistant,
                    text: "抱歉，我這邊剛剛出了一點狀況，可以等等再試一次嗎？"
                )
                errorThread.messages.append(errorMsg)
                errorThread.lastUpdated = Date()
                store.upsertThread(errorThread)
            }
        }

    }
}

//
// MARK: - 簡單版索引（只有列表，先不分週）
//

// MARK: - 依週次分組的索引（取代原本的 JournalIndexSheetSimple）

private struct JournalIndexSheetSimple: View {
    @EnvironmentObject var store: AppStore
    @Binding var activeThreadID: UUID?
    @Environment(\.dismiss) private var dismiss

    // 小小的 bucket 結構，用來代表「這週 / 一週前 / 兩週前…」這一組
    private struct Bucket: Identifiable {
        let id = UUID()
        let title: String            // 例如「這週」「一週前」
        let threads: [ChatThread]    // 該組底下的日記 threads
    }

    // 所有日記 threads，依日期新到舊
    private var journalThreads: [ChatThread] {
        store.conversations
            .filter { $0.isJournalThread }
            .sorted { $0.effectiveJournalDate > $1.effectiveJournalDate }
    }

    // 依日期分成「這週 / 一週前 / 兩週前 / 三週前 / 一個月前以上」
    private var buckets: [Bucket] {
        let now = Date().startOfDayLocal
        let cal = Calendar.current
        var dict: [String: [ChatThread]] = [:]

        func bucketTitle(for date: Date) -> String {
            let d1 = date.startOfDayLocal
            let d2 = now
            let diff = cal.dateComponents([.day], from: d1, to: d2).day ?? 0
            switch diff {
            case ..<7: return "這週"
            case 7..<14: return "一週前"
            case 14..<21: return "兩週前"
            case 21..<28: return "三週前"
            default: return "一個月前以上"
            }
        }

        // 把每個 thread 丟進對應的 bucket
        for t in journalThreads {
            let key = bucketTitle(for: t.effectiveJournalDate)
            dict[key, default: []].append(t)
        }

        // 固定顯示順序
        let order = ["這週", "一週前", "兩週前", "三週前", "一個月前以上"]

        return order.compactMap { key in
            guard let arr = dict[key] else { return nil }
            return Bucket(
                title: key,
                threads: arr.sorted { $0.effectiveJournalDate > $1.effectiveJournalDate }
            )
        }
    }

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "yyyy/MM/dd"
        return df
    }

    var body: some View {
        NavigationStack {
            List {
                if journalThreads.isEmpty {
                    Text("No journal entries yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(buckets) { bucket in
                        // 一組 = 標題 + 底下多筆日記
                        VStack(alignment: .leading, spacing: 6) {
                            // 上面這行像「一週前 ─────」
                            HStack {
                                Text(bucket.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Rectangle()
                                    .frame(height: 0.5)
                                    .foregroundStyle(.quaternary)
                            }
                            .padding(.bottom, 2)

                            // 該組底下的每一個日記
                            ForEach(bucket.threads) { t in
                                Button {
                                    activeThreadID = t.id
                                    dismiss()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(t.title.isEmpty ? "Mood Journal" : t.title)
                                                .font(.body)
                                                .lineLimit(1)
                                                .foregroundStyle(.black)
                                            Text(dateFormatter.string(from: t.effectiveJournalDate))
                                                .font(.caption)
                                                .foregroundStyle(.black.opacity(0.6))
                                        }
                                        Spacer()
                                        if activeThreadID == t.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Journal Index")
            .tint(.black)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}


//
// MARK: - Suggestion & ChatInputBar（跟你之前一樣）
//

struct JournalSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

struct JournalSuggestionCard: View {
    let s: JournalSuggestion
    let width: CGFloat
    var tap: () -> Void

    init(_ s: JournalSuggestion, width: CGFloat, tap: @escaping () -> Void) {
        self.s = s; self.width = width; self.tap = tap
    }

    var body: some View {
        Button(action: tap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(s.title))
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Text(LocalizedStringKey(s.subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(width: width, height: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.gray.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ChatInputBar: View {
    @Binding var text: String
    var isLoading: Bool
    var placeholder: String
    var onSend: () -> Void

    @FocusState private var focused: Bool
    private let minHeight: CGFloat = 40
    private let maxHeight: CGFloat = 120
    private let corner: CGFloat = 14

    var body: some View {
        HStack(spacing: 10) {
            ZstackBackground
            sendButton
        }
        .animation(.easeInOut(duration: 0.15), value: isLoading)
        .onSubmit { onSend() }
    }

    private var ZstackBackground: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: corner)
                .fill(Color(.secondarySystemBackground))

            IMEAwareTextView(
                text: $text,
                placeholder: placeholder,
                onCommit: onSend
            )
            .frame(minHeight: minHeight, maxHeight: maxHeight)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .focused($focused)
        }
        .frame(minHeight: minHeight, maxHeight: maxHeight)
    }

    private var sendButton: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(width: 40, height: 40)
            } else {
                Button(action: {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSend()
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.accentColor))
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

#Preview {
    let store = AppStore()
    let gemini = GeminiService()
    return NavigationStack {
        JournalView()
            .environmentObject(store)
            .environment(gemini)
    }
}
