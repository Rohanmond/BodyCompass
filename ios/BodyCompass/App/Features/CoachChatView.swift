import SwiftUI

struct CoachChatView: View {
    @State private var question = ""
    @State private var selectedTab = "Combined"
    private let tabs = ["Combined", "ChatGPT", "Gemini"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Picker("Answer source", selection: $selectedTab) {
                    ForEach(tabs, id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(selectedTab)
                            .font(.headline)
                        Text("Based on today's data, your best move is to keep protein high, complete the planned workout, and avoid cutting calories harder until the weekly trend confirms you are stalled.")
                            .padding()
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    TextField("Ask your coach", text: $question)
                        .textFieldStyle(.roundedBorder)
                    Button {
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Coach")
        }
    }
}
