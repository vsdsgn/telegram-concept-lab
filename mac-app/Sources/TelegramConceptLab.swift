import SwiftUI
import AppKit
import Combine
import Foundation

private enum LabPaths {
    static let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Projects/telegram-concept-lab")
    static let state = root.appendingPathComponent(".lab")
    static let jobs = state.appendingPathComponent("jobs.json")
    static let logRoot = state.appendingPathComponent("logs")
    static let github = URL(string: "https://github.com/vsdsgn/telegram-concept-lab")!
    static let paperclip = URL(string: "https://asya.188-245-144-65.sslip.io/")!
}

private struct Phase: Identifiable {
    let key: String
    let label: String
    var id: String { key }
}

private let phases: [Phase] = [
    .init(key: "design", label: "Claude · UX-дизайн"),
    .init(key: "design-review", label: "Codex · UX-ревью"),
    .init(key: "design-revise", label: "Claude · правки дизайна"),
    .init(key: "build-ios", label: "Codex · разработка iOS"),
    .init(key: "build-android", label: "Codex · разработка Android"),
    .init(key: "review-ios", label: "Claude · ревью iOS"),
    .init(key: "review-android", label: "Claude · ревью Android"),
    .init(key: "fix-ios", label: "Codex · исправления iOS"),
    .init(key: "fix-android", label: "Codex · исправления Android")
]

private struct LabJob: Identifiable {
    let slug: String
    let mode: String
    let phase: String
    let error: String?
    let created: String?
    let legacyPlatforms: [String: String]
    var id: String { slug }
    var isCollaborative: Bool { mode == "collaborative" }

    var state: String {
        if isCollaborative {
            let marker = LabPaths.logRoot.appendingPathComponent(slug + "/pipeline.exit")
            if let exitCode = try? String(contentsOf: marker, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines) {
                return exitCode == "0" ? "Завершено" : "Ошибка"
            }
            if phase == "failed" { return "Ошибка" }
            return "В процессе"
        }
        return "Старый пилот"
    }

    var color: Color {
        switch state {
        case "Завершено": return .green
        case "Ошибка": return .red
        case "В процессе": return .orange
        default: return .secondary
        }
    }

    var isComplete: Bool { state == "Завершено" || state == "Старый пилот" }
}

@MainActor
private final class LabStore: ObservableObject {
    @Published var jobs: [LabJob] = []
    @Published var busy = false
    @Published var lastResult = ""
    @Published var lastError = ""

    func refresh() {
        guard let data = try? Data(contentsOf: LabPaths.jobs),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let records = obj as? [String: [String: Any]] else {
            jobs = []
            return
        }
        jobs = records.map { slug, dict in
            var platformStatuses: [String: String] = [:]
            if let platforms = dict["platforms"] as? [String: [String: Any]] {
                for (platform, p) in platforms {
                    platformStatuses[platform] = p["agent"] as? String ?? "unknown"
                }
            }
            return LabJob(
                slug: slug,
                mode: dict["mode"] as? String ?? "legacy",
                phase: dict["phase"] as? String ?? "unknown",
                error: dict["error"] as? String,
                created: dict["created_at"] as? String,
                legacyPlatforms: platformStatuses
            )
        }.sorted { ($0.created ?? "") > ($1.created ?? "") }
    }

