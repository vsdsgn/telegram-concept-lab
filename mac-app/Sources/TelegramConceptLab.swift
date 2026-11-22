import SwiftUI
import AppKit
import Combine
import Foundation
import Darwin

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
    .init(key: "fix-android", label: "Codex · исправления Android"),
    .init(key: "verify-ios", label: "Независимая сборка Xcode"),
    .init(key: "verify-android", label: "Независимая сборка Gradle")
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
    var isVerified: Bool {
        guard isCollaborative else { return isComplete }
        return ["ios", "android"].allSatisfy { platform in
            let path = LabPaths.logRoot.appendingPathComponent(slug + "/verify-" + platform + ".exit")
            return ((try? String(contentsOf: path, encoding: .utf8)) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines) == "0"
        }
    }
    var isInterrupted: Bool {
        guard isCollaborative, state == "В процессе" else { return false }
        let pid = legacyPlatforms["__pid"].flatMap { Int($0) } ?? 0
        return pid > 0 && kill(Int32(pid), 0) != 0
    }
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
            if let pid = dict["pid"] as? Int {
                platformStatuses["__pid"] = String(pid)
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
        execute(["new", slug, prompt, "--demo"]) { success in
            if success { done(slug) }
        }
    }

    func resume(slug: String) {
        execute(["resume", slug]) { _ in }
    }

    func stop(slug: String) {
        execute(["stop", slug]) { _ in }
    }

    func createPR(slug: String) {
        execute(["prs", slug]) { success in
            if success { NSWorkspace.shared.open(URL(string: LabPaths.github.absoluteString + "/pulls")!) }
        }
    }

    func doctor() { execute(["doctor"]) { _ in } }

    func verify(slug: String) {
        execute(["verify", slug]) { _ in }
    }

    func preview(slug: String, platform: String) {
        execute(["preview", slug, platform]) { _ in }
    }

    func previewImage(slug: String, platform: String) -> NSImage? {
        NSImage(contentsOf: LabPaths.state.appendingPathComponent(
            "previews/" + slug + "/" + platform + ".png"
        ))
    }

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
                    self.lastError = "Ошибка команды \(arguments.first ?? "?") (код \(finished.terminationStatus)):\n" +
                        String(output.suffix(1200))
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
    @State private var selection = "official"
    @State private var idea = ""
    @State private var publicAgreed = false
    @State private var confirmLaunch = false
    @State private var confirmPR = false
    @State private var confirmResume = false
    @State private var confirmStop = false
    @State private var selectedLog = "pipeline"

    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var selectedJob: LabJob? { store.jobs.first(where: { $0.slug == selection }) }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Официальные исходники Telegram", systemImage: "message.fill")
                    .tag("official")
                Label("Standalone-мок", systemImage: "plus.circle")
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
            if selection == "official" {
                officialView
            } else if selection == "new" {
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

    private var officialView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Настоящие клиенты Telegram")
                    .font(.system(size: 29, weight: .bold))
                Text("Reaction Wheel интегрируется в официальные исходники Telegram 13.2 (iOS) и 13.2.2 (Android). Это НЕ прежние моки. Рабочие сборки оригинальных клиентов пока не подтверждены.")
                    .foregroundStyle(.secondary)
                ForEach(["ios", "android"], id: \.self) { platform in
                    let directory = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent("Projects/telegram-integrations/Telegram-" +
                            (platform == "ios" ? "iOS" : "Android") + "-reaction-wheel")
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(platform == "ios" ? "Telegram iOS · Xcode/Bazel" : "Telegram Android · Gradle")
                                .font(.headline)
                            Spacer()
                            StatusTag(text: "Исходники / требует сборки", color: .orange)
                        }
                        Text(directory.path)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary).textSelection(.enabled)
                        Button("Открыть исходники в Finder") {
                            NSWorkspace.shared.open(directory)
                        }
                        let log = FileManager.default.homeDirectoryForCurrentUser
                            .appendingPathComponent("Projects/telegram-integrations/" + platform + "-implementation.log")
                        if let raw = try? String(contentsOf: log, encoding: .utf8) {
                            Text(raw.components(separatedBy: .newlines).suffix(9).joined(separator: "\n"))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary).textSelection(.enabled).lineLimit(9)
                        }
                    }
                    .padding(15)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                }
                Text("Предыдущие Reaction Wheel PR содержат самостоятельные демо-приложения. Настоящая интеграция считается готовой только после сборки Telegram и проверки реакций на реальных сообщениях.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 950, alignment: .leading)
        }
        .navigationTitle("Telegram · исходники")
    }

    private var newConceptView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Отдельное демо — НЕ Telegram")
                        .font(.system(size: 29, weight: .bold))
                    Text("Этот режим создаёт standalone-мок с вымышленными сообщениями. Разработка настоящих клиентов показана в разделе «Официальные исходники Telegram» слева.")
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
                        Label("Сделать отдельный мок", systemImage: "play.fill")
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

                HStack {
                    Button { store.preview(slug: job.slug, platform: "ios") } label: {
                        Label("Демо iOS", systemImage: "iphone")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.busy || !job.isVerified)
                    Button { store.preview(slug: job.slug, platform: "android") } label: {
                        Label("Демо Android", systemImage: "smartphone")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.busy || !job.isVerified)
                    Button { store.openIOS(slug: job.slug) } label: {
                        Label("Код iOS", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Button { store.openAndroid(slug: job.slug) } label: {
                        Label("Код Android", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Button { store.openLogs(slug: job.slug) } label: {
                        Label("Логи", systemImage: "folder")
                    }
                }
                .buttonStyle(.bordered)
                HStack {
                    Spacer()
                    if job.isCollaborative && (job.state == "Ошибка" || job.isInterrupted) {
                        Button {
                            confirmResume = true
                        } label: {
                            Label("Продолжить с места ошибки", systemImage: "arrow.clockwise")
                        }
                        .disabled(store.busy)
                    }
                    if job.isCollaborative && job.state == "В процессе" && !job.isInterrupted {
                        Button("Остановить") { confirmStop = true }
                            .disabled(store.busy)
                    }
                    if job.isCollaborative && job.isComplete {
                        Button("Проверить сборки") { store.verify(slug: job.slug) }
                            .disabled(store.busy)
                    }
                    Button("Создать черновые PR") { confirmPR = true }
                        .disabled(store.busy || !job.isComplete || !job.isVerified)
                }
                .buttonStyle(.bordered)
                .confirmationDialog("Остановить работу моделей?", isPresented: $confirmStop) {
                    Button("Остановить Codex и Claude", role: .destructive) {
                        store.stop(slug: job.slug)
                    }
                } message: {
                    Text("Текущие модельные вызовы будут остановлены, результаты завершённых этапов сохранятся. Позже можно продолжить.")
                }
                .confirmationDialog("Продолжить прерванный запуск?", isPresented: $confirmResume) {
                    Button("Да, продолжить с первого незавершённого этапа") {
                        store.resume(slug: job.slug)
                    }
                } message: {
                    Text("Уже завершённые этапы не будут запущены повторно. При необходимости агент продолжит с сохранёнными файлами.")
                }
                .confirmationDialog("Создать черновые Pull Request?", isPresented: $confirmPR) {
                    Button("Создать PR для iOS и Android") {
                        store.createPR(slug: job.slug)
                    }
                } message: {
                    Text("Исходники будут отправлены в публичный GitHub. Автоматического merge не будет.")
                }

                if store.busy {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Выполняется действие. Результат появится здесь.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                if !store.lastResult.isEmpty && !store.busy {
                    Text(store.lastResult)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 9))
                }

                if store.previewImage(slug: job.slug, platform: "ios") != nil ||
                   store.previewImage(slug: job.slug, platform: "android") != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Снимки запущенных приложений").font(.headline)
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(["ios", "android"], id: \.self) { platform in
                                if let screenshot = store.previewImage(slug: job.slug, platform: platform) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(platform.uppercased())
                                            .font(.caption).foregroundStyle(.secondary)
                                        Image(nsImage: screenshot)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity, maxHeight: 280)
                                            .clipShape(RoundedRectangle(cornerRadius: 9))
                                            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 9))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
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
