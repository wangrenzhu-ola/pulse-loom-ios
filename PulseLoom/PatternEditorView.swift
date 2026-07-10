import SwiftUI
import UIKit

struct PatternEditorView: View {
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var store: PracticeStore
    let context: PatternEditorContext

    @State private var name: String
    @State private var bpm: Int
    @State private var meter: String
    @State private var cells: [BeatCell]
    @State private var isChanged = false
    @State private var savedMessage: String?
    @State private var validationMessage: String?

    init(context: PatternEditorContext) {
        self.context = context
        switch context {
        case .new:
            _name = State(initialValue: "Offbeat Warm-up")
            _bpm = State(initialValue: 92)
            _meter = State(initialValue: "4/4")
            _cells = State(initialValue: Self.defaultCells)
        case let .edit(pattern):
            _name = State(initialValue: pattern.name)
            _bpm = State(initialValue: pattern.bpm)
            _meter = State(initialValue: pattern.meter)
            _cells = State(initialValue: pattern.sortedCells)
        }
    }

    var body: some View {
        NavigationView {
            LoomScreen {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                        if let savedMessage { SaveToast(message: savedMessage) }
                        if let validationMessage {
                            Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundColor(LoomPalette.amber)
                        }
                        if let saveError = store.saveError {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Pattern not saved", systemImage: "exclamationmark.triangle.fill")
                                    .font(.headline)
                                    .foregroundColor(LoomPalette.amber)
                                Text(saveError)
                                    .font(.footnote)
                                    .foregroundColor(LoomPalette.fog)
                                HStack {
                                    Button("Retry", action: save)
                                        .buttonStyle(SecondaryLoomButtonStyle())
                                    Button("Copy pattern details", action: copyPatternDetails)
                                        .buttonStyle(SecondaryLoomButtonStyle())
                                }
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LoomPalette.amber.opacity(0.12)))
                        }
                        editForm
                        beatCellsSection
                        livePreview
                        Text("Touch timing is measured on this device only. No microphone or audio input is used.")
                            .font(.footnote)
                            .foregroundColor(LoomPalette.fog)
                        }
                        .padding(20)
                    }
                    Button(action: save) {
                        Text(isChanged ? "Save changes" : "Save pattern")
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(PrimaryLoomButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(LoomPalette.navy.opacity(0.97))
                    .accessibilityIdentifier("save-pattern")
                }
            }
            .navigationTitle(contextTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .onChange(of: name) { _ in isChanged = true }
        .onChange(of: bpm) { _ in isChanged = true }
        .onChange(of: meter) { _ in isChanged = true }
        .onChange(of: cells) { _ in isChanged = true }
    }

    private var contextTitle: String {
        switch context { case .new: return "New Pattern"; case .edit: return "Edit Pattern" }
    }

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Pattern details")
                .font(.headline)
            TextField("Pattern name", text: $name, onCommit: dismissKeyboard)
                .disableAutocorrection(true)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(LoomPalette.panel))
                .accessibilityLabel("Pattern name")

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Tempo")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(LoomPalette.fog)
                    Stepper("\(bpm) BPM", value: $bpm, in: 40...220, step: 1)
                        .font(.headline)
                        .accessibilityLabel("Tempo, \(bpm) beats per minute")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Meter")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(LoomPalette.fog)
                    Picker("Meter", selection: $meter) {
                        Text("4/4").tag("4/4")
                        Text("3/4").tag("3/4")
                        Text("6/8").tag("6/8")
                    }
                    .pickerStyle(.menu)
                    .accentColor(LoomPalette.mint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(LoomPalette.panel))
        }
    }

    private var beatCellsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Beat-cell loom")
                        .font(.headline)
                    Text("Toggle accents, add a subdivision, or remove a beat cell.")
                        .font(.footnote)
                        .foregroundColor(LoomPalette.fog)
                }
                Spacer()
                Button(action: addCell) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accentColor(LoomPalette.mint)
                .accessibilityLabel("Add beat cell")
            }

            ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(LoomPalette.mint)
                        .frame(width: 26)
                    Button(action: { toggleAccent(for: cell.id) }) {
                        Label(cell.accent ? "Accent" : "Regular", systemImage: cell.accent ? "bolt.fill" : "circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(cell.accent ? LoomPalette.amber : LoomPalette.fog)
                    }
                    Spacer(minLength: 0)
                    Text(cell.subdivision == 1 ? "Beat" : "Subdivided")
                        .font(.caption)
                        .foregroundColor(LoomPalette.fog)
                    Button(action: { removeCell(cell) }) {
                        Image(systemName: "minus.circle")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .disabled(cells.count <= 2)
                    .accessibilityLabel("Remove beat cell \(index + 1)")
                }
                .padding(.vertical, 6)
                Divider().overlay(LoomPalette.fog.opacity(0.2))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LoomPalette.panel))
    }

    private var livePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live preview")
                .font(.headline)
            BeatLoom(beatCells: cells, completed: 0, activeIndex: nil)
            Text("\(bpm) BPM · \(meter) · \(cells.count) beat cells")
                .font(.footnote)
                .foregroundColor(LoomPalette.fog)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LoomPalette.panel))
    }

    private func toggleAccent(for id: UUID) {
        guard let index = cells.firstIndex(where: { $0.id == id }) else { return }
        cells[index].accent.toggle()
    }

    private func addCell() {
        let nextOrder = cells.count
        cells.append(BeatCell(offset: Double(nextOrder), accent: false, subdivision: nextOrder.isMultiple(of: 2) ? 2 : 1, order: nextOrder))
    }

    private func removeCell(_ cell: BeatCell) {
        cells.removeAll { $0.id == cell.id }
        cells = cells.enumerated().map { index, cell in
            var updated = cell
            updated.order = index
            updated.offset = Double(index)
            return updated
        }
    }

    private func save() {
        dismissKeyboard()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationMessage = "Add a pattern name before saving."
            return
        }
        let id: UUID
        let createdAt: Date
        switch context {
        case .new:
            id = UUID()
            createdAt = Date()
        case let .edit(pattern):
            id = pattern.id
            createdAt = pattern.createdAt
        }
        let pattern = RhythmPattern(id: id, name: trimmedName, bpm: bpm, meter: meter, beatCells: cells, createdAt: createdAt)
        if store.save(pattern: pattern) {
            savedMessage = "Pattern saved"
            isChanged = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { presentationMode.wrappedValue.dismiss() }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func copyPatternDetails() {
        let accents = cells.enumerated().filter { $0.element.accent }.map { String($0.offset + 1) }.joined(separator: ", ")
        UIPasteboard.general.string = "\(name)\n\(bpm) BPM · \(meter)\n\(cells.count) beat cells\nAccents: \(accents.isEmpty ? "None" : accents)"
    }

    private static var defaultCells: [BeatCell] {
        (0..<8).map { index in
            BeatCell(offset: Double(index), accent: index == 0 || index == 4, subdivision: index == 3 ? 2 : 1, order: index)
        }
    }
}
