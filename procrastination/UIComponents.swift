import SwiftUI
import UIKit

struct Pill: View {
    var text: LocalizedStringKey
    var color: Color = .blue
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct ProgressBar: View {
    var progress: Double // 0..1
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.15))
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor)
                    .frame(width: max(4, geo.size.width * progress))
            }
        }
        .frame(height: 12)
    }
}

struct Card<Content: View>: View {
    private let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding(16)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct SectionHeader: View {
    var title: String
    var actionTitle: String? = nil
    var action: (() -> Void)?
    var body: some View {
        HStack {
            Text(LocalizedStringKey(title))
                .font(.title3).bold()
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(LocalizedStringKey(actionTitle))
                        .font(.callout).bold()
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }
}

struct SegmentedTabs: View {
    enum Tab: String, CaseIterable, Identifiable {
        case all = "All", todo = "To-do", completed = "Completed"
        var id: String { rawValue }
    }
    @Binding var selection: Tab
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(Tab.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(4)
        .background(backgroundView)
    }
    
    private func tabButton(for tab: Tab) -> some View {
        Button(action: { selection = tab }) {
            Text(LocalizedStringKey(tab.rawValue))
                .font(.subheadline).bold()
                .foregroundStyle(textColor(for: tab))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(buttonBackground(for: tab))
        }
        .buttonStyle(.plain)
    }
    
    private func textColor(for tab: Tab) -> Color {
        selection == tab ? .themeBrown : .secondary
    }
    
    private func buttonBackground(for tab: Tab) -> some View {
        let backgroundColor = selection == tab ? Color.themeYellow: Color.gray.opacity(0.08)
        return Capsule().fill(backgroundColor)
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 14).fill(Color.gray.opacity(0.08))
    }
}

struct DayChip: View {
    var dayNumber: String
    var weekday: String
    var isSelected: Bool
    var body: some View {
        VStack(spacing: 6) {
            Text(dayNumber).font(.title3).bold()
            Text(weekday).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(width: 64, height: 84)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(isSelected ? Color.white : Color.white.opacity(0.6))
                .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.02), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? Color.themeBlue : Color.clear, lineWidth: 2)
        )
    }
}

struct ProgressBanner: View {
    var progress: Double   // 0...1
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey

    var body: some View {
        HStack(spacing: 16) {
            // 左側進度環
            ZStack {
                Circle()
                    .stroke(Color.themeYellow.opacity(0.3), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.themeYellow, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))%")
                    .font(.subheadline.bold())
                    .foregroundColor(.themeYellow)
            }
            .frame(width: 70, height: 70)

            // 右側兩行文字
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.themeYellow)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.themeYellow.opacity(0.85))
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#83c4ca"), // 淺藍
                    Color(hex: "#83c4ca").opacity(0.8) // 或稍微變淡一點
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
    }
}

struct ChallengeCard: View {
    var title: String
    var timeLeft: String
    var friendsJoined: String
    var progress: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .foregroundStyle(.blue)
                Text(title).bold()
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(Color.blue).frame(width: 22, height: 22)
                    Circle().fill(Color.purple).frame(width: 22, height: 22)
                    Text(friendsJoined).foregroundStyle(.secondary).font(.caption)
                }
            }
            Text(timeLeft).font(.caption).foregroundStyle(.secondary)
            ProgressBar(progress: progress)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.gray.opacity(0.1)))
    }
}

struct TaskRow: View {
    let icon: String
    let iconColor: Color          // 👈 這個要記得有
    let title: String
    let detail: String
    let isOn: Bool
    let toggle: () -> Void
    let onFail: (() -> Void)?
    let onDone: (() -> Void)?
    