    func phaseState(slug: String, key: String) -> String {
        let url = LabPaths.logRoot.appendingPathComponent(slug + "/" + key + ".exit")
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return "ожидает" }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines) == "0" ? "готово" : "ошибка"
    }

    func log(slug: String, phase: String = "pipeline") -> String {
        let path = LabPaths.logRoot.appendingPathComponent(slug + "/" + phase + ".log")
        guard let raw = try? String(contentsOf: path, encoding: .utf8) else { return "Логов пока нет." }
        let tail = raw.split(separator: "\n", omittingEmptySubsequences: false).suffix(90)
        return tail.joined(separator: "\n")
    }

    func launch(prompt: String, done: @escaping (String) -> Void) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let slug = "concept-" + formatter.string(from: Date()) + "-" + String(UUID().uuidString.prefix(4)).lowercased()
        execute(["new", slug, prompt]) { success in
            if success { done(slug) }
        }
    }

    func createPR(slug: String) {
        execute(["prs", slug]) { success in
            if success { NSWorkspace.shared.open(URL(string: LabPaths.github.absoluteString + "/pulls")!) }
        }
    }

    func doctor() { execute(["doctor"]) { _ in } }

    private func execute(_ arguments: [String], completion: @escaping (Bool) -> Void) {
        guard !busy else { return }
        guard FileManager.default.fileExists(atPath: LabPaths.root.appendingPathComponent("lab.py").path) else {
            lastError = "Не найден проект: \(LabPaths.root.path)"
            return
        }
        busy = true
        lastError = ""
        lastResult = "Выполняется: " + arguments.first! + "…"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "lab.py"] + arguments
        process.currentDirectoryURL = LabPaths.root
        var environment = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        environment["PATH"] = [
            home + "/.local/bin", "/opt/homebrew/bin", "/usr/local/bin",
            "/usr/bin", "/bin", "/usr/sbin", "/sbin"
        ].joined(separator: ":")
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.terminationHandler = { [weak self] finished in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                self.lastResult = output.isEmpty ? "Команда завершилась без вывода." : output
                if finished.terminationStatus != 0 {
                    self.lastError = "Ошибка запуска (код \(finished.terminationStatus)). Подробности ниже."
                }
                self.refresh()
                completion(finished.terminationStatus == 0)
            }
        }
        do {
            try process.run()
        } catch {
            busy = false
            lastError = "Не удалось запустить процесс: \(error.localizedDescription)"
        }
    }

    func openIOS(slug: String) {
        let folder = LabPaths.state.appendingPathComponent("worktrees/\(slug)/ios/concepts/\(slug)/ios")
        guard FileManager.default.fileExists(atPath: folder.path) else {
            lastError = "iOS-проект пока не создан."
            return
        }
        if let items = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil),
           let project = items.first(where: { $0.pathExtension == "xcodeproj" }) {
            openApplication("Xcode", url: project)
        } else {
            NSWorkspace.shared.open(folder)
        }
    }

    func openAndroid(slug: String) {
        let folder = LabPaths.state.appendingPathComponent("worktrees/\(slug)/android/concepts/\(slug)/android")
        guard FileManager.default.fileExists(atPath: folder.path) else {
            lastError = "Android-проект пока не создан."
            return
        }
        openApplication("Android Studio", url: folder)
    }

    func openLogs(slug: String) {
        let url = LabPaths.logRoot.appendingPathComponent(slug)
        guard FileManager.default.fileExists(atPath: url.path) else {
            lastError = "Логов пока нет."
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func openApplication(_ app: String, url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", app, url.path]
        do { try process.run() }
        catch { lastError = "\(app): \(error.localizedDescription)" }
    }
}

private struct StatusTag: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1), in: Capsule())
    }
}

