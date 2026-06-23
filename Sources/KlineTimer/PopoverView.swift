import SwiftUI
import KlineCore

/// The popover panel: live readout, timeframe picker, toggles and quit.
struct PopoverView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var timer: TimerModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 4)

    private var timeString: String { CandleClock.format(secondsLeft: timer.secondsLeft) }
    private var isFinalMinute: Bool {
        CandleClock.isFinalMinute(timeframe: settings.timeframe, secondsLeft: timer.secondsLeft)
    }

    var body: some View {
        VStack(spacing: 0) {
            readout
            Divider()
            timeframePicker
            Divider()
            toggles
            Divider()
            quit
        }
        .frame(width: 288)
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Current \(settings.timeframe.label) candle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(timeString)
                    .font(.system(size: 44, weight: .semibold).monospacedDigit())
                    .foregroundStyle(isFinalMinute ? Color.red : Color.primary)
                Text("left")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 7)
            Text("until the \(settings.timeframe.label) candle closes")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private var timeframePicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Timeframe")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Timeframe.allCases) { tf in
                    let selected = settings.timeframe == tf
                    Button { settings.timeframe = tf } label: {
                        Text(tf.label)
                            .font(.system(size: 13, weight: selected ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(selected ? Color.accentColor : Color.primary.opacity(0.08))
                            .foregroundStyle(selected ? Color.white : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var toggles: some View {
        VStack(spacing: 0) {
            row(
                title: "Show countdown in menu bar",
                subtitle: "Off shows just the icon",
                isOn: $settings.showCountdown
            )
            Divider()
            row(
                title: "Voice / chime on close",
                subtitle: "Short beep when candle ends",
                isOn: Binding(
                    get: { settings.chimeOnClose },
                    // Preview the beep the moment it is switched on, so the
                    // setting confirms what to expect instead of staying silent
                    // until the next candle close.
                    set: { settings.chimeOnClose = $0; if $0 { Chime.play() } }
                )
            )
        }
        .padding(.horizontal, 18)
    }

    private func row(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13))
                Text(subtitle).font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.accentColor)
        }
        .padding(.vertical, 9)
    }

    private var quit: some View {
        Button { NSApplication.shared.terminate(nil) } label: {
            HStack {
                Text("Quit Kline Timer")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("⌘Q")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("q")
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }
}
