// GeminiService.swift
import Foundation
import FirebaseAI
import Observation

// MARK: - Errors

enum GeminiError: Error {
    case modelInitializationError
    case jsonParsingError(Error)
    case generationError(String)
}

// MARK: - Service

@Observable
@MainActor
class GeminiService {
    
    private var generativeModel: GenerativeModel
    
    // ✅ 每日任務上限（要 2 個就把 3 改成 2）
    private let maxTasksPerDay: Int = 3
    
    init() {
        let ai = FirebaseAI.firebaseAI()
        self.generativeModel = ai.generativeModel(modelName: "gemini-2.5-flash-lite")
    }
    
    // MARK: - Main Breakdown Function（拆解任務）

    /// 主要生成函式：接收已「字串化」的偏好（PreferenceDTO）
    func generateInitialBreakdown(
        goal: Goal,
        preferences: PreferenceDTO,
        onboarding: Onboarding,
        workstyle: Workstyle,
        type: ProcrastinationType
    ) async throws -> GoalBreakdownResponse {
        
        print("正在向 Gemini 發送請求...")
        
        // 1) 使用 DTO 組合偏好摘要
        let preferencesSummary = """
        - Task Arrangement Preference: \(preferences.arrangeStrategy)
        - Work/Life Balance: \(preferences.weekdayWeekend)
        - Typical Focus Span: \(preferences.focusSpan)
        - Preference for Long Tasks: \(preferences.longTask)
        - Available daily hours (Mon-Sun): \(workstyle.dailyHours)
        - User's Procrastination Archetype (zh-TW): \(type.rawValue)
        - Tends to wait for perfection before starting (1-5 scale): \(onboarding.perfectionismPrep)
        - Tends to feel anxious when starting important tasks (1-5 scale): \(onboarding.anxietyStart)
        - Tends to do things at the last minute (1-5 scale): \(onboarding.lastMinute)
        """
        
        // 2) 根據拖延類型產生「拆解 & 排程準則」
        let archetypePlanningRules = breakdownPlanningStyleFor(
            archetypeRaw: type.rawValue,
            onboarding: onboarding,
            preferences: preferences,
            workstyle: workstyle
        )
        
        // 日期格式
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = .current
        df.dateFormat = "yyyy-MM-dd"
        
        let today = Date()
        let todayFormatted = df.string(from: today)
        let deadlineDate = goal.deadline ?? Calendar.current.date(byAdding: .day, value: 7, to: today)!
        let deadlineFormatted = df.string(from: deadlineDate)
        
        // 3) Prompt：加入「依拖延類型拆解」的明確規則
        let prompt = """
        You are a supportive, detail-oriented productivity coach. STRICTLY follow all constraints.

        ## The User's Goal
        - Title: "\(goal.title)"
        - Description: "\(goal.subTasks.first?.title ?? "No description provided.")"
        - Deadline (inclusive): \(deadlineFormatted)
        - Today's Date: \(todayFormatted)

        ## The User's Profile (MUST be respected; if conflicts, user's preference wins)
        The user is from a zh-TW app. Their procrastination archetype is stored in Chinese.
        Interpret the archetype label and adapt your planning accordingly.

        \(preferencesSummary)

        ## Archetype-specific planning rules (MUST be IMPLEMENTED, not just repeated)
        The user's procrastination archetype is: "\(type.rawValue)".
        Below are concrete planning rules you MUST apply when creating and scheduling tasks.
        If a perfectionist-type plan and a deadline-warrior-type plan for the SAME goal look very similar,
        your answer is considered WRONG.

        \(archetypePlanningRules)

        ## Output Format (JSON ONLY)
        Return a single JSON object with exactly two keys: "chatReply" (string) and "tasks" (array).

        ### 1) "tasks" (array of objects)
        - Represent the FULL actionable plan.
        - Each task object MUST have EXACTLY these 4 keys:
          1. "title": String (clear, specific action; DO NOT micro-split a single step into many fragments)
          2. "isCompleted": Boolean (always false)
          3. "dueDate": String in "YYYY-MM-DD" format
             - MUST be within [today=\(todayFormatted), deadline=\(deadlineFormatted)] inclusive.
          4. "estimatedDuration": String, e.g., "25-35 minutes", "30 minutes", or "1 hour"
             - Consider the user's typical focus span \(preferences.focusSpan).
        - HARD LIMIT: For ANY calendar date, DO NOT output more than \(maxTasksPerDay) tasks total.
        - DO NOT split one logical task across many tasks on the same day. Prefer combining into one concise task with a realistic duration window.
        - Consider workstyle.available hours by weekday: \(workstyle.dailyHours). If daily hours are small, schedule fewer tasks for that day.
        - VERY IMPORTANT:
          - The structure, wording, and schedule of tasks MUST look noticeably different for different archetypes
            (e.g., early "rough draft" for perfectionists vs. early easy warm-up + mini-deadlines for deadline-warriors).

        ### 2) "chatReply" (string, user-facing)
        - Friendly, encouraging, personalized.
        - Reflect the user's archetype in tone and coaching:
          - If type is 完美主義型 (perfectionist-type):
            * Emphasize "rough first pass", progress over perfection, small safe steps.
            * Use wording like "rough draft", "messy outline", "B-minus version".
          - If type is 死線戰士型 (deadline-warrior-type / last-minute):
            * Emphasize early small wins, mini-deadlines, and "quick starter today".
            * Use wording like "10-minute starter", "mini-deadline", "today's small checkpoint".
        - Present tasks as a bulleted list:
          For each bullet: "- (MMM dd) <title> (Est: <duration>)"
        - If the full plan has more than 5 tasks, ONLY list the first 3–5 tasks and add:
          "Here are your first few steps! You can see the full plan on your home screen."
        - Use "\\n" for newlines.

        ### Example (shape only)
        {
          "chatReply": "Awesome goal! ...",
          "tasks": [
            { "title": "First task", "isCompleted": false, "dueDate": "2025-10-25", "estimatedDuration": "30 minutes" }
          ]
        }

        IMPORTANT:
        - Output RAW JSON only (no markdown fences).
        - STRICTLY honor the date range and the per-day max \(maxTasksPerDay).
        - STRICTLY align with the user's preferences AND the archetype-specific planning rules above; deviations are errors.
        """
        
        // 4) 呼叫 Gemini 並解析 JSON
        do {
            let response = try await generativeModel.generateContent(prompt)
            print("已成功從 Gemini 收到回應。")
            
            guard var text = response.text else {
                throw GeminiError.generationError("Failed to get valid text from response.")
            }

            // 清理可能的 code fence
            if text.hasPrefix("```json\n") { text = String(text.dropFirst(7)) }
            if text.hasPrefix("```") { text = String(text.dropFirst(3)) }
            if text.hasSuffix("\n```") { text = String(text.dropLast(4)) }
            if text.hasSuffix("```") { text = String(text.dropLast(3)) }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard let jsonData = text.data(using: .utf8) else {
                throw GeminiError.generationError("Failed to convert cleaned text to data.")
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(df)
            var decoded = try decoder.decode(GoalBreakdownResponse.self, from: jsonData)
            
            // 5) 本地端保險機制：日期修正 + 每日上限合併
            decoded.tasks = postProcessTasks(
                decoded.tasks,
                start: today,
                end: deadlineDate,
                maxPerDay: maxTasksPerDay
            )
            
            return decoded
            
        } catch let error as DecodingError {
            print("JSON Parsing Error: \(error)")
            throw GeminiError.jsonParsingError(error)
        } catch {
            print("Generation Error: \(error)")
            throw GeminiError.generationError(error.localizedDescription)
        }
    }
    
    // MARK: - Journal Response（簡單版：保留，必要時可以 fallback）

    func getJournalResponse(history: [ChatMessage], newMessage: String) async throws -> String {
        let firebaseHistory = history.map { message -> ModelContent in
            let role = message.role == .user ? "user" : "model"
            return ModelContent(role: role, parts: [TextPart(message.text)])
        }
        let chat = generativeModel.startChat(history: firebaseHistory)
        do {
            let response = try await chat.sendMessage(newMessage)
            return response.text ?? "I'm sorry, I couldn't process that. Could you try again?"
        } catch {
            throw GeminiError.generationError(error.localizedDescription)
        }
    }
    
    // MARK: - Journal Response（✅ 新版：CBT + 網友語氣 + 兩類型差異）

    func getJournalResponsePersonalized(
        history: [ChatMessage],
        newMessage: String,
        preferences: PreferenceDTO,
        onboarding: Onboarding,
        workstyle: Workstyle,
        type: ProcrastinationType
    ) async throws -> String {
        
        let styleAdvice = journalStyleFor(
            archetypeRaw: type.rawValue,
            onboarding: onboarding
        )
        
        let systemLikePrompt = """
        You are a warm, down-to-earth online friend chatting in a private DM with the user.
        You reply in Traditional Chinese (zh-TW), like a supportive網友, not like an AI assistant or formal therapist.

        ## User Profile (for CBT-style guidance, do NOT repeat as a list)
        - Archetype (zh-TW label): \(type.rawValue)
        - Perfectionism (1-5): \(onboarding.perfectionismPrep)
        - Anxiety at start (1-5): \(onboarding.anxietyStart)
        - Last-minute tendency (1-5): \(onboarding.lastMinute)

        ## General style rules (VERY IMPORTANT)
        - Tone: 像一個懂事又不嘴砲的好友在聊天室聊天，口氣自然，不要太制式。
        - Use short sentences, casual wording, and at most 1–2 emojis（例如 🙂、🤍、🥹）.
        - Total length: 3–5 short sentences. Avoid long paragraphs or walls of text.
        - NO bullet points, NO numbered lists, NO markdown formatting, NO section titles.
        - At most ONE short follow-up question at the end（可以不問問題）; other句子以陪伴、回應為主。
        - Do NOT heavily repeat the user's original sentences. 回應要像自己真的在聽，而不是複誦。
        - Focus on ONE tiny next step or reframe,不要塞太多建議。

        ## CBT-style guidance (what you should DO in your reply)
        1) Briefly name and validate the emotion you infer（e.g. 壓力、愧疚、挫折、無力）.
        2) Gently challenge可能的自動想法或認知偏誤（例如全有全無、災難化、自我貶低），用溫柔而實際的角度重構。
        3) 提出「今天可以嘗試的一個很小的行為實驗」（5–15 分鐘就好），說明只是試試看，不用完美。
        4) 結尾用一句給力量的話，讓對方覺得「可以再試一次」，不要批評或說教。

        ## Archetype-specific coaching notes
        Use the following notes to adapt your CBT reframe and the small experiment:

        \(styleAdvice)

        ---

        使用者剛剛在心情日記裡寫下這段話（可能是中文或英文）：
        "\(newMessage)"

        現在請你用繁體中文直接回覆對方一段話，
        遵守以上所有規則，只輸出訊息內容，不要多做說明。
        """
        
        // 這裡可以選擇帶歷史，也可以只帶當前訊息
        let firebaseHistory = history.map { message -> ModelContent in
            let role = message.role == .user ? "user" : "model"
            return ModelContent(role: role, parts: [TextPart(message.text)])
        }
        
        let chat = generativeModel.startChat(history: firebaseHistory)
        
        do {
            let response = try await chat.sendMessage(systemLikePrompt)
            return response.text ?? "我在這裡陪你，有什麼感受都可以慢慢跟我說。"
        } catch {
            throw GeminiError.generationError(error.localizedDescription)
        }
    }
    
    // MARK: - 依拖延類型決定「回應風格 & CBT 重點」（Journal 用）

    private func journalStyleFor(archetypeRaw: String, onboarding: Onboarding) -> String {
        // 目前類型： "完美主義型"、"死線戰士型"
        if archetypeRaw.contains("完美") {
            return """
            ### 完美主義型使用者（perfectionist-type）
            - 典型模式：很怕「不夠好」、很容易全有全無（覺得沒辦法做到完美就乾脆不做），做事前會先要求自己想清楚、準備好。
            - 在回覆裡：
              - 多幫他看到「已經做到了哪些小地方」，淡化「一次就要做到最好」的壓力。
              - 用口語方式提醒：「先做一個很醜/很亂的版本也沒關係」、「今天只要完成 30% 就很不錯」。
              - 在認知重建時，可以指出：把事情當成 0 分 / 100 分 是一種想法，不是事實，可以試著接受「60 分也有價值」。
              - 安排的行為實驗要小且不完美，例如：「先隨便寫 3 句，亂也沒關係」、「今天只要打開檔案 + 寫一段就收工」。
            """

        } else if archetypeRaw.contains("死線") || archetypeRaw.contains("戰士") {
            return """
            ### 死線戰士型使用者（deadline-warrior / last-minute-type）
            - 典型模式：覺得自己「壓力來才做得出來」，平常會拖到最後一刻才衝刺，事後又很累、很後悔。
            - 在回覆裡：
              - 先理解他喜歡「最後衝刺的爽感」，但溫柔點出：那種方式很耗體力、也很消磨自信。
              - 認知重建時，可以質疑「一定要到最後一刻才做得出好東西嗎？」並舉例：先動一點點，反而可以讓最後的衝刺比較輕鬆。
              - 行為實驗要強調「超小的暖身」，例如：「現在先花 5–10 分鐘，把明天要做的三件事列出來就好」、「今天只先寫開頭一段」。
              - 語氣可以稍微有一點動力感，像在說：「先動一點點，之後的你會很感謝現在的自己」。
            """

        } else {
            return """
            ### 一般或混合型使用者
            - 以溫和、中性的方式陪伴，混合一點穩定跟鼓勵。
            - 認知重建時，不要太激烈，點到為止：幫他看到事情不是只有一種解讀。
            - 行為實驗仍然保持小且可行，例如：「今天先做 10 分鐘試試看」。
            """
        }
    }
    
    // MARK: - 依拖延類型產生「拆解 & 排程」準則（Breakdown 用）

    private func breakdownPlanningStyleFor(
        archetypeRaw: String,
        onboarding: Onboarding,
        preferences: PreferenceDTO,
        workstyle: Workstyle
    ) -> String {
        // 目前 app 的類型： "完美主義型"、"死線戰士型"
        if archetypeRaw.contains("完美") {
            // ✅ 完美主義型
            return """
            ### Planning rules for 完美主義型 (perfectionist-type) procrastination
            - Main risk: They delay starting until they can do it "perfectly", over-plan, and over-edit.
            - Task granularity:
              - Always start with a very small, imperfect, "rough" action (e.g. brain-dump, ugly outline, quick sketch).
              - Avoid more than ONE separate "research" or "planning" task before a first draft. If you add research, time-box it strictly (e.g. 20–30 minutes).
              - Prefer task titles that explicitly include words like "rough", "messy", "first pass", "B-minus version".
            - Scheduling:
              - Force an early, imperfect first draft well BEFORE the deadline (e.g. within the first 30–40% of the time window).
              - Schedule 1–2 short review / refinement passes later, close to the deadline, but keep each review task short.
              - Never put all heavy work on the last 1–2 days; those days should only contain light polishing / formatting / submission tasks.
            - Emotional protection:
              - Avoid wording that sounds like "final", "perfect", or "comprehensive" too early.
              - Use wording that reduces fear of judgment, e.g. "draft a messy version just for yourself" instead of "write the final report".
            """

        } else if archetypeRaw.contains("死線") || archetypeRaw.contains("戰士") {
            // ✅ 死線戰士型
            return """
            ### Planning rules for 死線戰士型 (deadline-warrior / last-minute-type) procrastination
            - Main risk: They ignore the task until the deadline is very close, then rush in a big panic sprint.
            - Task granularity:
              - Create EASY, LOW-FRICTION warm-up tasks at the very beginning (5–20 minutes), such as "open the document and write 3 bullet points".
              - Break large work into several checkpoints (outline, half draft, full draft, revision) so that progress is visible before the last day.
            - Scheduling:
              - Introduce explicit "mini-deadlines" several days BEFORE the real deadline, e.g. "finish rough outline by X", "complete 50% draft by Y".
              - Do NOT place the majority of effort on the final day; the last day should mainly be review, small fixes, and submission.
              - Even if the total window is short, ensure at least 2 different days contain meaningful progress tasks (not all on one day).
            - Motivation hacks:
              - Prefer task titles that emphasize quick wins and action, e.g. "10-minute starter pass", "write only the introduction today".
              - Make it clear what "good enough for today" means, to reduce the feeling of "I'll just do it all later".
            """

        } else {
            // ✅ 預設平衡型（防呆）
            return """
            ### Planning rules for GENERAL / MIXED-type procrastination
            - Use balanced granularity: tasks are 20–60 minutes each, each with a clear concrete action.
            - Ensure the user starts within the next 24 hours with a simple, low-friction task.
            - Avoid clustering all work on the last day; spread tasks across the available window.
            - Combine at most one short research/planning task with clear output (e.g. "collect 3 sources and write 3 bullets about each").
            """
        }
    }
    
    // MARK: - Wrapper：給 View 呼叫（注意：收 `PreferenceDTO`）
    
    func breakDownGoal(
        goalTitle: String,
        description: String,
        preferences: PreferenceDTO,
        onboarding: Onboarding,
        workstyle: Workstyle,
        type: ProcrastinationType,
        deadline: Date?
    ) async throws -> GoalBreakdownResponse {
        
        var tempGoal = Goal(
            title: goalTitle,
            icon: "checklist",
            colorHex: "#4F46E5",
            deadline: deadline,
            reminders: [],
            subTasks: []
        )
        if description.isEmpty == false {
            tempGoal.subTasks = [TaskItem(title: description, isCompleted: false, dueDate: nil)]
        }
        
        let response = try await generateInitialBreakdown(
            goal: tempGoal,
            preferences: preferences,
            onboarding: onboarding,
            workstyle: workstyle,
            type: type
        )
        return response
    }
}

// MARK: - Post-processing: 日期與每日上限收斂（dueDate 為 Date 版）

extension GeminiService {
    
