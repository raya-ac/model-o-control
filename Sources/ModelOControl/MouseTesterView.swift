import AppKit
import ModelOCore
import SwiftUI

struct MouseTesterView: View {
    @StateObject private var monitor = MouseEventMonitor()

    var body: some View {
        PageScaffold(
            title: "Mouse Tester",
            subtitle: "Live mouse-only input feedback. Nothing here is recorded or written onboard."
        ) {
            HStack(spacing: 50) {
                ModelOMouseVisual(
                    color: monitor.pressedButtons.isEmpty ? Color.accentColor : .pink,
                    effect: .single,
                    size: 260,
                    brightness: monitor.pressedButtons.isEmpty ? 2 : 4,
                    speed: 1
                )
                .frame(width: 310, height: 315)
                .animation(.easeOut(duration: 0.12), value: monitor.pressedButtons)

                VStack(spacing: 0) {
                    TesterMetric(value: "\(monitor.observedRate)", unit: "events/s", label: "Observed movement")
                    Divider()
                    TesterMetric(value: "\(monitor.peakRate)", unit: "events/s", label: "Session peak")
                    Divider()
                    TesterMetric(value: "\(monitor.clicksPerSecond)", unit: "clicks/s", label: "Current click rate")
                    Divider()
                    TesterMetric(value: monitor.lastClickIntervalText, unit: "ms", label: "Last click interval")
                }
                .frame(maxWidth: 320)
            }
            .frame(maxWidth: .infinity)

            SettingSection("Button check", detail: "Press each physical button") {
                HStack(spacing: 10) {
                    ButtonIndicator(label: "Left", number: 0, count: monitor.buttonCounts[0, default: 0], pressed: monitor.pressedButtons.contains(0))
                    ButtonIndicator(label: "Right", number: 1, count: monitor.buttonCounts[1, default: 0], pressed: monitor.pressedButtons.contains(1))
                    ButtonIndicator(label: "Wheel", number: 2, count: monitor.buttonCounts[2, default: 0], pressed: monitor.pressedButtons.contains(2))
                    ButtonIndicator(label: "Back", number: 3, count: monitor.buttonCounts[3, default: 0], pressed: monitor.pressedButtons.contains(3))
                    ButtonIndicator(label: "Forward", number: 4, count: monitor.buttonCounts[4, default: 0], pressed: monitor.pressedButtons.contains(4))
                }
            }

            SettingSection("Movement history", detail: "Last 12 seconds") {
                RateGraph(values: monitor.rateHistory, peak: max(1, monitor.peakRate))
                    .frame(height: 92)
            }

            SettingSection("Sensor path", detail: "Relative movement · session only") {
                HStack(spacing: 28) {
                    MotionPathView(points: monitor.pathPoints)
                        .frame(height: 150)
                    VStack(spacing: 0) {
                        TesterMetric(value: monitor.horizontalTravelText, unit: "pt", label: "Horizontal travel")
                        Divider()
                        TesterMetric(value: monitor.verticalTravelText, unit: "pt", label: "Vertical travel")
                        Divider()
                        TesterMetric(value: monitor.maxSpeedText, unit: "pt/s", label: "Peak pointer speed")
                        Divider()
                        TesterMetric(value: "\(monitor.microMovements)", unit: "events", label: "Micro-movements")
                    }
                    .frame(width: 230)
                }
            }

            SettingSection("Session") {
                HStack(spacing: 34) {
                    SessionMetric(value: "\(monitor.clickCount)", label: "Clicks")
                    SessionMetric(value: "\(monitor.doubleClickCount)", label: "Double-clicks")
                    SessionMetric(value: monitor.travelText, label: "Travel points")
                    SessionMetric(value: "\(monitor.scrollEvents)", label: "Scroll events")
                    SessionMetric(value: monitor.durationText, label: "Duration")
                }
            }

            HStack {
                Label("The monitor exists only while this page is open and subscribes to mouse events—not keyboard input.", systemImage: "hand.raised")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Copy results") { monitor.copyResults() }
                    .buttonStyle(.bordered)
                Button("Reset session") { monitor.reset() }
                    .buttonStyle(.bordered)
            }
        }
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }
}

private struct SessionMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TesterMetric: View {
    let value: String
    let unit: String
    let label: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value)
                        .font(.system(size: 25, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText())
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 13)
    }
}

