//  ActivityView.swift — Past Activity (Dynamic, data-driven)
//  Drop-in replacement. Put this file alone; no duplicate model/store here.

import SwiftUI
import BCrypt

struct ActivityView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedPeriod: ActivityPeriod = .weekly
    @State private var periodOffset: Int = 0   // 0 = current, -1 = previous, -2 = two ago ...

    enum ActivityPeriod: String, CaseIterable, Identifiable {
        case weekly = "Weekly"
        case monthly = "Monthly"
        var id: String { rawValue }
    }

    var body: some View {
        let today = Date()
        let range = dateRange(for: selectedPeriod, offset: periodOffset, from: today)
        let stats = metrics(in: range, now: today)
        let bars = (selectedPeriod == .weekly)
            ? weeklyBars(weeksBack: 7, until: today)
            : monthlyBars(monthsBack: 7, until: today)

        return VStack(spacing: 0) {
            // Header
            HStack {
                Text("Activity")
                    .font(.largeTitle).bold()
                    .foregroundStyle(Color.themeBlue)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Period selector
                    HStack {
                        ForEach(ActivityPeriod.allCases) { p in
                            Button(action: {
                                selectedPeriod = p
                                periodOffset = 0
                            }) {
                                Text(LocalizedStringKey(p.rawValue))
                                    .font(.subheadline).bold()
                                    .foregroundStyle(selectedPeriod == p ? Color.black : .secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(selectedPeriod == p ? Color.themeBlue  : Color.gray.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }

                    // Date range + pager
                    HStack {
                        VStack(alignment: .leading) {
                            Text(titleForHeader(period: selectedPeriod, offset: periodOffset))
                                .bold()
                            Text(rangeTitle(start: range.start, end: range.end))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Button(action: { periodOffset -= 1 }) {
                                Image(systemName: "chevron.left")
                                    .foregroundStyle(Color.themeBlue)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color.gray.opacity(0.1)))
                            }
                            Button(action: { if periodOffset < 0 { periodOffset += 1 } }) {
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(periodOffset < 0 ? Color.themeBlue : Color.themeBlue)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color.gray.opacity(0.1)))
                            }
                            .disabled(periodOffset >= 0)
                        }
                    }

                    // Task Achievement Card
                    taskAchievementCard(stats: stats)

                    // Tasks Completed Card (bar chart)
                    tasksCompletedCard(
                        bars: bars,
                        caption: selectedPeriod == .weekly
                            ? "By week (current anchor ±\(bars.count-1))"
                            : "By month (current anchor ±\(bars.count-1))",
                        xLabels: barLabels(for: selectedPeriod, count: bars.count, until: today)
                    )

                    // Mood Card
                    moodCard(range: range)
                }
                .padding(.horizontal, 20)     // ✅ 統一外框間距
                .padding(.top, 20)
            }
        }
        .background(Color.gray.opacity(0.05).ignoresSafeArea()) // ✅ 不受安全區影響
    }
}

// MARK: - UI Cards
private extension ActivityView {
    @ViewBuilder
    func taskAchievementCard(stats: Metrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "eye").foregroundStyle(.black))

                VStack(alignment: .leading) {
                    Text("Task Achievement").bold()
                    Text("Summary").foregroundStyle(.secondary).font(.caption)
                }
                Spacer()
