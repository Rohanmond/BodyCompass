import SwiftUI
#if canImport(BodyCompassCore)
import BodyCompassCore
#endif

struct ScheduleEditorView: View {
    @EnvironmentObject private var store: AppStore
    @State private var editingItem: ScheduleItem?
    @State private var isAdding = false
    @State private var testReminderMessage: String?

    var body: some View {
        List {
            Section {
                Toggle("Daily reminders", isOn: Binding(
                    get: { store.remindersEnabled },
                    set: { newValue in Task { await store.setRemindersEnabled(newValue) } }
                ))
#if DEBUG
                Button {
                    Task {
                        let scheduled = await store.scheduleTestReminder()
                        testReminderMessage = scheduled
                            ? "Test scheduled. Lock the iPhone and wait 10 seconds."
                            : "Enable Daily reminders and allow notifications first."
                    }
                } label: {
                    Label("Send test reminder in 10 seconds", systemImage: "bell.badge")
                }
                if let testReminderMessage {
                    Text(testReminderMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
#endif
            } footer: {
                Text("Get a local notification at the time set on each task. Tasks without a time are silent.")
            }

            Section("Tasks") {
                ForEach(store.schedule) { item in
                    Button {
                        editingItem = item
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.category.systemImage)
                                .foregroundStyle(Theme.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .foregroundStyle(.primary)
                                Text(reminderSubtitle(for: item))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .onDelete { store.deleteItems(at: $0) }
                .onMove { store.moveItems(from: $0, to: $1) }

                Button {
                    isAdding = true
                } label: {
                    Label("Add task", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Daily schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $isAdding) {
            ScheduleItemForm(mode: .add)
        }
        .sheet(item: $editingItem) { item in
            ScheduleItemForm(mode: .edit(item))
        }
    }

    private func reminderSubtitle(for item: ScheduleItem) -> String {
        guard let hour = item.reminderHour, let minute = item.reminderMinute else {
            return "\(item.category.displayName) · no reminder"
        }
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return "\(item.category.displayName) · \(date.formatted(date: .omitted, time: .shortened))"
    }
}

private struct ScheduleItemForm: View {
    enum Mode {
        case add
        case edit(ScheduleItem)
    }

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var title = ""
    @State private var category: ScheduleCategory = .other
    @State private var hasReminder = false
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("e.g. Strength training", text: $title)
                }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(ScheduleCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.systemImage).tag(category)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                Section("Reminder") {
                    Toggle("Remind me", isOn: $hasReminder)
                    if hasReminder {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit task" : "New task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: prefill)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func prefill() {
        guard case let .edit(item) = mode else { return }
        title = item.title
        category = item.category
        if let hour = item.reminderHour, let minute = item.reminderMinute {
            hasReminder = true
            reminderTime = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? reminderTime
        }
    }

    private func save() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let hour = hasReminder ? components.hour : nil
        let minute = hasReminder ? components.minute : nil

        switch mode {
        case .add:
            store.addItem(title: title, category: category, reminderHour: hour, reminderMinute: minute)
        case .edit(let item):
            var updated = item
            updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.category = category
            updated.reminderHour = hour
            updated.reminderMinute = minute
            store.updateItem(updated)
        }
        dismiss()
    }
}
