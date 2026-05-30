//
//  PomodoroView.swift
//  Text it
//
//  Lern-Timer mit Pomodoro-Modus und freiem Timer.
//

import SwiftUI
#if os(iOS) || os(visionOS)
import AudioToolbox
#endif

// MARK: - Timer-Snapshot (für NearbySync)

struct TimerSnap: Codable {
    var phase: String          // "idle" / "work" / "breakTime"
    var isRunning: Bool
    var remainingSeconds: Int
    var snapshotAt: Date
    var mode: String           // "pomodoro" / "custom"
    var workMinutes: Int
    var breakMinutes: Int
    var customMinutes: Int
    var pomodorosCompleted: Int
}

// MARK: - Timer-Zustand (Observable, außerhalb der View für Persistenz)

@MainActor
@Observable
final class StudyTimer {
    static let shared = StudyTimer()
    private init() {}

    enum Mode: String, CaseIterable {
        case pomodoro = "Pomodoro"
        case custom   = "Eigener Timer"
    }

    enum Phase: String {
        case idle, work, breakTime
    }

    var mode: Mode = .pomodoro
    var phase: Phase = .idle
    var isRunning: Bool = false

    var workMinutes: Int = 25
    var breakMinutes: Int = 5
    var customMinutes: Int = 30

    var remainingSeconds: Int = 0
    var pomodorosCompleted: Int = 0

    private var timerTask: Task<Void, Never>? = nil

