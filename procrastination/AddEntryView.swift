//
//  AddEntryView.swift
//  procrastination
//
//  Created by Iris Tsou on 2025/10/25.
//
import SwiftUI

struct AddEntryView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var goalTitle: String = ""
    @State private var goalDescription: String = ""
    @State private var showIconPicker = false
    @State private var showColorPicker = false
    @State private var showDatePicker = false
    @State private var selectedIcon: String = "figure.walk"
    @State private var selectedColorHex: String = "#A5D8DC"
    @State private var deadline: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var addReminder: Bool = true
    @State private var reminderTime: Date = Date()
    // 新增：導航狀態
    @State private var navigateToBreakdown: Bool = false
    // 新增：傳給 BreakDownGoalView 的參數
    @State private var createdGoalID: UUID? = nil
    @State private var initialUserMessage: String? = nil

    // 新增：Start Date
    @State private var startDate: Date = Date()
    @State private var showStartDatePicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 隱形 NavigationLink 由狀態觸發，並帶入初始參數
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
                    Text("Set a New Goal")
                        .font(.headline).bold()
                        .foregroundColor(.themeBrown)
                    Spacer()
                    // Balance the back button
                    Color.clear.frame(width: 24, height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // GOAL Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("GOAL")
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)
                            
                            TextField("Please enter your goal.", text: $goalTitle)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                            
                            TextField("Describe your goal.", text: $goalDescription)
                                .textFieldStyle(.roundedBorder)
                                .font(.body)
                        }
                        
                        // ICON AND COLOR Section
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
                                                .foregroundStyle(Color.themeBlue)
                                        }
                                        .frame(width: 40, height: 40)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(iconName(for: selectedIcon)).bold()
                                            Text("Icon").font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
                                }
                                .buttonStyle(.plain)
                                .sheet(isPresented: $showIconPicker) {
                                    IconPickerView(selected: $selectedIcon)
                                        .presentationDetents([.large])
                                }

                                // ---- Color Card ----
                                Button(action: { showColorPicker = true }) {
                                    HStack(spacing: 12) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(hex: selectedColorHex) ?? Color.themeBlue)
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
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
                                }
                                .buttonStyle(.plain)
                                .sheet(isPresented: $showColorPicker) {
                                    ThemeColorPickerView(selectedHex: $selectedColorHex)
                                        .presentationDetents([.medium, .large])
                                }
                            }
                        }
                        
                        // DATES Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DATES")
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)

                            // Start Date
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
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
                            }
                            .buttonStyle(.plain)

                            // Deadline
                            Button(action: { showDatePicker = true }) {
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
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
                            }
                            .buttonStyle(.plain)

                            // Simple validation hint
                            if startDate > deadline {
                                Text("Start date is after the deadline. The deadline will be adjusted when saving.")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        
                        // REMINDERS Section
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
                                    Image(systemName: "moon.fill")
                                        .foregroundStyle(Color(hex: "#f0bd44"))
                                    Text("30 minutes before the deadline")
                                    Spacer()
                                    Image(systemName: "bell.fill")
                                        .foregroundStyle(Color(hex: "#f0bd44"))
                                    Text("Every day")
                                }
                                .padding(16)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
                            }
                            
                            Button("Add Reminder") {
                                // Add reminder logic
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                
                // Bottom Button
                VStack {
                    Button("Start breaking down the goal!") {
                        let newGoal = createGoal()
                        // 準備第一則要送給 Gemini 的訊息（包含 title/description/start/deadline）
                        let message = composeInitialUserMessage(
                            title: newGoal.title,
                            description: goalDescription,
                            startDate: newGoalStartDate(newGoal),
                            deadline: newGoal.deadline
                        )
                        // 帶參數導航，BreakDownGoalView 會自動送出
                        createdGoalID = newGoal.id
                        initialUserMessage = message
                        navigateToBreakdown = true
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "#f0bd44"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(date: $deadline)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showStartDatePicker) {
            StartDatePickerSheet(date: $startDate)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: startDate) { _, newValue in
            // 若開始日超過目前的 deadline，將 deadline 自動調整為 start + 7 天
            if newValue > deadline {
                deadline = Calendar.current.date(byAdding: .day, value: 7, to: newValue) ?? newValue
            }
        }
        .background(Color(uiColor: .systemBackground))
    }
    
    private func iconName(for systemName: String) -> LocalizedStringKey {
        switch systemName {
        case "figure.walk": return "Walking"
        case "drop.fill": return "Water"
        case "brain.head.profile": return "Focus"
        case "heart.fill": return "Health"
        case "book.fill": return "Reading"
        case "bolt.fill": return "Energy"
        case "flame.fill": return "Burn"
        case "leaf.fill": return "Nature"
        case "sun.max.fill": return "Morning"
        case "moon.fill": return "Sleep"
        case "timer": return "Timer"
        case "alarm.fill": return "Wake up"
        case "pencil": return "Write"
        case "checkmark.seal.fill": return "Goal"
        case "cart.fill": return "Shopping"
        case "dumbbell.fill": return "Workout"
        case "bicycle": return "Cycling"
        case "medal.fill": return "Achievement"
        case "music.note": return "Music"
        case "paintbrush.fill": return "Art"
        default: return "Custom"
        }
    }
    
    private func createGoal() -> Goal {
        var reminders: [Reminder] = []
        if addReminder {
            reminders.append(Reminder(time: reminderTime, repeatDaily: true))
        }

        let finalStart = startDate
        let finalDeadline = startDate > deadline
            ? Calendar.current.date(byAdding: .day, value: 7, to: startDate)
            : deadline

        let newGoal = Goal(
            title: goalTitle.isEmpty ? "未命名目標" : goalTitle,
            icon: selectedIcon,
            colorHex: selectedColorHex,
            startDate: finalStart,
            deadline: finalDeadline ?? deadline,
            reminders: reminders,
            subTasks: [],
            createdAt: Date()
        )
        store.addGoal(newGoal)

        if addReminder {
            NotificationManager.scheduleDailyReminder(id: newGoal.id.uuidString,
                                                      title: newGoal.title,
                                                      at: reminderTime)
        }

        let thread = ChatThread(
            title: newGoal.title,
            messages: [
                .init(
                    role: .assistant,
                    text: "Hi! Tell me more about **\(newGoal.title)** and I’ll break it down into actionable steps for you. ✨"
                )
            ],
            relatedGoalID: newGoal.id
        )
        store.upsertThread(thread)

        Task {
            try? await SupabaseRepository.shared.upsertConversation(thread)
            if let first = thread.messages.first {
                try? await SupabaseRepository.shared.upsertMessage(first, conversationId: thread.id)
            }
        }

        return newGoal
    }

    private func newGoalStartDate(_ goal: Goal) -> Date? {
        // 之後 Goal 有 startDate 欄位就直接 goal.startDate
        // 這個方法先留著，避免在你更新 Models 前編譯失敗
        // 臨時回傳本地的 startDate
        return startDate
    }
    
    private func composeInitialUserMessage(title: String, description: String, startDate: Date?, deadline: Date?) -> String {
        var parts: [String] = []
        parts.append("Goal: \(title)")
        if description.isEmpty == false {
            parts.append("Description: \(description)")
        }
        if let startDate {
            parts.append("Start Date: \(startDate.formatted(.dateTime.year().month().day()))")
        }
        if let deadline {
            parts.append("Deadline: \(deadline.formatted(.dateTime.year().month().day()))")
        }
        parts.append("Please break down this goal into actionable tasks considering my preferences and workstyle.")
        return parts.joined(separator: "\n")
    }
    
    private struct DatePickerSheet: View {
        @Environment(\.dismiss) private var dismiss
        @Binding var date: Date

        var body: some View {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker(
                        "Select a deadline",
                        selection: $date,
                        in: Date()...,                   // 不可選今天以前
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()

                    Spacer()
                }
                .navigationTitle("Choose Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    private struct StartDatePickerSheet: View {
        @Environment(\.dismiss) private var dismiss
        @Binding var date: Date

        var body: some View {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    DatePicker(
                        "Select a start date",
                        selection: $date,
                        in: Date()...,                   // 不可選今天以前
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()

                    Spacer()
                }
                .navigationTitle("Start Date")
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

private func colorName(for hex: String) -> LocalizedStringKey {
    switch hex {
    case "#BDCFFF": return "Skyblue"
    case "#B8C0FF": return "Blue"
    case "#C8B6FE": return "Purple"
    case "#E7C5FF": return "Pink Purple"
    case "#FED5FF": return "Pink"
    default: return "Custom"
    }
}

struct IconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: String

    private let icons = [
        "figure.walk", "drop.fill", "brain.head.profile", "heart.fill", "book.fill",
        "bolt.fill", "flame.fill", "leaf.fill", "sun.max.fill", "moon.fill",
        "timer", "alarm.fill", "pencil", "checkmark.seal.fill", "cart.fill",
        "dumbbell.fill", "bicycle", "medal.fill", "music.note", "paintbrush.fill"
    ]

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(icons, id: \.self) { name in
                        Button {
                            selected = name
                            dismiss()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(name == selected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                                Image(systemName: name)
                                    .font(.title2)
                                    .foregroundStyle(name == selected ? Color.accentColor : .primary)
                            }
                            .frame(width: 56, height: 56)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Choose an Icon")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ThemeColorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedHex: String

    private let palette: [(name: String, hex: String)] = [
        ("Skyblue", "#BDCFFF"),
        ("Blue",   "#B8C0FF"),
        ("Purple",  "#C8B6FE"),
        ("Pink Purple", "#E7C5FF"),
        ("Pink",    "#FED5FF"),
    ]

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: 14)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(palette, id: \.hex) { c in
                            Button {
                                selectedHex = c.hex
                                dismiss()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: c.hex) ?? .gray)
                                        .frame(width: 48, height: 48)

                                    if selectedHex == c.hex {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.white)
                                            .shadow(radius: 2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                }

                Divider().padding(.horizontal)
                SystemColorPickerRow(selectedHex: $selectedHex)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            .navigationTitle("Choose a Color")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SystemColorPickerRow: View {
    @Binding var selectedHex: String
    @State private var tempColor: Color = .orange

    var body: some View {
        HStack(spacing: 12) {
            ColorPicker("Custom color", selection: $tempColor, supportsOpacity: false)
            Spacer()
            Button("Use") {
                selectedHex = tempColor.toHex() ?? selectedHex
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