    private func postProcessTasks(
        _ tasks: [TaskItem],
        start: Date,
        end: Date,
        maxPerDay: Int
    ) -> [TaskItem] {
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)
        
        // 1) 修正日期
        var fixed = tasks.map { t -> TaskItem in
            var t = t
            if let d = t.dueDate {
                let day = cal.startOfDay(for: d)
                let clamped = min(max(day, startDay), endDay)
                t.dueDate = clamped
            } else {
                t.dueDate = endDay
            }
            t.isCompleted = false
            return t
        }
        
        // 2) 每日上限，超出的合併成 bundle
        var grouped: [Date: [TaskItem]] = [:]
        for t in fixed {
            let key = cal.startOfDay(for: t.dueDate ?? endDay)
            grouped[key, default: []].append(t)
        }
        
        var result: [TaskItem] = []
        let allDatesSorted = grouped.keys.sorted()
        
        for dateKey in allDatesSorted {
            let dayTasks = grouped[dateKey] ?? []
            if dayTasks.count <= maxPerDay {
                result.append(contentsOf: dayTasks)
            } else {
                let keepCount = max(1, maxPerDay - 1)
                let keep = Array(dayTasks.prefix(keepCount))
                let toMerge = Array(dayTasks.dropFirst(keepCount))
                
                let mergedTitle = "Bundle: " + toMerge.map { $0.title }.joined(separator: "; ")
                let mergedMinutes = toMerge
                    .compactMap { parseEstimatedDurationMinutes($0.estimatedDuration) }
                    .reduce(0, +)
                let defaultPerTask = 30
                let missingCount = toMerge.filter { parseEstimatedDurationMinutes($0.estimatedDuration) == nil }.count
                let mergedTotalMin = mergedMinutes + missingCount * defaultPerTask
                let mergedEst = formatMinutesToHuman(mergedTotalMin)
                
                let merged = TaskItem(
                    title: mergedTitle,
                    isCompleted: false,
                    dueDate: dateKey,
                    estimatedDuration: mergedEst
                )
                result.append(contentsOf: keep)
                result.append(merged)
            }
        }
        