private struct ButtonIndicator: View {
    let label: String
    let number: Int
    let count: Int
    let pressed: Bool

    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(pressed ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.04))
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(pressed ? Color.accentColor : Color.primary.opacity(0.09), lineWidth: pressed ? 1.5 : 1)
                Circle()
                    .fill(pressed ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: pressed ? 13 : 8, height: pressed ? 13 : 8)
                    .shadow(color: pressed ? Color.accentColor.opacity(0.7) : .clear, radius: 6)
            }
            .frame(height: 54)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
            Text("B\(number + 1) · \(count)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy(duration: 0.13), value: pressed)
    }
}

private struct RateGraph: View {
    let values: [Int]
    let peak: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
                Path { path in
                    guard values.count > 1 else { return }
                    for (index, value) in values.enumerated() {
                        let x = proxy.size.width * CGFloat(index) / CGFloat(max(1, values.count - 1))
                        let y = proxy.size.height - (proxy.size.height * CGFloat(value) / CGFloat(peak))
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .shadow(color: Color.accentColor.opacity(0.45), radius: 5)
                .padding(8)
            }
        }
        .accessibilityLabel("Movement event-rate history")
    }
}

private struct MotionPathView: View {
    let points: [CGPoint]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
                Path { path in
                    guard points.count > 1 else { return }
                    let minX = points.map(\.x).min() ?? 0
                    let maxX = points.map(\.x).max() ?? 1
                    let minY = points.map(\.y).min() ?? 0
                    let maxY = points.map(\.y).max() ?? 1
                    let rangeX = max(1, maxX - minX)
                    let rangeY = max(1, maxY - minY)
                    for (index, point) in points.enumerated() {
                        let x = 10 + ((point.x - minX) / rangeX) * (proxy.size.width - 20)
                        let y = 10 + ((point.y - minY) / rangeY) * (proxy.size.height - 20)
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(
                    LinearGradient(colors: [.cyan, Color.accentColor, .pink], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color.accentColor.opacity(0.35), radius: 4)
            }
        }
        .accessibilityLabel("Relative pointer movement path")
    }
}

private struct MouseSample: Sendable {
    enum Kind: Sendable { case down, up, movement, scroll, ignored }
    let kind: Kind
    let button: Int
    let deltaX: Double
    let deltaY: Double
    let timestamp: TimeInterval

    init(_ event: NSEvent) {
        button = event.buttonNumber
        deltaX = event.deltaX
        deltaY = event.deltaY
        timestamp = event.timestamp
        kind = switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown: .down
        case .leftMouseUp, .rightMouseUp, .otherMouseUp: .up
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged: .movement
        case .scrollWheel: .scroll
        default: .ignored
        }
    }
}

@MainActor
private final class MouseEventMonitor: ObservableObject {
    @Published var pressedButtons: Set<Int> = []
    @Published var observedRate = 0
    @Published var peakRate = 0
    @Published var clickCount = 0
    @Published var clicksPerSecond = 0
    @Published var doubleClickCount = 0
    @Published var lastClickInterval = 0.0
    @Published var travel = 0.0
    @Published var scrollDirection = "—"
    @Published var scrollEvents = 0
    @Published var buttonCounts: [Int: Int] = [:]
    @Published var rateHistory: [Int] = []
    @Published var sessionDuration: TimeInterval = 0
    @Published var pathPoints: [CGPoint] = [.zero]
    @Published var horizontalTravel = 0.0
    @Published var verticalTravel = 0.0
    @Published var maxSpeed = 0.0
    @Published var microMovements = 0

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var timer: Timer?
    private var movementTimes: [TimeInterval] = []
    private var clickTimes: [TimeInterval] = []
    private var lastScrollAt: TimeInterval = 0
    private var lastClickAt: TimeInterval = 0
    private var lastClickButton = -1
    private var startedAt: TimeInterval = 0
    private var lastMovementAt: TimeInterval = 0
    private var pathPosition = CGPoint.zero

    var travelText: String {
        travel >= 10_000 ? String(format: "%.1fk", travel / 1_000) : String(Int(travel.rounded()))
    }

    var lastClickIntervalText: String {
        lastClickInterval > 0 ? String(Int(lastClickInterval.rounded())) : "—"
    }