//                Image(systemName: "chevron.down")
//                    .foregroundStyle(.secondary)
//                    .frame(width: 32, height: 32)
//                    .background(Circle().fill(Color.gray.opacity(0.1)))
            }
            let statColumns: [GridItem] = [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ]

            LazyVGrid(columns: statColumns, spacing: 16) {
                StatItem(title: "SUCCESS RATE",
                         value: String(format: "%.0f%%", stats.successRate * 100),
                         color: .green)
                StatItem(title: "COMPLETED",
                         value: "\(stats.completed)",
                         color: .primary)
                StatItem(title: "BEST STREAK DAY",
                         value: "\(stats.bestStreakDays)",
                         color: .primary)
                StatItem(title: "FAILED",
                         value: "\(stats.failed)",
                         color: .red)
            }

        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        .frame(maxWidth: .infinity, alignment: .center)   // ✅ 與 Monthly 一致
    }

    @ViewBuilder
    func tasksCompletedCard(bars: [Int], caption: LocalizedStringKey, xLabels: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(.black))

                VStack(alignment: .leading) {
                    Text("Tasks Completed").bold()
                    Text(caption).foregroundStyle(.secondary).font(.caption)
                }
                Spacer()
                let badgeColor = Color(hex: "#FFD9D9")
                Text("🔥 Highest \(bars.max() ?? 0) tasks")
                    .font(.caption).bold()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(badgeColor)
                    )
                    .foregroundStyle(Color.red)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(bars.indices, id: \.self) { i in
                    let height = CGFloat(bars[i]) * 12 // 12pt per task
                    VStack(spacing: 6) {
                        Rectangle()
                            .fill(Color.themeBlue)
                            .frame(width: 22, height: max(6, height))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text(xLabels[i])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 40)
                            .minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(height: 140)
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        .frame(maxWidth: .infinity, alignment: .center)   // ✅ 與 Monthly 一致
    }

    @ViewBuilder
    func moodCard(range: (start: Date, end: Date)) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 48, height: 48)
                    .overlay(Text("😊").font(.title2))

                VStack(alignment: .leading) {
                    Text("Happy").bold()
                    Text("Mood in period").foregroundStyle(.secondary).font(.caption)
                }
                Spacer()
            }

            let moods = store.moods.filter { m in
                m.date >= range.start && m.date <= range.end
            }
            HStack(spacing: 12) {
                if moods.isEmpty {
                    Text("No mood logs in this period")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(moods) { m in
                        Text(emoji(for: m.moodScore))
                            .font(.title2)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1)))
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        .frame(maxWidth: .infinity, alignment: .center)   // ✅ 與 Monthly 一致
    }
}

// MARK: - Metrics & Helpers
private extension ActivityView {

    struct Metrics { let completed: Int; let failed: Int; let successRate: Double; let bestStreakDays: Int }