        result.sort { (a, b) -> Bool in
            let da = a.dueDate ?? Date.distantFuture
            let db = b.dueDate ?? Date.distantFuture
            if da != db { return da < db }
            return a.title < b.title
        }
        
        return result
    }
    
    // 解析 estimatedDuration
    private func parseEstimatedDurationMinutes(_ s: String?) -> Int? {
        guard let s = s?.lowercased() else { return nil }
        if let rangeMatch = s.range(of: #"(\d+)\s*[-–]\s*(\d+)\s*min"#, options: .regularExpression) {
            let sub = String(s[rangeMatch])
            let nums = sub.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            if nums.count >= 2 { return nums[1] }
        }
        if let hourMatch = s.range(of: #"(\d+(\.\d+)?)\s*hour"#, options: .regularExpression) {
            let sub = String(s[hourMatch])
            let numStr = sub.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
            if let hours = Double(numStr) { return Int(round(hours * 60.0)) }
        }
        if let minMatch = s.range(of: #"(\d+)\s*min"#, options: .regularExpression) {
            let sub = String(s[minMatch])
            let nums = sub.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            if let m = nums.first { return m }
        }
        return nil
    }
    
    private func formatMinutesToHuman(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) minutes" }
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 { return "\(h) hour" + (h > 1 ? "s" : "") }
        return "\(h) hour" + (h > 1 ? "s" : "") + " \(m) minutes"
    }
}

// MARK: - Helpers

extension Date {
    var startOfDayLocal: Date { Calendar.current.startOfDay(for: self) }
}
