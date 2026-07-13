import PhotosUI
import SwiftUI
import UIKit
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

struct MealLogView: View {
    private enum EstimateTab: String, CaseIterable, Identifiable {
        case combined = "Combined"
        case openAI = "ChatGPT"
        case gemini = "Gemini"

        var id: Self { self }
    }

    @EnvironmentObject private var store: AppStore
    @State private var notes = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var imageData: Data?
    @State private var analysis: MealAnalysisBundle?
    @State private var selectedEstimate: EstimateTab = .combined
    @State private var isAnalyzing = false
    @State private var isShowingCamera = false
    @State private var isShowingCorrection = false
    @State private var errorMessage: String?

    private let client = MealAPIClient()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Log what you actually ate")
                            .font(.title3.bold())
                        Text("A clear photo plus portion details gives both models a better starting point.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    photoInput

                    TextField("Portion, cooking oil, sauces, restaurant or home", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                        .textFieldStyle(.roundedBorder)

                    Button(action: analyzeMeal) {
                        if isAnalyzing {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Analyze meal", systemImage: "sparkles")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(imageData == nil || isAnalyzing)

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(Theme.warning)
                    }

                    if let analysis {
                        analysisSection(analysis)
                    }

                    historySection
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Meals")
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker { pickedImage in
                    prepare(pickedImage)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isShowingCorrection) {
                if let analysis, let imageData {
                    NutritionCorrectionView(analysis: analysis.reconciled) { accepted in
                        store.saveMeal(
                            estimates: analysis,
                            accepted: accepted,
                            notes: notes,
                            imageData: imageData
                        )
                        resetDraft()
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let selectedImage = UIImage(data: data) else {
                        errorMessage = "That photo could not be loaded. Try another image."
                        return
                    }
                    prepare(selectedImage)
                }
            }
        }
    }

    private var photoInput: some View {
        VStack(spacing: 12) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ContentUnavailableView(
                    "Add a meal photo",
                    systemImage: "fork.knife.circle",
                    description: Text("Use a clear overhead photo and add portion notes below.")
                )
                .frame(maxWidth: .infinity, minHeight: 190)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Photo library", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)

                Button {
                    isShowingCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                }
                .buttonStyle(.bordered)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            }
        }
    }