    var totalSeconds: Int {
        switch mode {
        case .pomodoro: return (phase == .breakTime ? breakMinutes : workMinutes) * 60
        case .custom:   return customMinutes * 60
        }
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    var phaseLabel: String {
        switch phase {
        case .idle:      return mode == .pomodoro ? "Bereit" : "Bereit"
        case .work:      return "Fokus"
        case .breakTime: return "Pause"
        }
    }

    var phaseColor: Color {
        switch phase {
        case .idle:      return .secondary
        case .work:      return .orange
        case .breakTime: return .green
        }
    }

    func start() {
        guard !isRunning else { return }
        if phase == .idle || remainingSeconds == 0 {
            phase = .work
            remainingSeconds = totalSeconds
        }
        isRunning = true
        broadcastState()
        startTask()
    }

    func pause() {
        stopTask()
        broadcastState()
    }

    func reset() {
        stopTask()
        phase = .idle
        remainingSeconds = 0
        broadcastState()
    }

    func skipBreak() {
        guard phase == .breakTime else { return }
        stopTask()
        phase = .work
        remainingSeconds = workMinutes * 60
        start()
    }

    // Empfangene Remote-State anwenden (kein Broadcast zurück)
    func applyRemoteState(_ snap: TimerSnap) {
        let elapsed = max(0, Int(Date().timeIntervalSince(snap.snapshotAt)))
        let adjusted = snap.isRunning ? max(0, snap.remainingSeconds - elapsed) : snap.remainingSeconds

        if let m = Mode(rawValue: snap.mode) { mode = m }
        workMinutes = snap.workMinutes
        breakMinutes = snap.breakMinutes
        customMinutes = snap.customMinutes
        pomodorosCompleted = snap.pomodorosCompleted

        let newPhase: Phase
        switch snap.phase {
        case Phase.work.rawValue:      newPhase = .work
        case Phase.breakTime.rawValue: newPhase = .breakTime
        default:                       newPhase = .idle
        }

        stopTask()
        phase = newPhase
        remainingSeconds = adjusted

        if snap.isRunning && newPhase != .idle && adjusted > 0 {
            isRunning = true
            startTask()   // kein broadcastState hier → kein Echo-Loop
        }
    }

    // MARK: - Private Helpers

    private func stopTask() {
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
    }

    private func startTask() {
        timerTask = Task {
            while isRunning && remainingSeconds > 0 {
                do { try await Task.sleep(nanoseconds: 1_000_000_000) }
                catch { return }  // Task durch stopTask() abgebrochen
                guard isRunning else { return }
                remainingSeconds = max(0, remainingSeconds - 1)
                if remainingSeconds == 0 {
                    handlePhaseEnd()
                    return  // Alter Task endet hier — handlePhaseEnd startet neuen
                }
            }
        }
    }

    private func handlePhaseEnd() {
        // Aufgerufen von INNERHALB startTask() — kein stopTask() nötig,
        // der aufrufende Task endet via `return` direkt danach.
        // Kein broadcastState() — Autotransitionen laufen auf jedem Gerät unabhängig.
        if mode == .pomodoro {
            if phase == .work {
                pomodorosCompleted += 1
                playTimerSound(.breakStart)
                phase = .breakTime
                remainingSeconds = breakMinutes * 60
                startTask()      // neuer Task für Pause
            } else {
                playTimerSound(.focusStart)
                phase = .work
                remainingSeconds = workMinutes * 60
                startTask()      // neuer Task für nächsten Fokus
            }
        } else {
            playTimerSound(.focusStart)
            isRunning = false
            phase = .idle
            timerTask = nil
        }
    }

    private func broadcastState() {
        NearbySync.shared.sendTimerSync(makeSnap())
    }

    private func makeSnap() -> TimerSnap {
        TimerSnap(
            phase: phase.rawValue,
            isRunning: isRunning,
            remainingSeconds: remainingSeconds,
            snapshotAt: Date(),
            mode: mode.rawValue,
            workMinutes: workMinutes,
            breakMinutes: breakMinutes,
            customMinutes: customMinutes,
            pomodorosCompleted: pomodorosCompleted
        )
    }

    private enum SoundEvent { case focusStart, breakStart }

    private func playTimerSound(_ event: SoundEvent) {
        #if os(iOS) || os(visionOS)
        switch event {
        case .focusStart:  AudioServicesPlaySystemSound(1057)   // Ding (scharf)
        case .breakStart:  AudioServicesPlaySystemSound(1013)   // sanfter Ton
        }
        #elseif os(macOS)
        switch event {
        case .focusStart:  NSSound(named: .init("Glass"))?.play()
        case .breakStart:  NSSound(named: .init("Pop"))?.play()
        }
        #endif
    }
}

// MARK: - PomodoroView

struct PomodoroView: View {
    @State private var timer = StudyTimer.shared
    @State private var showSettings: Bool = false
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Lern-Timer")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Modus-Picker
            Picker("Modus", selection: $timer.mode) {
                ForEach(StudyTimer.Mode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .onChange(of: timer.mode) { _, _ in
                timer.reset()
            }

            // Zirkular-Anzeige
            ZStack {
                // Hintergrundkreis
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 12)
                    .frame(width: 180, height: 180)

                // Fortschrittskreis
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(
                        timer.phaseColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timer.progress)

                // Zeit + Phase
                VStack(spacing: 4) {
                    Text(timer.phase == .idle
                         ? formatTime(timer.mode == .pomodoro
                                      ? timer.workMinutes * 60
                                      : timer.customMinutes * 60)
                         : formatTime(timer.remainingSeconds))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    Text(timer.phaseLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(timer.phaseColor)

                    if timer.mode == .pomodoro && timer.pomodorosCompleted > 0 {
                        HStack(spacing: 3) {
                            ForEach(0..<min(timer.pomodorosCompleted, 8), id: \.self) { _ in
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(.vertical, 24)

            // Steuerungs-Buttons
            HStack(spacing: 20) {
                // Reset
                Button {
                    withAnimation(.spring(response: 0.3)) { timer.reset() }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.secondary.opacity(0.10)))
                }
                .buttonStyle(.plain)

                // Start / Pause (Haupt-Button)
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        if timer.isRunning { timer.pause() } else { timer.start() }
                    }
                } label: {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle().fill(timer.isRunning
                                          ? Color.orange
                                          : appState.theme.accent)
                        )
                }
                .buttonStyle(.plain)
                .scaleEffect(timer.isRunning ? 1.05 : 1.0)
                .animation(.spring(response: 0.3), value: timer.isRunning)

                // Pause überspringen (nur in Pomodoro-Pause)
                if timer.phase == .breakTime {
                    Button {
                        withAnimation(.spring(response: 0.3)) { timer.skipBreak() }
                    } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.secondary.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                } else {
                    // Platzhalter, damit Layout stabil bleibt
                    Color.clear.frame(width: 44, height: 44)
                }
            }
            .padding(.bottom, 20)

            // Einstellungen (inline, ausklappbar)
            if showSettings {
                Divider()
                settingsSection
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35), value: showSettings)
    }

    // MARK: - Einstellungen

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if timer.mode == .pomodoro {
                settingsRow(label: "Fokus (min)") {
                    Stepper("\(timer.workMinutes)", value: $timer.workMinutes, in: 1...90)
                }
                settingsRow(label: "Pause (min)") {
                    Stepper("\(timer.breakMinutes)", value: $timer.breakMinutes, in: 1...30)
                }
                Button("Pomodoros zurücksetzen") {
                    timer.pomodorosCompleted = 0
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                settingsRow(label: "Dauer (min)") {
                    Stepper("\(timer.customMinutes)", value: $timer.customMinutes, in: 1...180)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func settingsRow<C: View>(label: String, @ViewBuilder control: () -> C) -> some View {
        HStack {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            control()
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Toolbar-Button für Pomodoro

struct PomodoroToolbarButton: View {
    @State private var timer = StudyTimer.shared
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            appState.showPomodoro.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .foregroundStyle(timer.isRunning ? timer.phaseColor : Color.secondary)
                if timer.isRunning && timer.remainingSeconds > 0 {
                    Text(formatTime(timer.remainingSeconds))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(timer.phaseColor)
                }
            }
        }
        .help("Lern-Timer")
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