private struct ContentView: View {
    @StateObject private var store = LabStore()
    @State private var selection = "new"
    @State private var idea = ""
    @State private var publicAgreed = false
    @State private var confirmLaunch = false
    @State private var confirmPR = false
    @State private var selectedLog = "pipeline"

    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var selectedJob: LabJob? { store.jobs.first(where: { $0.slug == selection }) }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Новый концепт", systemImage: "plus.circle.fill")
                    .tag("new")
                Section("Запуски") {
                    ForEach(store.jobs) { job in
                        HStack(spacing: 9) {
                            Image(systemName: job.state == "Завершено" ? "checkmark.circle.fill" :
                                  job.state == "Ошибка" ? "exclamationmark.circle.fill" : "circle.dotted")
                                .foregroundStyle(job.color)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(job.slug).font(.callout).lineLimit(1)
                                Text(job.state).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .tag(job.slug)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Concept Lab")
            .navigationSplitViewColumnWidth(min: 235, ideal: 280, max: 320)
        } detail: {
            if selection == "new" {
                newConceptView
            } else if let job = selectedJob {
                jobDetailView(job)
            } else {
                ContentUnavailableView("Выбери концепт", systemImage: "rectangle.stack")
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { store.refresh() } label: {
                    Label("Обновить", systemImage: "arrow.clockwise")
                }
                .help("Обновить статус")
                Button {
                    NSWorkspace.shared.open(LabPaths.github)
                } label: {
                    Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .help("Открыть GitHub")
                Button {
                    NSWorkspace.shared.open(LabPaths.paperclip)
                } label: {
                    Label("Paperclip", systemImage: "square.grid.2x2")
                }
                .help("Открыть Paperclip (агенты пока выключены)")
            }
        }
        .onAppear { store.refresh() }
        .onReceive(timer) { _ in store.refresh() }
        .alert("Ошибка", isPresented: Binding(
            get: { !store.lastError.isEmpty },
            set: { if !$0 { store.lastError = "" } }
        )) {
            Button("OK", role: .cancel) { store.lastError = "" }
        } message: {
            Text(store.lastError)
        }
    }

    private var newConceptView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Новый Telegram-концепт")
                        .font(.system(size: 29, weight: .bold))
                    Text("Одна идея. Claude отвечает за UX обеих платформ, Codex — за обе реализации. Затем они проверяют работу друг друга.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    StatusTag(text: "iOS · Swift", color: .blue)
                    StatusTag(text: "Android · Kotlin", color: .green)
                    StatusTag(text: "2 агента · взаимное ревью", color: .purple)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Описание идеи").font(.headline)
                    Text("Опиши проблему, взаимодействие, анимацию, состояния и критерии готовности. Можно по-русски.")
                        .font(.callout).foregroundStyle(.secondary)
                    TextEditor(text: $idea)
                        .font(.system(size: 14))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 190)
                        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator.opacity(0.6)))
                        .accessibilityLabel("Описание концепта")
                }

                Toggle(isOn: $publicAgreed) {
                    Text("Понимаю, что текст идеи и код будут опубликованы в публичном GitHub.")
                        .font(.callout)
                }
                .toggleStyle(.checkbox)

                HStack {
                    Button {
                        confirmLaunch = true
                    } label: {
                        Label("Запустить Claude + Codex", systemImage: "play.fill")
                            .fontWeight(.semibold)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.busy || idea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !publicAgreed)

                    Button("Проверить систему") { store.doctor() }
                        .disabled(store.busy)
                    if store.busy {
                        ProgressView().controlSize(.small)
                        Text("Запускаю…").foregroundStyle(.secondary)
                    }
                }
                .confirmationDialog("Запустить работу над концептом?", isPresented: $confirmLaunch) {
                    Button("Да, запустить и опубликовать спецификацию") {
                        store.launch(prompt: idea) { slug in
                            selection = slug
                            idea = ""
                            publicAgreed = false
                        }
                    }
                } message: {
                    Text("Исходный промпт попадёт в публичный репозиторий. Claude и Codex выполнят реальные модельные вызовы.")
                }

                if !store.lastResult.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Последняя команда").font(.headline)
                        Text(store.lastResult)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 9))
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle")
                    Text("Paperclip пока хранит задачи, но не запускает агентов: его штатный SSH-адаптер пытался отключить песочницу безопасности. Рабочий запуск — здесь, на Mac.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 5)
            }
            .padding(28)
            .frame(maxWidth: 850, alignment: .leading)
        }
        .navigationTitle("Новый концепт")
    }

    private func jobDetailView(_ job: LabJob) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(job.slug).font(.system(size: 25, weight: .bold))
                        Text(job.isCollaborative ? "Claude дизайн → Codex обе платформы → взаимное ревью" :
                             "Исторический пилот с разделением моделей по платформам")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusTag(text: job.state, color: job.color)
                }

                if job.isCollaborative {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Этапы выполнения").font(.headline)
                        ForEach(phases) { phase in
                            let state = store.phaseState(slug: job.slug, key: phase.key)
                            HStack {
                                Image(systemName: state == "готово" ? "checkmark.circle.fill" :
                                      state == "ошибка" ? "xmark.circle.fill" : "circle")
                                    .foregroundStyle(state == "готово" ? .green :
                                                     state == "ошибка" ? .red : .secondary)
                                Text(phase.label).font(.callout)
                                Spacer()
                                Text(state).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(17)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                    if let error = job.error {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }

                HStack {
                    Button { store.openIOS(slug: job.slug) } label: {
                        Label("Открыть iOS", systemImage: "iphone")
                    }
                    Button { store.openAndroid(slug: job.slug) } label: {
                        Label("Открыть Android", systemImage: "smartphone")
                    }
                    Button { store.openLogs(slug: job.slug) } label: {
                        Label("Папка логов", systemImage: "folder")
                    }
                    Spacer()
                    Button("Создать черновые PR") { confirmPR = true }
                        .disabled(store.busy || !job.isComplete)
                }
                .buttonStyle(.bordered)
                .confirmationDialog("Создать черновые Pull Request?", isPresented: $confirmPR) {
                    Button("Создать PR для iOS и Android") {
                        store.createPR(slug: job.slug)
                    }
                } message: {
                    Text("Исходники будут отправлены в публичный GitHub. Автоматического merge не будет.")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Лог выполнения").font(.headline)
                        Spacer()
                        if job.isCollaborative {
                            Picker("Этап", selection: $selectedLog) {
                                Text("Оркестратор").tag("pipeline")
                                ForEach(phases) { phase in
                                    Text(phase.label).tag(phase.key)
                                }
                            }
                            .frame(width: 205)
                        }
                    }
                    Text(store.log(slug: job.slug, phase: job.isCollaborative ? selectedLog :
                        (FileManager.default.fileExists(atPath:
                            LabPaths.logRoot.appendingPathComponent(job.slug + "/ios.log").path) ? "ios" : "pipeline")))
                        .textSelection(.enabled)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 185, alignment: .topLeading)
                        .padding(12)
                        .background(.black.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                }
                if !store.lastResult.isEmpty {
                    Text(store.lastResult)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .padding(26)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .navigationTitle(job.slug)
    }
}

@main
private struct TelegramConceptLabApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 850, minHeight: 600)
        }
        .defaultSize(width: 1120, height: 760)
    }
}