    func dateRange(for period: ActivityPeriod, offset: Int, from anchor: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        switch period {
        case .weekly:
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchor))!
            let start = cal.date(byAdding: .weekOfYear, value: offset, to: weekStart)!
            let end = cal.date(byAdding: .day, value: 6, to: start)!.endOfDay
            return (start.startOfDay, end)
        case .monthly:
            let comps = cal.dateComponents([.year, .month], from: anchor)
            let monthStart = cal.date(from: comps)!
            let start = cal.date(byAdding: .month, value: offset, to: monthStart)!
            let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)!.endOfDay
            return (start.startOfDay, end)
        }
    }

    // Success rate / Completed / Failed + Best Streak (strict: all tasks of the day completed)
    func metrics(in range: (start: Date, end: Date), now: Date) -> Metrics {
        let allSubs = store.goals.flatMap { $0.subTasks }
        let inRange = allSubs.filter { st in
            guard let d = st.dueDate else { return false }
            return d >= range.start && d <= range.end
        }

        let completed = inRange.filter { $0.isCompleted }.count
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)

        let failed = inRange.filter {
            guard let dueDate = $0.dueDate else { return false }
            return !($0.isCompleted) && dueDate < startOfToday
        }.count

        let denom = max(1, completed + failed)
        let rate = Double(completed) / Double(denom)

        // --- Strict best-streak: count a day only if ALL tasks due that day are completed ---
        let cal = Calendar.current
        let groupedByDay = Dictionary(grouping: inRange.compactMap { $0.dueDate?.startOfDay }) { $0 }
        let fullyCompletedDays: [Date] = groupedByDay.keys.sorted().filter { day in
            let tasksThatDay = inRange.filter { ($0.dueDate?.startOfDay ?? .distantPast) == day }
            return tasksThatDay.allSatisfy { $0.isCompleted }
        }

        var best = 0, cur = 0
        for (i, day) in fullyCompletedDays.enumerated() {
            if i == 0 { cur = 1; best = 1; continue }
            let prev = fullyCompletedDays[i-1]
            if cal.isDate(day, inSameDayAs: cal.date(byAdding: .day, value: 1, to: prev)!) {
                cur += 1
            } else {
                best = max(best, cur)
                cur = 1
            }
        }
        best = max(best, cur)

        return Metrics(completed: completed, failed: failed, successRate: rate, bestStreakDays: best)
    }

    // Weekly bars: counts of completed tasks per each of the last N weeks
    func weeklyBars(weeksBack: Int, until endDate: Date) -> [Int] {
        var counts = Array(repeating: 0, count: weeksBack)
        let cal = Calendar.current
        let endWeekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: endDate))!
        let startAnchor = cal.date(byAdding: .weekOfYear, value: -(weeksBack - 1), to: endWeekStart)!

        for st in store.goals.flatMap({ $0.subTasks }) where st.isCompleted {
            guard let d = st.dueDate else { continue }
            guard let diff = cal.dateComponents([.weekOfYear], from: startAnchor, to: d).weekOfYear else { continue }
            let idx = min(max(diff, 0), weeksBack - 1)
            counts[idx] += 1
        }
        return counts
    }

    // Monthly bars: counts of completed tasks per each of the last N months
    func monthlyBars(monthsBack: Int, until endDate: Date) -> [Int] {
        var counts = Array(repeating: 0, count: monthsBack)
        let cal = Calendar.current
        let endMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: endDate))!
        let startAnchor = cal.date(byAdding: .month, value: -(monthsBack - 1), to: endMonthStart)!

        for st in store.goals.flatMap({ $0.subTasks }) where st.isCompleted {
            guard let d = st.dueDate else { continue }
            let comps = cal.dateComponents([.month], from: startAnchor, to: d)
            guard let diff = comps.month else { continue }
            let idx = min(max(diff, 0), monthsBack - 1)
            counts[idx] += 1
        }
        return counts
    }

    func barLabels(for period: ActivityPeriod, count: Int, until endDate: Date) -> [String] {
        let cal = Calendar.current
        switch period {
        case .weekly:
            // start anchor is (count-1) weeks before current week start
            let endWeekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: endDate))!
            let start = cal.date(byAdding: .weekOfYear, value: -(count - 1), to: endWeekStart)!
            return (0..<count).map { i in
                let d = cal.date(byAdding: .weekOfYear, value: i, to: start)!
                let df = DateFormatter()
                df.setLocalizedDateFormatFromTemplate("MMM d")
                return df.string(from: d)
            }
        case .monthly:
            let endMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: endDate))!
            let start = cal.date(byAdding: .month, value: -(count - 1), to: endMonthStart)!
            return (0..<count).map { i in
                let d = cal.date(byAdding: .month, value: i, to: start)!
                let df = DateFormatter()
                df.setLocalizedDateFormatFromTemplate("MMM yyyy")
                return df.string(from: d)
            }
        }
    }

    func titleForHeader(period: ActivityPeriod, offset: Int) -> LocalizedStringKey {
        switch period {
        case .weekly:
            return offset == 0 ? "This week" : "\(-offset) week(s) ago"
            
        case .monthly:
            return offset == 0 ? "This month" : "\(-offset) month(s) ago"
        }
    }

    // Mood emoji mapping (1..5) aligned with Home
    func emoji(for score: Int) -> String {
        let map = ["😡","😞","😢","😆","🥰"] // 1..5
        let idx = max(1, min(5, score)) - 1
        return map[idx]
    }

    func rangeTitle(start: Date, end: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("MMM d")
        return "\(df.string(from: start)) - \(df.string(from: end))"
    }
}

// MARK: - Small reusable pieces
private struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(title)).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.title2).bold().foregroundStyle(color)
        }
    }
}



private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var endOfDay: Date { Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)! }
}

// MARK: - Preview
#Preview {
    let store = AppStore()
    return ActivityView().environmentObject(store)
}