    var durationText: String {
        let seconds = Int(sessionDuration)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var horizontalTravelText: String { compact(horizontalTravel) }
    var verticalTravelText: String { compact(verticalTravel) }
    var maxSpeedText: String { compact(maxSpeed) }

    func start() {
        guard globalMonitor == nil else { return }
        startedAt = ProcessInfo.processInfo.systemUptime
        let mask: NSEvent.EventTypeMask = [
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp, .mouseMoved,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel
        ]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            let sample = MouseSample(event)
            Task { @MainActor [weak self] in self?.consume(sample) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            let sample = MouseSample(event)
            Task { @MainActor [weak self] in self?.consume(sample) }
            return event
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        timer?.invalidate()
        timer = nil
        pressedButtons.removeAll()
        observedRate = 0
        clicksPerSecond = 0
    }

    func reset() {
        clickCount = 0
        clicksPerSecond = 0
        doubleClickCount = 0
        lastClickInterval = 0
        peakRate = 0
        travel = 0
        scrollDirection = "—"
        scrollEvents = 0
        buttonCounts.removeAll()
        rateHistory.removeAll()
        pathPoints = [.zero]
        horizontalTravel = 0
        verticalTravel = 0
        maxSpeed = 0
        microMovements = 0
        pathPosition = .zero
        lastMovementAt = 0
        startedAt = ProcessInfo.processInfo.systemUptime
        sessionDuration = 0
        movementTimes.removeAll()
        clickTimes.removeAll()
        lastClickAt = 0
        lastClickButton = -1
        observedRate = 0
    }

    private func consume(_ sample: MouseSample) {
        switch sample.kind {
        case .down:
            pressedButtons.insert(sample.button)
            clickCount += 1
            buttonCounts[sample.button, default: 0] += 1
            if lastClickAt > 0 {
                lastClickInterval = (sample.timestamp - lastClickAt) * 1_000
                if sample.button == lastClickButton,
                   sample.timestamp - lastClickAt <= NSEvent.doubleClickInterval {
                    doubleClickCount += 1
                }
            }
            lastClickAt = sample.timestamp
            lastClickButton = sample.button
            clickTimes.append(sample.timestamp)
            updateClickRate(now: sample.timestamp)
        case .up:
            pressedButtons.remove(sample.button)
        case .movement:
            let distance = hypot(sample.deltaX, sample.deltaY)
            travel += distance
            horizontalTravel += abs(sample.deltaX)
            verticalTravel += abs(sample.deltaY)
            if lastMovementAt > 0 {
                let elapsed = max(0.001, sample.timestamp - lastMovementAt)
                maxSpeed = max(maxSpeed, distance / elapsed)
            }
            lastMovementAt = sample.timestamp
            if distance > 0, distance < 2 { microMovements += 1 }
            pathPosition.x += sample.deltaX
            pathPosition.y += sample.deltaY
            pathPoints.append(pathPosition)
            if pathPoints.count > 240 { pathPoints.removeFirst(pathPoints.count - 240) }
            movementTimes.append(sample.timestamp)
            updateRate(now: sample.timestamp)
        case .scroll:
            scrollEvents += 1
            scrollDirection = abs(sample.deltaY) >= abs(sample.deltaX)
                ? (sample.deltaY > 0 ? "↑" : "↓")
                : (sample.deltaX > 0 ? "→" : "←")
            lastScrollAt = sample.timestamp
        case .ignored:
            break
        }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        updateRate(now: now)
        updateClickRate(now: now)
        sessionDuration = max(0, now - startedAt)
        rateHistory.append(observedRate)
        if rateHistory.count > 60 { rateHistory.removeFirst(rateHistory.count - 60) }
        if lastScrollAt > 0, now - lastScrollAt > 0.7 { scrollDirection = "—" }
    }

    private func updateRate(now: TimeInterval) {
        movementTimes.removeAll { now - $0 > 1.0 }
        observedRate = movementTimes.count
        peakRate = max(peakRate, observedRate)
    }

    private func updateClickRate(now: TimeInterval) {
        clickTimes.removeAll { now - $0 > 1.0 }
        clicksPerSecond = clickTimes.count
    }


    func copyResults() {
        let text = """
        Model O mouse test
        Duration: \(durationText)
        Peak movement: \(peakRate) events/s
        Clicks: \(clickCount) · current \(clicksPerSecond)/s
        Double-clicks: \(doubleClickCount)
        Last click interval: \(lastClickIntervalText) ms
        Button counts: \((0...4).map { "B\($0 + 1)=\(buttonCounts[$0, default: 0])" }.joined(separator: ", "))
        Travel: \(travelText) points
        Horizontal / vertical: \(horizontalTravelText) / \(verticalTravelText) points
        Peak pointer speed: \(maxSpeedText) points/s
        Micro-movements: \(microMovements)
        Scroll events: \(scrollEvents)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func compact(_ value: Double) -> String {
        value >= 10_000 ? String(format: "%.1fk", value / 1_000) : String(Int(value.rounded()))
    }
}
