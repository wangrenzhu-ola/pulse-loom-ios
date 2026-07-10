import SwiftUI

struct TimingRibbon: View {
    let deviations: [Int]
    let highlightedRange: ClosedRange<Int>?

    init(deviations: [Int], highlightedRange: ClosedRange<Int>? = nil) {
        self.deviations = deviations
        self.highlightedRange = highlightedRange
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(deviations.enumerated()), id: \.offset) { index, deviation in
                TimingCell(
                    index: index,
                    deviation: deviation,
                    isHighlighted: highlightedRange?.contains(index) == true
                )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Timing Ribbon. \(accessibilitySummary)")
    }

    private var accessibilitySummary: String {
        deviations.enumerated().map { index, deviation in
            "Beat \(index + 1), \(TimingStatus.status(for: deviation).shortLabel), \(abs(deviation)) milliseconds"
        }.joined(separator: ". ")
    }
}

private struct TimingCell: View {
    let index: Int
    let deviation: Int
    let isHighlighted: Bool

    private var status: TimingStatus { TimingStatus.status(for: deviation) }
    private var color: Color {
        switch status {
        case .early: return LoomPalette.amber
        case .onTime: return LoomPalette.mint
        case .late: return LoomPalette.coral
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isHighlighted ? Color.white : color, lineWidth: isHighlighted ? 2 : 1)
                    )
                switch status {
                case .early:
                    Image(systemName: "arrowtriangle.left.fill")
                        .font(.caption.weight(.bold))
                        .foregroundColor(color)
                case .onTime:
                    Circle().fill(color).frame(width: 11, height: 11)
                case .late:
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.caption.weight(.bold))
                        .foregroundColor(color)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            Text(status == .onTime ? "ON" : status == .early ? "EARLY" : "LATE")
                .font(.caption2.weight(.bold))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .accessibilityHidden(true)
    }
}

struct BeatLoom: View {
    let beatCells: [BeatCell]
    let completed: Int
    let activeIndex: Int?

    var body: some View {
        wrappedGrid
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Beat progress: \(min(completed, beatCells.count)) of \(beatCells.count) beats complete")
    }

    private var wrappedGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 40)), count: 4), spacing: 8) {
            ForEach(beatCells) { cell in beatCell(cell) }
        }
    }

    private func beatCell(_ cell: BeatCell) -> some View {
        let completed = cell.order < completed
        let active = cell.order == activeIndex
        return ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(completed ? LoomPalette.mint.opacity(0.25) : LoomPalette.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(active ? LoomPalette.amber : completed ? LoomPalette.mint : LoomPalette.fog.opacity(0.45), lineWidth: active ? 3 : 1)
                )
            VStack(spacing: 2) {
                Text("\(cell.order + 1)")
                    .font(.caption.weight(.heavy))
                Image(systemName: cell.accent ? "bolt.fill" : "circle.fill")
                    .font(.caption2)
                    .foregroundColor(cell.accent ? LoomPalette.amber : LoomPalette.fog)
            }
        }
        .frame(minWidth: 38, minHeight: 48)
        .accessibilityHidden(true)
    }
}

struct EmptyLoomIllustration: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundColor(index == 2 ? LoomPalette.mint.opacity(0.9) : LoomPalette.fog.opacity(0.65))
                    .frame(width: 38, height: 48)
            }
        }
        .accessibilityHidden(true)
    }
}

struct MeterIcon: View {
    let meter: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LoomPalette.mint.opacity(0.14))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(LoomPalette.mint.opacity(0.7)))
            VStack(spacing: 0) {
                ForEach(meter.split(separator: "/").map(String.init), id: \.self) { number in
                    Text(number)
                        .font(.caption2.weight(.heavy))
                }
            }
        }
        .frame(width: 42, height: 42)
        .accessibilityLabel("\(meter) meter")
    }
}

struct SaveToast: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(LoomPalette.mint.opacity(0.2)))
            .overlay(Capsule().stroke(LoomPalette.mint.opacity(0.8)))
            .accessibilityLabel(message)
    }
}