    var body: some View {
        ZStack {
            // MARK: - 背後的 Fail / Done 按鈕（側滑用）
            if let onFail = onFail, let onDone = onDone {
                HStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Button("X Fail", action: onFail)
                            .font(.caption).bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .clipShape(Capsule())
                        
                        Button("✓ Done", action: onDone)
                            .font(.caption).bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                    .padding(.trailing, 16)
                }
            }
            
            // MARK: - 主內容卡片
            HStack(spacing: 14) {
                // 左側 icon（用 goal 的 colorHex 上色）
                ZStack {
                    Circle()
                        .stroke(iconColor.opacity(0.25), lineWidth: 6)
                    Circle()
                        .fill(iconColor.opacity(0.15))
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(width: 44, height: 44)
                
                // 中間文字
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(detail)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 右側完成按鈕
                Button(action: toggle) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isOn ? iconColor.opacity(0.15) : Color.gray.opacity(0.08))
                        
                        Image(systemName: isOn ? "checkmark" : "circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isOn ? iconColor : .secondary)
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.gray.opacity(0.10))
            )
        }
    }
}

// MARK: - BottomSheet（這裡有改）

/*struct BottomSheet: View {
    @Binding var isPresented: Bool
    var onSetNewGoal: () -> Void = {}
    var onSelectMood: (Int) -> Void = { _ in }
    var onCreateGroupGoal: () -> Void = {}   // 🆕 新增社群任務 callback*/
struct BottomSheet: View {
    @Binding var isPresented: Bool
    let onSetNewGoal: () -> Void
    let onSelectMood: (Int) -> Void
    let onCreateGroupGoal: () -> Void   // ❌ 不再給預設值

    
    private let emojis = ["😡","😞","😢","😆","🥰"]
    
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            
            VStack(spacing: 16) {
                // 1) Set a new goal（原本）
                Button {
                    isPresented = false
                    onSetNewGoal()
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle() .fill(Color.themeYellow.opacity(0.6))
                            Image(systemName: "flag.fill")
                                .foregroundStyle(Color(hex: "#f0bd44"))
                                .font(.title3)
                        }
                        .frame(width: 48, height: 48)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Set a new goal").font(.headline)
                            Text("AI breaks tasks for you!")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1)))
                }
                .buttonStyle(.plain)
                
                // 2) 🆕 Create a group goal（新增社群任務）
                Button {
                    print("👉 BottomSheet group button tapped")
                    isPresented = false
                    onCreateGroupGoal()
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(Color.themeYellow)
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(Color(hex: "#f0bd44"))
                                .font(.title3)
                        }
                        .frame(width: 48, height: 48)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Create a group goal").font(.headline)
                            Text("Invite friends & break it down together")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1)))
                }
                .buttonStyle(.plain)
                
                // 3) Add Mood（原本）
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Add Mood").font(.headline)
                            Text("How're you feeling?")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            ForEach(emojis.indices, id: \.self) { i in
                                Button {
                                    isPresented = false
                                    onSelectMood(i + 1)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text(emojis[i])
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(.secondarySystemBackground))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1)))
            }
        }
    }
}



struct OptionChip: View {
    let text: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.themeBlue.opacity(0.15) : Color(.secondarySystemBackground))
                )
                .overlay(
                    Capsule().stroke(isSelected ? Color.themeBlue : Color.gray.opacity(0.15), lineWidth: 1)
                )
                .foregroundStyle(isSelected ? Color.themeDarkBlue  : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// 單選題區塊（標題 + 選項群組），使用自動換行的 LazyVGrid
struct SingleChoiceQuestion<T: CaseIterable & Identifiable & RawRepresentable & Hashable>: View where T.AllCases == Array<T>, T.RawValue == String {
    let title: LocalizedStringKey
    let options: [T]
    @Binding var selection: T   // changed from T? to T

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 8, alignment: .leading)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(options) { opt in
                    OptionChip(
                        text: LocalizedStringKey(opt.rawValue),
                        isSelected: selection == opt,
                        action: { selection = opt }
                    )
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.12)))
    }
}
// MARK: - Group Goal helpers

extension Goal {
    var socialMode: SocialMode? {
        get { SocialMode(raw: socialModeRaw) }
        set { socialModeRaw = newValue?.rawValue }
    }
}
