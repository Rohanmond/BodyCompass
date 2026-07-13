import Charts
import PhotosUI
import SwiftUI
import UIKit
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

struct HistoryView: View {
    @EnvironmentObject private var app: AppStore
    @EnvironmentObject private var training: TrainingStore
    @StateObject private var checkIns = ProgressCheckInStore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    weeklySummary
                    timeline
                    TrendChart(title: "Weight", unit: "kg", color: Theme.accent, values: chartValues(\.weightKg))
                    TrendChart(title: "Body fat", unit: "%", color: Theme.warning, values: chartValues(\.bodyFatPercentage), target: 12)
                    progressSection
                    Text("Photos are used only for analysis and are never added to history. Visual estimates remain broad, non-medical ranges.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("History")
        }
    }

    private var weeklySummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 days").font(.title2.bold())
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricCard(title: "Adherence", value: percent(app.weeklyAdherence), caption: "daily schedule", systemImage: "checkmark.circle")
                MetricCard(title: "Protein", value: "\(weeklyProtein) g", caption: "meals logged", systemImage: "fork.knife")
                MetricCard(title: "Calories", value: "\(weeklyCalories)", caption: "meals logged", systemImage: "flame")
                MetricCard(title: "Sleep", value: averageSleep, caption: "nightly average", systemImage: "bed.double")
                MetricCard(title: "Strength", value: "\(strengthDays)", caption: "days logged", systemImage: "dumbbell")
                MetricCard(title: "Swimming", value: "\(swimDays)", caption: "days logged", systemImage: "figure.pool.swim")
            }
        }
    }

    private var timeline: some View {
        let projection = app.weeklyProjection
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("12% projection", systemImage: "scope")
                    .font(.headline)
                Spacer()
                Text("\(projection.optimumWeeks) weeks")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.accent)
            }
            Text("Target weight \(projection.targetWeightKg.formatted(.number.precision(.fractionLength(1)))) kg • about \(projection.weeklyLossTargetKg.formatted(.number.precision(.fractionLength(2)))) kg/week")
                .font(.callout)
            Text(projection.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly photos").font(.title2.bold())
                    Text("Front, side, and back")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                NavigationLink {
                    ProgressCaptureView(store: checkIns)
                } label: {
                    Label("Check in", systemImage: "camera")
                }
                .buttonStyle(.borderedProminent)
            }

            if checkIns.checkIns.isEmpty {
                ContentUnavailableView("No photo check-ins", systemImage: "person.crop.rectangle.badge.plus", description: Text("Create the first weekly baseline in the morning."))
                    .frame(minHeight: 180)
            } else {
                ForEach(checkIns.checkIns) { checkIn in
                    NavigationLink {
                        ProgressCheckInDetailView(checkIn: checkIn, previous: previous(to: checkIn), store: checkIns)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.title2)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 44)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(checkIn.date.formatted(date: .abbreviated, time: .omitted)).font(.headline)
                                Text(checkIn.wasRejected ? "Estimate rejected" : (checkIn.acceptedRange ?? checkIn.analysis.reconciled.bodyFatRange).label)
                                    .foregroundStyle(checkIn.wasRejected ? Theme.warning : Theme.accent)
                                Text(checkIn.analysis.reconciled.nextWeekAction)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                        .padding(10)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func chartValues(_ keyPath: KeyPath<DailyHealthSnapshot, Double?>) -> [TrendValue] {
        app.healthHistory.compactMap { snapshot in
            guard let date = Self.dayFormatter.date(from: snapshot.date), let value = snapshot[keyPath: keyPath] else { return nil }
            return TrendValue(date: date, value: value)
        }.sorted { $0.date < $1.date }
    }

    private var weekCutoff: String { HealthKitService.dayKey(for: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()) }
    private var weeklyMeals: [LoggedMeal] { app.mealHistory.filter { HealthKitService.dayKey(for: $0.createdAt) >= weekCutoff } }
    private var weeklyProtein: Int { weeklyMeals.reduce(0) { $0 + $1.accepted.proteinGrams } }
    private var weeklyCalories: Int {
        weeklyMeals.reduce(0) { $0 + ($1.accepted.caloriesRange.lowerBound + $1.accepted.caloriesRange.upperBound) / 2 }
    }
    private var averageSleep: String {
        let values = app.healthHistory.filter { $0.date >= weekCutoff }.compactMap(\.sleepHours)
        guard !values.isEmpty else { return "--" }
        return "\((values.reduce(0, +) / Double(values.count)).formatted(.number.precision(.fractionLength(1)))) h"
    }
    private var strengthDays: Int { Set(training.strengthLogs.filter { $0.date >= weekCutoff }.map(\.date)).count }
    private var swimDays: Int { Set(training.swimLogs.filter { $0.date >= weekCutoff }.map(\.date)).count }
    private func percent(_ value: Double?) -> String { value.map { "\(Int(($0 * 100).rounded()))%" } ?? "--" }
    private func previous(to checkIn: ProgressCheckIn) -> ProgressCheckIn? {
        guard let index = checkIns.checkIns.firstIndex(of: checkIn), checkIns.checkIns.indices.contains(index + 1) else { return nil }
        return checkIns.checkIns[index + 1]
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct TrendValue: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

private struct TrendChart: View {
    let title: String
    let unit: String
    let color: Color
    let values: [TrendValue]
    var target: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if let latest = values.last { Text("\(latest.value.formatted(.number.precision(.fractionLength(1)))) \(unit)").font(.headline).foregroundStyle(color) }
            }
            if values.isEmpty {
                Text("Sync HealthKit or add a manual entry to begin this trend.")
                    .font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    ForEach(values) { point in
                        LineMark(x: .value("Date", point.date), y: .value(title, point.value)).interpolationMethod(.catmullRom)
                        PointMark(x: .value("Date", point.date), y: .value(title, point.value))
                    }
                    if let target {
                        RuleMark(y: .value("Target", target))
                            .foregroundStyle(.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("12% target")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .foregroundStyle(color)
                .chartYScale(domain: yDomain)
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
                .frame(height: 170)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(title) trend")
                .accessibilityValue(chartSummary)
            }
        }
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var yDomain: ClosedRange<Double> {
        let allValues = values.map(\.value) + (target.map { [$0] } ?? [])
        guard let minimum = allValues.min(), let maximum = allValues.max() else { return 0...1 }
        let padding = max((maximum - minimum) * 0.18, unit == "%" ? 1 : 0.5)
        return max(0, minimum - padding)...(maximum + padding)
    }

    private var chartSummary: String {
        guard let first = values.first, let latest = values.last else { return "No data" }
        let direction = latest.value == first.value ? "unchanged" : (latest.value < first.value ? "down" : "up")
        let change = abs(latest.value - first.value).formatted(.number.precision(.fractionLength(1)))
        return "Latest \(latest.value.formatted(.number.precision(.fractionLength(1)))) \(unit), \(direction) \(change) \(unit) across \(values.count) measurements"
    }
}

private struct ProgressCaptureView: View {
    private enum EstimateTab: String, CaseIterable, Identifiable { case combined = "Combined", openAI = "ChatGPT", gemini = "Gemini"; var id: Self { self } }
    @EnvironmentObject private var app: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ProgressCheckInStore
    @State private var images: [ProgressPose: UIImage] = [:]
    @State private var imageData: [ProgressPose: Data] = [:]
    @State private var frontItem: PhotosPickerItem?
    @State private var sideItem: PhotosPickerItem?
    @State private var backItem: PhotosPickerItem?
    @State private var cameraPose: ProgressPose?
    @State private var morning = false
    @State private var lighting = false
    @State private var fullBody = false
    @State private var isAnalyzing = false
    @State private var analysis: ProgressAnalysisBundle?
    @State private var selectedTab: EstimateTab = .combined
    @State private var lower = ""
    @State private var upper = ""
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Use the same room, camera height, distance, posture, and relaxed pose each week.")
                    .font(.callout).foregroundStyle(.secondary)
                AnalysisPrivacyNotice(subject: "progress")
                HStack(spacing: 8) {
                    photoSlot(.front, item: $frontItem)
                    photoSlot(.side, item: $sideItem)
                    photoSlot(.back, item: $backItem)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Morning, before food or training", isOn: $morning)
                    Toggle("Consistent lighting and distance", isOn: $lighting)
                    Toggle("Full body is clearly framed", isOn: $fullBody)
                }
                Button(action: analyze) {
                    Group { if isAnalyzing { ProgressView() } else { Label("Analyze progress", systemImage: "sparkles") } }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(imageData.count != 3 || !morning || !lighting || !fullBody || isAnalyzing)
                if let errorMessage { Label(errorMessage, systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundStyle(Theme.warning) }
                if let analysis { resultView(analysis) }
            }
            .padding()
        }
        .navigationTitle("Progress check-in")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $cameraPose) { pose in
            ProgressCameraPicker { image in prepare(image, for: pose) }.ignoresSafeArea()
        }
        .onChange(of: frontItem) { _, item in load(item, pose: .front) }
        .onChange(of: sideItem) { _, item in load(item, pose: .side) }
        .onChange(of: backItem) { _, item in load(item, pose: .back) }
    }

    private func photoSlot(_ pose: ProgressPose, item: Binding<PhotosPickerItem?>) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Theme.surface)
                if let image = images[pose] { Image(uiImage: image).resizable().scaledToFill() }
                else { Image(systemName: pose.symbol).font(.title).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity).aspectRatio(0.72, contentMode: .fit).clipped()
            .accessibilityLabel("\(pose.title) progress photo")
            .accessibilityValue(images[pose] == nil ? "Not selected" : "Selected")
            Text(pose.title).font(.caption.bold())
            HStack(spacing: 4) {
                PhotosPicker(selection: item, matching: .images) { Image(systemName: "photo").frame(width: 32, height: 28) }.buttonStyle(.bordered)
                Button { cameraPose = pose } label: { Image(systemName: "camera").frame(width: 32, height: 28) }.buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder private func resultView(_ bundle: ProgressAnalysisBundle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Estimate", selection: $selectedTab) { ForEach(EstimateTab.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            if let selected = selectedAnalysis(bundle) {
                HStack(alignment: .firstTextBaseline) {
                    Text(selected.bodyFatRange.label).font(.largeTitle.bold())
                    Spacer()
                    Label(selected.imageQuality.capitalized, systemImage: selected.imageQuality == "good" ? "checkmark.circle" : "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(selected.imageQuality == "good" ? Theme.accent : Theme.warning)
                }
                resultList("Green signs", items: selected.positiveSignals ?? [], icon: "checkmark.circle.fill", color: Theme.accent)
                resultList("Red signs", items: selected.warningSignals ?? selected.limitations, icon: "exclamationmark.triangle.fill", color: Theme.coral)
                resultList("Visual notes", selected.visibleChanges)
                resultList("Limits", selected.limitations)
                resultList("What to improve", items: selected.suggestions, icon: "arrow.up.circle.fill", color: Theme.blue)
                VStack(alignment: .leading, spacing: 4) { Text("Next week").font(.headline); Text(selected.nextWeekAction) }
            } else {
                Text(selectedError(bundle) ?? "This provider did not return an estimate.").foregroundStyle(Theme.warning)
            }
            Divider()
            Text("Review estimate").font(.headline)
            HStack {
                TextField("Lower %", text: $lower).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                TextField("Upper %", text: $upper).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
            }
            HStack {
                Button("Reject estimate", role: .destructive) { save(rejected: true) }
                Spacer()
                Button("Save check-in") { save(rejected: false) }.buttonStyle(.borderedProminent)
                    .disabled(validRange == nil)
            }
        }
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func resultList(_ title: String, _ items: [String]) -> some View {
        resultList(title, items: items, icon: "circle.fill", color: .primary)
    }

    private func resultList(_ title: String, items: [String], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.headline).foregroundStyle(color)
            ForEach(items, id: \.self) { Label($0, systemImage: icon).font(.callout).symbolRenderingMode(.hierarchical) }
        }
    }

    private var validRange: BodyFatEstimateRange? {
        guard let low = Double(lower), let high = Double(upper), (3...60).contains(low), (3...60).contains(high), low <= high else { return nil }
        return BodyFatEstimateRange(lower: low, upper: high)
    }

    private func selectedAnalysis(_ bundle: ProgressAnalysisBundle) -> ProgressAnalysis? {
        switch selectedTab { case .combined: bundle.reconciled; case .openAI: bundle.openAI.analysis; case .gemini: bundle.gemini.analysis }
    }
    private func selectedError(_ bundle: ProgressAnalysisBundle) -> String? {
        switch selectedTab { case .combined: nil; case .openAI: bundle.openAI.error; case .gemini: bundle.gemini.error }
    }
    private func prepare(_ image: UIImage, for pose: ProgressPose) {
        guard let data = image.progressJPEG() else { errorMessage = "Could not prepare that photo."; return }
        images[pose] = UIImage(data: data); imageData[pose] = data
    }
    private func load(_ item: PhotosPickerItem?, pose: ProgressPose) {
        guard let item else { return }
        Task { if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) { await MainActor.run { prepare(image, for: pose) } } }
    }
    private func analyze() {
        isAnalyzing = true; errorMessage = nil
        Task {
            do {
                let result = try await ProgressAPIClient().analyze(current: imageData, app: app, previousRange: store.latest?.acceptedRange)
                analysis = result
                lower = result.reconciled.bodyFatRange.lower.formatted(.number.precision(.fractionLength(0...1)))
                upper = result.reconciled.bodyFatRange.upper.formatted(.number.precision(.fractionLength(0...1)))
            } catch { errorMessage = error.localizedDescription }
            isAnalyzing = false
        }
    }
    private func save(rejected: Bool) {
        guard let analysis else { return }
        store.save(analysis: analysis, acceptedRange: rejected ? nil : validRange, rejected: rejected)
        images.removeAll()
        imageData.removeAll()
        dismiss()
    }
}

