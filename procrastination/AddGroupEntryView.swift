//  AddGroupEntryView.swift

import SwiftUI

struct AddGroupEntryView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // 目標基本資訊
    @State private var goalTitle: String = ""
    @State private var goalDescription: String = ""

    // icon / 顏色
    @State private var showIconPicker = false
    @State private var showColorPicker = false
    @State private var selectedIcon: String = "person.3.fill"
    @State private var selectedColorHex: String = "#A5D8DC"

    // 日期
    @State private var startDate: Date = Date()
    @State private var deadline: Date =
        Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var showStartDatePicker = false
    @State private var showDeadlinePicker = false

    // 通知
    @State private var addReminder: Bool = true
    @State private var reminderTime: Date = Date()

    // 社群模式
    @State private var socialMode: SocialMode = .cooperation

    // 參與人員
    @State private var participantEmailInput: String = ""
    @State private var participantEmails: [String] = []    // 不含自己，自己會自動加

    // 導航到拆解頁
    @State private var navigateToBreakdown: Bool = false
    @State private var createdGoalID: UUID? = nil
    @State private var initialUserMessage: String? = nil

    // Alert
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // 隱形 NavigationLink
                NavigationLink(isActive: $navigateToBreakdown) {
                    BreakDownGoalView(
                        initialGoalID: createdGoalID,
                        initialUserMessage: initialUserMessage
                    )
                } label: {
                    EmptyView()
                }
                .hidden()

                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundStyle(Color.themeBrown)
                    }
                    Spacer()
                    Text("Create a Group Goal")
                        .font(.headline).bold()
                        .foregroundColor(.themeBrown)
                    Spacer()
                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // MARK: GOAL
                        VStack(alignment: .leading, spacing: 12) {
                            Text("GROUP GOAL")
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)

                            TextField("Please enter your group goal.", text: $goalTitle)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)

                            TextField("Describe the shared goal.", text: $goalDescription, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                                .lineLimit(3, reservesSpace: true)
                        }

                        // MARK: Mode
                        VStack(alignment: .leading, spacing: 12) {
                            Text("MODE")
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                modeChip(title: "Cooperation", mode: .cooperation)
                                modeChip(title: "Competition", mode: .competition)
                            }
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(Color.gray.opacity(0.08))
                            )
                        }
                        // MARK: ICON & COLOR
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ICON AND COLOR")
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)

                            HStack(spacing: 16) {
                                // Icon Card
                                Button(action: { showIconPicker = true }) {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle().fill(Color.gray.opacity(0.1))
                                            Image(systemName: selectedIcon)
                                                .foregroundStyle(Color.themeDarkYellow)
                                        }
                                        .frame(width: 40, height: 40)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Icon").bold()
                                            Text("For this group goal")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.2))
                                    )
                                }
                                .buttonStyle(.plain)
                                .sheet(isPresented: $showIconPicker) {
                                    IconPickerView(selected: $selectedIcon)
                                        .presentationDetents([.large])
                                }

                                // Color Card
                                Button(action: { showColorPicker = true }) {
                                    HStack(spacing: 12) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(hex: selectedColorHex))
                                            .frame(width: 24, height: 24)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(colorName(for: selectedColorHex)).bold()
                                            Text("Color").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.gray.opacity(0.2))
                                    )
                                }
                                .buttonStyle(.plain)
                                .sheet(isPresented: $showColorPicker) {
                                    ThemeColorPickerView(selectedHex: $selectedColorHex)
                                        .presentationDetents([.medium, .large])
                                }
                            }
                        }

                        // MARK: DATES
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DATES")
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)

                            // Start
                            Button(action: { showStartDatePicker = true }) {
                                HStack {
                                    Text("Start")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(startDate.formatted(.dateTime.year().month().day()))
                                        .foregroundStyle(Color.themeBrown)
                                }
                                .padding(16)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2))
                                )
                            }
                            .buttonStyle(.plain)

                            // Deadline
                            Button(action: { showDeadlinePicker = true }) {
                                HStack {
                                    Text("Deadline")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(deadline.formatted(.dateTime.year().month().day()))
                                        .foregroundStyle(Color.themeBrown)
                                }
                                .padding(16)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2))
                                )
                            }
                            .buttonStyle(.plain)

                            if startDate > deadline {
                                Text("Start date is after the deadline. The deadline will be adjusted when saving.")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }

                        // MARK: PARTICIPANTS
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PARTICIPANTS")
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)

                            HStack {
                                TextField("Add member by email", text: $participantEmailInput)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    addParticipant()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                            }

                            if !participantEmails.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(participantEmails, id: \.self) { mail in
                                        HStack {
                                            Text(mail)
                                                .font(.subheadline)
                                            Spacer()
                                            Button {
                                                removeParticipant(mail)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color(.secondarySystemBackground))
                                        )
                                    }
                                }
                            }

                            Text("You will be added automatically as a member.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // MARK: REMINDERS
                        VStack(alignment: .leading, spacing: 12) {
                            Text("REMINDERS")
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)

                            HStack {
                                Text("Want to receive a notification?")
                                Spacer()
                                Toggle("", isOn: $addReminder)
                                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#4fd4c9")))
                            }

                            if addReminder {
                                HStack(spacing: 12) {
                                    Image(systemName: "bell.fill")
                                        .foregroundStyle(Color.themeDarkYellow)
                                    DatePicker(
                                        "Reminder time",
                                        selection: $reminderTime,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .labelsHidden()
                                }
                                .padding(16)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2))
                                )
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }

                // Bottom button
                VStack {
                    Button("Start breaking down with your group!") {
                        createAndBreakdown()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.themeDarkYellow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showStartDatePicker) {
            DatePickerSheet(
                title: "Select a start date",
                date: $startDate,
                lowerBound: Date()
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showDeadlinePicker) {
            DatePickerSheet(
                title: "Select a deadline",
                date: $deadline,
                lowerBound: Date()
            )
            .presentationDetents([.medium])
        }
        .onChange(of: startDate) { _, newValue in
            if newValue > deadline {
                deadline = Calendar.current.date(byAdding: .day, value: 7, to: newValue) ?? newValue
            }
        }
        .alert("Cannot create group goal", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
        .background(Color(uiColor: .systemBackground))
    }
    
    private func modeChip(title: String, mode: SocialMode) -> some View {
        Button {
            socialMode = mode
        } label: {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(socialMode == mode ? .themeBrown : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        socialMode == mode
                        ? Color.themeYellow            // ✅ 選到時：themeYellow 底
                        : Color.clear
                    )
                )
        }
        .buttonStyle(.plain)
    }


    // MARK: - Participants

    private func addParticipant() {
        let trimmed = participantEmailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        guard participantEmails.contains(trimmed) == false else {
            participantEmailInput = ""
            return
        }
        participantEmails.append(trimmed)
        participantEmailInput = ""
    }

    private func removeParticipant(_ mail: String) {
        participantEmails.removeAll { $0 == mail }
    }

    // MARK: - Create & Breakdown

    private func createAndBreakdown() {
        // 1. 檢查標題
        guard goalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            validationMessage = "Please enter a group goal title."
            showValidationAlert = true
            return
        }

        // 2. 檢查登入狀態（一定要有 currentUser）
        guard let currentUser = authVM.currentUser else {
            validationMessage = "Please log in first."
            showValidationAlert = true
            return
        }

        // 3. 檢查人數 > 1（包含自己）
        let selfEmail = currentUser.email
        let allParticipants = Array(Set(participantEmails + [selfEmail]))
        if allParticipants.count < 2 {
            validationMessage = "Please add at least one more member (besides yourself)."
            showValidationAlert = true
            return
        }

        // 4. 產生 groupId
        let groupId = UUID()

        // 5. Reminders
        var reminders: [Reminder] = []
        if addReminder {
            reminders.append(Reminder(time: reminderTime, repeatDaily: true))
        }

        // 6. 起迄日修正
        let finalStart = startDate
        let finalDeadline = startDate > deadline
            ? Calendar.current.date(byAdding: .day, value: 7, to: startDate)
            : deadline

        // 7. 先建立「自己這一份」本地目標（繼續存在 snapshot 裡）
        let newGoal = Goal(
            id: UUID(),
            title: goalTitle,
            icon: selectedIcon,
            colorHex: selectedColorHex,
            startDate: finalStart,
            deadline: finalDeadline ?? deadline,
            reminders: reminders,
            subTasks: [],
            createdAt: Date(),
            isGroupGoal: true,
            groupId: groupId,
            participantEmails: allParticipants,
            socialModeRaw: socialMode.rawValue
        )

        // 存到 AppStore（會順便觸發 snapshot → user_profiles.snapshot）
        store.addGoal(newGoal)

        // 8. 同步到 Supabase：group_goals + group_participants
        Task {
            do {
                try await SupabaseRepository.shared.createGroupGoal(
                    groupId: groupId,
                    title: goalTitle,
                    description: goalDescription.isEmpty ? nil : goalDescription,
                    icon: selectedIcon,
                    colorHex: selectedColorHex,
                    startDate: finalStart,
                    deadline: finalDeadline ?? deadline,
                    socialMode: socialMode.rawValue,   // 建議 rawValue = "cooperate"/"compete"
                    ownerUserId: currentUser.id,
                    ownerEmail: selfEmail,
                    participantEmails: allParticipants
                )
                print("✅ Supabase group goal created")
            } catch {
                print("❌ failed to create group goal in Supabase:", error)
                // 這裡你之後可以加 UI 提示（例如顯示 alert）
            }
        }

        // 9. 一樣導去拆解畫面（個人的拆解，存回自己的 snapshot）
        let message = composeInitialUserMessage(
            title: newGoal.title,
            description: goalDescription,
            startDate: newGoal.startDate,
            deadline: newGoal.deadline
        )

        createdGoalID = newGoal.id
        initialUserMessage = message
        navigateToBreakdown = true
    }


    private func composeInitialUserMessage(
        title: String,
        description: String,
        startDate: Date?,
        deadline: Date?
    ) -> String {
        var parts: [String] = []
        parts.append("Group Goal: \(title)")
        if description.isEmpty == false {
            parts.append("Description: \(description)")
        }
        if let startDate {
            parts.append("Start Date: \(startDate.formatted(.dateTime.year().month().day()))")
        }
        if let deadline {
            parts.append("Deadline: \(deadline.formatted(.dateTime.year().month().day()))")
        }
        parts.append("This is a group goal. Please break it down into actionable tasks for me, considering my procrastination type, workstyle and preferences.")
        return parts.joined(separator: "\n")
    }

    // MARK: - Inner date picker sheet

    private struct DatePickerSheet: View {
        @Environment(\.dismiss) private var dismiss
        let title: String
        @Binding var date: Date
        let lowerBound: Date

        var body: some View {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker(
                        title,
                        selection: $date,
                        in: lowerBound...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()

                    Spacer()
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }
}

// MARK: - Color name helper（防止找不到 colorName）

private func colorName(for hex: String) -> String {
    switch hex.uppercased() {
    case "#B8C0FF": return "Lavender"
    case "#F97373": return "Coral"
    case "#4F46E5": return "Indigo"
    default:        return "Custom"
    }
}
