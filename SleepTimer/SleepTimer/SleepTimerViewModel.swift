import Foundation
import UserNotifications
import ServiceManagement

struct DaySchedule: Codable, Equatable {
    var isEnabled: Bool
    var hour: Int
    var minute: Int

    static var disabled: DaySchedule {
        DaySchedule(isEnabled: false, hour: 22, minute: 0)
    }
}

@MainActor
class SleepTimerViewModel: ObservableObject {
    // Weekly schedule (0 = Monday, 6 = Sunday)
    @Published var weeklySchedule: [DaySchedule] = Array(repeating: .disabled, count: 7) {
        didSet { saveSchedule() }
    }

    @Published var isTimerActive = false
    @Published var timeRemaining: TimeInterval = 0
    @Published var launchAtLogin: Bool = false {
        didSet { updateLaunchAtLogin() }
    }

    private var timer: Timer?
    private var targetDate: Date?
    private var hasShownWarning = false
    private var lastTriggeredDate: Date?  // Prevent double-triggering

    static let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    var timeRemainingFormatted: String {
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var nextScheduledTime: String? {
        guard let next = calculateNextScheduledDate() else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE HH:mm"
        return formatter.string(from: next)
    }

    init() {
        loadSchedule()
        loadLaunchAtLogin()
        scheduleNextTimer()
    }

    // MARK: - Persistence

    private func saveSchedule() {
        if let data = try? JSONEncoder().encode(weeklySchedule) {
            UserDefaults.standard.set(data, forKey: "weeklySchedule")
        }
        // Reschedule when settings change
        if !isTimerActive {
            scheduleNextTimer()
        }
    }

    private func loadSchedule() {
        if let data = UserDefaults.standard.data(forKey: "weeklySchedule"),
           let schedule = try? JSONDecoder().decode([DaySchedule].self, from: data),
           schedule.count == 7 {
            weeklySchedule = schedule
        }
    }

    // MARK: - Launch at Login

    private func loadLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert on failure
            DispatchQueue.main.async {
                self.launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    // MARK: - Schedule Calculator

    private func currentWeekday() -> Int {
        let calendarWeekday = Calendar.current.component(.weekday, from: Date())
        return (calendarWeekday + 5) % 7  // Convert: 1(Sun)->6, 2(Mon)->0, etc.
    }

    private func calculateNextScheduledDate() -> Date? {
        let calendar = Calendar.current
        let now = Date()

        // Check up to 8 days ahead (today + 7 days)
        for dayOffset in 0..<8 {
            let checkDate = calendar.date(byAdding: .day, value: dayOffset, to: now)!
            let weekday = (currentWeekday() + dayOffset) % 7
            let schedule = weeklySchedule[weekday]

            guard schedule.isEnabled else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: checkDate)
            components.hour = schedule.hour
            components.minute = schedule.minute
            components.second = 0

            guard let scheduledDate = calendar.date(from: components) else { continue }

            // Must be in the future (at least 10 seconds from now)
            if scheduledDate > now.addingTimeInterval(10) {
                return scheduledDate
            }
        }

        return nil
    }

    // MARK: - Timer Control

    func scheduleNextTimer() {
        guard let nextDate = calculateNextScheduledDate() else { return }

        // Prevent scheduling the same time twice
        if let last = lastTriggeredDate,
           Calendar.current.isDate(last, equalTo: nextDate, toGranularity: .minute) {
            return
        }

        startTimer(targetDate: nextDate)
    }

    private func startTimer(targetDate target: Date) {
        timer?.invalidate()

        targetDate = target
        hasShownWarning = false
        isTimerActive = true
        updateTimeRemaining()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func cancelTimer() {
        timer?.invalidate()
        timer = nil
        targetDate = nil
        isTimerActive = false
        timeRemaining = 0
        hasShownWarning = false
    }

    func snooze() {
        guard let current = targetDate else { return }
        targetDate = current.addingTimeInterval(5 * 60)  // Add 5 minutes
        hasShownWarning = false  // Reset warning so it shows again
        updateTimeRemaining()
    }

    private func tick() {
        updateTimeRemaining()

        guard timeRemaining > 0 else {
            executeSleep()
            return
        }

        // Show warning at 1 minute remaining
        if timeRemaining <= 60 && !hasShownWarning {
            hasShownWarning = true
            showWarningNotification()
        }
    }

    private func updateTimeRemaining() {
        guard let target = targetDate else {
            timeRemaining = 0
            return
        }
        timeRemaining = max(0, target.timeIntervalSinceNow)
    }

    private func showWarningNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Sleep Timer"
        content.body = "Your computer will sleep in 1 minute"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "sleep-warning",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func executeSleep() {
        // Remember this trigger time to prevent double-scheduling
        lastTriggeredDate = targetDate

        cancelTimer()

        // Schedule the next occurrence
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.scheduleNextTimer()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["sleepnow"]

        try? process.run()
    }
}
