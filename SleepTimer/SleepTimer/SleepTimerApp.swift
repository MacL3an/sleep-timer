import SwiftUI
import UserNotifications

@main
struct SleepTimerApp: App {
    @StateObject private var viewModel = SleepTimerViewModel()

    init() {
        // Request notification permissions on launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(viewModel: viewModel)
        } label: {
            Image(systemName: viewModel.isTimerActive ? "moon.fill" : "moon")
        }
        .menuBarExtraStyle(.window)
    }
}