    @ViewBuilder
    private func analysisSection(_ bundle: MealAnalysisBundle) -> some View {
        SectionHeader(title: "AI estimate")

        Picker("Estimate", selection: $selectedEstimate) {
            ForEach(EstimateTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)

        switch selectedEstimate {
        case .combined:
            estimatePanel(bundle.reconciled, providerMode: "Reconciled estimate")
        case .openAI:
            providerPanel(bundle.openAI)
        case .gemini:
            providerPanel(bundle.gemini)
        }

        Button {
            isShowingCorrection = true
        } label: {
            Label("Review and save", systemImage: "checkmark.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    @ViewBuilder
    private func providerPanel(_ provider: MealProviderEstimate) -> some View {
        if let estimate = provider.analysis {
            estimatePanel(estimate, providerMode: provider.mode == "live" ? "Live estimate" : "Demo estimate")
        } else {
            Label(provider.error ?? "This provider did not return an estimate.", systemImage: "wifi.exclamationmark")
                .font(.callout)
                .foregroundStyle(Theme.warning)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func estimatePanel(_ meal: MealAnalysis, providerMode: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(meal.title).font(.headline)
                Spacer()
                Text(providerMode).font(.caption).foregroundStyle(.secondary)
            }
            Text("\(meal.caloriesRange.lowerBound)-\(meal.caloriesRange.upperBound) kcal")
                .font(.title2.bold())
            Text("Protein \(meal.proteinGrams)g | Carbs \(meal.carbsGrams)g | Fat \(meal.fatGrams)g")
                .foregroundStyle(.secondary)
            ProgressView(value: meal.confidence)
                .tint(meal.confidence >= 0.65 ? Theme.accent : Theme.warning)
            Text(meal.recommendation)
            ForEach(meal.likelyMistakes, id: \.self) { mistake in
                Label(mistake, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }
        }
        .padding()
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var historySection: some View {
        SectionHeader(title: "Meal history")
        if store.mealHistory.isEmpty {
            Text("Saved meals will appear here.")
                .foregroundStyle(.secondary)
        } else {
            ForEach(store.mealHistory) { meal in
                HStack(alignment: .top, spacing: 12) {
                    if let data = store.mealImageData(for: meal), let thumbnail = UIImage(data: data) {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meal.accepted.title).font(.headline)
                        Text(meal.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                        Text("\(meal.accepted.caloriesRange.lowerBound) kcal | P \(meal.accepted.proteinGrams)g | C \(meal.accepted.carbsGrams)g | F \(meal.accepted.fatGrams)g")
                            .font(.callout)
                    }
                    Spacer(minLength: 4)
                    Button(role: .destructive) {
                        store.deleteMeal(meal)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete meal")
                }
                .padding()
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func analyzeMeal() {
        guard let imageData else { return }
        isAnalyzing = true
        errorMessage = nil
        analysis = nil
        Task {
            do {
                analysis = try await client.analyze(
                    imageData: imageData,
                    notes: notes,
                    targetProteinGrams: store.proteinTargetGrams
                )
                selectedEstimate = .combined
            } catch {
                errorMessage = error.localizedDescription
            }
            isAnalyzing = false
        }
    }

    private func prepare(_ pickedImage: UIImage) {
        guard let prepared = pickedImage.preparedForMealUpload(),
              let data = prepared.jpegData(compressionQuality: 0.78) else {
            errorMessage = "The photo could not be prepared for analysis."
            return
        }
        image = prepared
        imageData = data
        analysis = nil
        errorMessage = nil
    }

    private func resetDraft() {
        notes = ""
        selectedPhoto = nil
        image = nil
        imageData = nil
        analysis = nil
        isShowingCorrection = false
    }
}

private struct NutritionCorrectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var calories: Int
    @State private var protein: Int
    @State private var carbs: Int
    @State private var fat: Int
    let analysis: MealAnalysis
    let onSave: (MealAnalysis) -> Void

    init(analysis: MealAnalysis, onSave: @escaping (MealAnalysis) -> Void) {
        self.analysis = analysis
        self.onSave = onSave
        _title = State(initialValue: analysis.title)
        _calories = State(initialValue: (analysis.caloriesRange.lowerBound + analysis.caloriesRange.upperBound) / 2)
        _protein = State(initialValue: analysis.proteinGrams)
        _carbs = State(initialValue: analysis.carbsGrams)
        _fat = State(initialValue: analysis.fatGrams)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Meal name", text: $title)
                    Stepper("Calories: \(calories) kcal", value: $calories, in: 0...5_000, step: 10)
                }
                Section("Macros") {
                    Stepper("Protein: \(protein)g", value: $protein, in: 0...300)
                    Stepper("Carbs: \(carbs)g", value: $carbs, in: 0...500)
                    Stepper("Fat: \(fat)g", value: $fat, in: 0...300)
                }
                Section {
                    Text("Photo estimates can miss oils, sauces, ingredients, and portion depth. Correct known values before saving.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Confirm nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(
                            MealAnalysis(
                                title: trimmedTitle.isEmpty ? analysis.title : trimmedTitle,
                                caloriesRange: calories...calories,
                                proteinGrams: protein,
                                carbsGrams: carbs,
                                fatGrams: fat,
                                confidence: analysis.confidence,
                                likelyMistakes: analysis.likelyMistakes,
                                recommendation: analysis.recommendation
                            )
                        )
                    }
                }
            }
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

private extension UIImage {
    func preparedForMealUpload(maxDimension: CGFloat = 1_600) -> UIImage? {
        let longest = max(size.width, size.height)
        let scale = min(1, maxDimension / longest)
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
