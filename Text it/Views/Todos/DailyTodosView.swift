//
//  DailyTodosView.swift
//  Text it
//
//  Tägliche Aufgaben mit automatischem Übertrag nicht erledigter Todos.
//

import SwiftUI
import SwiftData

struct DailyTodosView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    @Query(sort: \DailyTodo.sortIndex)
    private var allTodos: [DailyTodo]

    @State private var newTodoText: String = ""
    @State private var isAddingTodo: Bool = false
    @FocusState private var addFieldFocused: Bool
    @State private var editingID: UUID? = nil

    private var todayStart: Date { Calendar.current.startOfDay(for: Date()) }
    private var tomorrowStart: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: todayStart)!
    }

    private var todaysTodos: [DailyTodo] {
        allTodos.filter { $0.targetDate >= todayStart && $0.targetDate < tomorrowStart }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    private var carriedTodos: [DailyTodo] {
        todaysTodos.filter { $0.carriedOver && !$0.isChecked }
    }

    private var freshTodos: [DailyTodo] {
        todaysTodos.filter { !$0.carriedOver || $0.isChecked }
    }

    private var checkedCount: Int { todaysTodos.filter { $0.isChecked }.count }
    private var totalCount: Int { todaysTodos.count }
    private var progress: Double {
        totalCount == 0 ? 0 : Double(checkedCount) / Double(totalCount)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                if !carriedTodos.isEmpty { carriedSection }
                todaySection
                addTodoField
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .navigationTitle("Todos")
        .onAppear { carryOverUnfinished() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tägliche Todos")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            progressRing
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 5)
                .frame(width: 64, height: 64)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progress >= 1.0 ? Color.green : appState.theme.accent,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 64, height: 64)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.4), value: progress)
            VStack(spacing: 1) {
                Text("\(checkedCount)")
                    .font(.system(.callout, design: .rounded, weight: .bold))
                Text("/\(totalCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Übertragene Todos

    private var carriedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.trianglehead.counterclockwise")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("Von gestern übertragen")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            ForEach(carriedTodos) { todo in
                TodoRow(todo: todo, editingID: $editingID, onDelete: deleteTodo)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.06))
        )
    }

    // MARK: - Heutige Todos

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Heute", icon: "sun.max.fill")
                Spacer()
                if checkedCount > 0 {
                    Button {
                        withAnimation { clearCompleted() }
                    } label: {
                        Text("Erledigt löschen")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if freshTodos.isEmpty && carriedTodos.isEmpty {
                emptyState
            } else {
                ForEach(freshTodos) { todo in
                    TodoRow(todo: todo, editingID: $editingID, onDelete: deleteTodo)
                }
                .onMove { from, to in reorderTodos(from: from, to: to, in: freshTodos) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("Keine Aufgaben für heute")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Füge deine erste Aufgabe hinzu.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Neue Aufgabe

    private var addTodoField: some View {
        HStack(spacing: 12) {
            Circle()
                .stroke(appState.theme.accent.opacity(0.5), lineWidth: 1.5)
                .frame(width: 22, height: 22)

            TextField("Aufgabe hinzufügen…", text: $newTodoText)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($addFieldFocused)
                .onSubmit { commitNewTodo() }
                .submitLabel(.done)

            if !newTodoText.isEmpty {
                Button { commitNewTodo() } label: {
                    Image(systemName: "return")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(appState.theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.quaternary.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(addFieldFocused ? appState.theme.accent.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
        )
        .animation(.easeInOut(duration: 0.15), value: addFieldFocused)
        .onTapGesture { addFieldFocused = true }
    }

    // MARK: - Carry-Over Logic

    private func carryOverUnfinished() {
        let today = Calendar.current.startOfDay(for: Date())
        let overdue = allTodos.filter { !$0.isChecked && $0.targetDate < today }
        guard !overdue.isEmpty else { return }
        for todo in overdue {
            todo.targetDate = today
            todo.carriedOver = true
        }
        try? context.save()
    }

    // MARK: - CRUD

    private func commitNewTodo() {
        let trimmed = newTodoText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            addFieldFocused = false
            return
        }
        let nextIndex = (todaysTodos.map(\.sortIndex).max() ?? -1) + 1
        let todo = DailyTodo(text: trimmed)
        todo.sortIndex = nextIndex
        context.insert(todo)
        try? context.save()
        NearbySync.shared.sendTodoUpsert(todo)
        newTodoText = ""
    }

    private func deleteTodo(_ todo: DailyTodo) {
        NearbySync.shared.sendTodoDelete(todo.id)
        context.delete(todo)
        try? context.save()
    }

    private func clearCompleted() {
        let done = todaysTodos.filter { $0.isChecked }
        done.forEach { t in
            NearbySync.shared.sendTodoDelete(t.id)
            context.delete(t)
        }
        try? context.save()
    }

    private func reorderTodos(from source: IndexSet, to destination: Int, in list: [DailyTodo]) {
        var copy = list
        copy.move(fromOffsets: source, toOffset: destination)
        for (i, t) in copy.enumerated() {
            t.sortIndex = i
            NearbySync.shared.sendTodoUpsert(t)
        }
        try? context.save()
    }
}

// MARK: - TodoRow

struct TodoRow: View {
    @Bindable var todo: DailyTodo
    @Binding var editingID: UUID?
    let onDelete: (DailyTodo) -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppState.self) private var appState
    @State private var draftText: String = ""
    @FocusState private var editFocused: Bool

    private var isEditing: Bool { editingID == todo.id }

    var body: some View {
        HStack(spacing: 12) {
            checkButton
            contentArea
            Spacer(minLength: 0)
            if !isEditing {
                deleteButton
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(rowBackground)
        .animation(.easeInOut(duration: 0.15), value: todo.isChecked)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { onDelete(todo) } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    private var checkButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                todo.isChecked.toggle()
                todo.carriedOver = false
                try? context.save()
                NearbySync.shared.sendTodoUpsert(todo)
            }
        } label: {
            Image(systemName: todo.isChecked ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(todo.isChecked ? appState.theme.accent : Color.secondary.opacity(0.5))
                .scaleEffect(todo.isChecked ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var contentArea: some View {
        if isEditing {
            TextField("Aufgabe", text: $draftText)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($editFocused)
                .onSubmit { commitEdit() }
                .onChange(of: editFocused) { _, focused in
                    if !focused { commitEdit() }
                }
                .onAppear {
                    draftText = todo.text
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        editFocused = true
                    }
                }
        } else {
            Text(todo.text)
                .font(.callout)
                .strikethrough(todo.isChecked, color: .secondary)
                .foregroundStyle(todo.isChecked ? .secondary : .primary)
                .onTapGesture(count: 2) {
                    editingID = todo.id
                }
        }
    }

    private var deleteButton: some View {
        Button { onDelete(todo) } label: {
            Image(systemName: "xmark")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .opacity(0.5)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(todo.isChecked
                  ? Color.secondary.opacity(0.06)
                  : Color.primary.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(todo.isChecked ? Color.clear : Color.secondary.opacity(0.1), lineWidth: 1)
            )
    }

    private func commitEdit() {
        let trimmed = draftText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { todo.text = trimmed }
        try? context.save()
        NearbySync.shared.sendTodoUpsert(todo)
        editingID = nil
    }
}
