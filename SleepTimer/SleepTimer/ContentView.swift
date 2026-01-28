import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: SleepTimerViewModel
    @State private var showingSchedule = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Sleep Timer")
                .font(.headline)

            if viewModel.isTimerActive {
                // Active timer view
                VStack(spacing: 12) {
                    Text("Time until sleep")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(viewModel.timeRemainingFormatted)
                        .font(.system(size: 36, weight: .medium, design: .monospaced))

                    HStack(spacing: 12) {
                        Button("Snooze +5m") {
                            viewModel.snooze()
                        }
                        .buttonStyle(.bordered)

                        Button("Cancel") {
                            viewModel.cancelTimer()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
            }

            // Schedule view (always visible)
            VStack(spacing: 8) {
                Text("Weekly Schedule")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(0..<7, id: \.self) { day in
                    DayScheduleRow(
                        dayName: SleepTimerViewModel.dayNames[day],
                        schedule: $viewModel.weeklySchedule[day]
                    )
                }

                if let next = viewModel.nextScheduledTime, !viewModel.isTimerActive {
                    Text("Next: \(next)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 260)
    }
}

struct DayScheduleRow: View {
    let dayName: String
    @Binding var schedule: DaySchedule

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $schedule.isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)

            Text(dayName)
                .frame(width: 70, alignment: .leading)
                .foregroundColor(schedule.isEnabled ? .primary : .secondary)

            Spacer()

            HStack(spacing: 2) {
                TextField("", value: $schedule.hour, formatter: hourFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 36)
                    .multilineTextAlignment(.center)
                    .disabled(!schedule.isEnabled)

                Text(":")
                    .foregroundColor(schedule.isEnabled ? .primary : .secondary)

                TextField("", value: $schedule.minute, formatter: minuteFormatter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 36)
                    .multilineTextAlignment(.center)
                    .disabled(!schedule.isEnabled)
            }
            .opacity(schedule.isEnabled ? 1 : 0.5)
        }
    }

    private var hourFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.minimum = 0
        formatter.maximum = 23
        formatter.allowsFloats = false
        return formatter
    }

    private var minuteFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.minimum = 0
        formatter.maximum = 59
        formatter.allowsFloats = false
        formatter.minimumIntegerDigits = 2
        return formatter
    }
}