private struct ProgressCheckInDetailView: View {
    let checkIn: ProgressCheckIn
    let previous: ProgressCheckIn?
    @ObservedObject var store: ProgressCheckInStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(checkIn.wasRejected ? "Estimate rejected" : (checkIn.acceptedRange ?? checkIn.analysis.reconciled.bodyFatRange).label).font(.title.bold())
                    Text(checkIn.analysis.reconciled.nextWeekAction)
                    ForEach(checkIn.analysis.reconciled.limitations, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.secondary) }
                }
                if let previous {
                    LabeledContent("Previous check-in", value: (previous.acceptedRange ?? previous.analysis.reconciled.bodyFatRange).label)
                }
                Label("Capture photos were discarded after analysis.", systemImage: "hand.raised")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Delete check-in", role: .destructive) { store.delete(checkIn); dismiss() }.frame(maxWidth: .infinity)
            }.padding()
        }
        .navigationTitle(checkIn.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProgressCameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera; picker.cameraCaptureMode = .photo; picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ProgressCameraPicker
        init(parent: ProgressCameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImage(image) }; parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

private extension UIImage {
    func progressJPEG(maxDimension: CGFloat = 1400) -> Data? {
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let rendered = renderer.image { _ in draw(in: CGRect(origin: .zero, size: target)) }
        return rendered.jpegData(compressionQuality: 0.72)
    }
}
