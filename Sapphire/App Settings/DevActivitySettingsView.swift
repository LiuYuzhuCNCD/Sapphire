//
//  DevActivitySettingsView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-12
//

import SwiftUI

struct DevActivitySettingsView: View {
    @EnvironmentObject var settings: SettingsEditingSession
    @ObservedObject private var monitor = DevActivityMonitor.shared

    private func kindBinding(_ kind: DevTaskKind, keyPath: WritableKeyPath<Settings, Set<String>>) -> Binding<Bool> {
        Binding(
            get: { settings.settings[keyPath: keyPath].contains(kind.rawValue) },
            set: { isOn in
                if isOn {
                    settings.settings[keyPath: keyPath].insert(kind.rawValue)
                } else {
                    settings.settings[keyPath: keyPath].remove(kind.rawValue)
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("开发者活动")
                    .font(.largeTitle.bold())
                    .padding(.bottom)

                detectionSection
                whatIsRunningSection
                accuracySection
                stayAwakeSection
                supportedToolsSection
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear { monitor.refreshNow() }
    }

    // MARK: - Sections

    private var detectionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToggleRow(
                title: "在刘海显示正在运行的任务",
                description: "有 AI 智能体、构建或终端命令运行时显示实时活动。",
                isOn: $settings.settings.devActivityEnabled
            )

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "AI 代理",
                description: "Claude、Codex、Cursor、Antigravity、GitHub Copilot、Devin/Windsurf、Gemini、Aider 等编程智能体。",
                isOn: kindBinding(.ai, keyPath: \.devActivityKinds)
            )

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "构建与测试",
                description: "Xcode、Android Studio 与 Gradle、Swift、cargo、Go、npm 系列、make、Docker 以及测试运行。",
                isOn: kindBinding(.build, keyPath: \.devActivityKinds)
            )

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "终端命令",
                description: "你在终端、iTerm、Warp、Ghostty 或编辑器内置终端里启动的任何长时任务。监听器与开发服务器会被忽略，因为它们不会结束。",
                isOn: kindBinding(.command, keyPath: \.devActivityKinds)
            )

            Divider().padding(.leading, 20)

            ToggleRow(
                title: "优先于其他活动",
                description: "把正在运行的任务与通知同级排序，而非与常驻读数同级，这样播放音乐时也能显示。",
                isOn: $settings.settings.devActivityHighPriority
            )
        }
        .modifier(SettingsContainerModifier())
    }

    private var whatIsRunningSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("当前检测到")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Button("刷新") { monitor.refreshNow() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            .padding()

            Divider().padding(.leading, 20)

            if monitor.tasks.isEmpty {
                Text(settings.settings.devActivityEnabled || settings.settings.caffeinateAutoDuringTasks
                     ? "Nothing running. Start a build or send an agent a prompt and it will appear here."
                     : "Detection is off. Turn on the notch activity or auto-caffeinate above to start watching.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(monitor.tasks) { task in
                    DevTaskRow(task: task)
                    if task.id != monitor.tasks.last?.id {
                        Divider().padding(.leading, 20)
                    }
                }
            }
        }
        .modifier(SettingsContainerModifier())
    }

    private var accuracySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToggleRow(
                title: "检测编辑器内的智能体",
                description: "Cursor、Antigravity、Devin、VS Code 与 Zed 把智能体放在编辑器进程内，因此其活动由工作强度推断。若空闲打字被误判为智能体运行，请关闭此项。",
                isOn: $settings.settings.devActivityDetectIDEAgents
            )

            Divider().padding(.leading, 20)

            VStack(alignment: .leading, spacing: 4) {
                CustomSliderRowView(
                    label: "灵敏度",
                    value: $settings.settings.devActivitySensitivity,
                    range: 0.4...2.0,
                    specifier: "%.1f×"
                )
                Text("数值低能捕捉更安静的任务，但可能把繁忙的编辑器误判为运行中的智能体。数值高只报告持续活动。仅在运行时存在的命令行工具不受影响。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .modifier(SettingsContainerModifier())
    }

    private var stayAwakeSection: some View { CaffeineAutoTaskSettingsView() }

    private var supportedToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("检测原理")
                .font(.system(size: 14, weight: .medium))

            Text("""
            Sapphire watches your own processes — nothing is read from inside an app, no accessibility \
            permission is used, and nothing leaves the Mac.

            Tools that only exist while they run (xcodebuild, cargo, gradle, npm run build, a command you \
            typed) are detected the moment they start. Tools that stay resident between turns (Claude, \
            Codex, an editor's built-in agent, a Gradle daemon) are reported only while they are actually \
            working, which is why sensitivity exists.
            """)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SettingsContainerModifier())
    }
}

private struct DevTaskRow: View {
    let task: DevTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.tool.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(task.tool.tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 13, weight: .medium))
                HStack(spacing: 6) {
                    Text(task.kind.displayName)
                    if !task.detail.isEmpty {
                        Text("·")
                        Text(task.detail)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(DevTaskFormatting.elapsed(task.elapsed))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

enum DevTaskFormatting {
    static func elapsed(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct CaffeineAutoTaskSettingsView: View {
    @EnvironmentObject var settings: SettingsEditingSession
    @ObservedObject private var monitor = DevActivityMonitor.shared

    private var unmonitoredKinds: [DevTaskKind] {
        DevTaskKind.allCases.filter {
            settings.settings.caffeinateAutoTaskKinds.contains($0.rawValue)
                && !settings.settings.devActivityKinds.contains($0.rawValue)
        }
    }

    private var runningSummary: String {
        let kinds = settings.settings.caffeinateAutoTaskKinds
        let relevant = monitor.tasks.filter { kinds.contains($0.kind.rawValue) }
        guard let first = relevant.first else { return "Nothing running" }
        if relevant.count == 1 { return first.title }
        return "\(first.title) + \(relevant.count - 1) more"
    }

    private func kindBinding(_ kind: DevTaskKind) -> Binding<Bool> {
        Binding(
            get: { settings.settings.caffeinateAutoTaskKinds.contains(kind.rawValue) },
            set: { isOn in
                if isOn {
                    settings.settings.caffeinateAutoTaskKinds.insert(kind.rawValue)
                } else {
                    settings.settings.caffeinateAutoTaskKinds.remove(kind.rawValue)
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ToggleRow(
                title: "任务运行期间保持唤醒",
                description: "有 AI 智能体、构建或终端命令启动时自动开启防休眠，全部结束后再关闭。你自己开启的防休眠不会被它关掉。",
                isOn: $settings.settings.caffeinateAutoDuringTasks
            )

            if settings.settings.caffeinateAutoDuringTasks {
                Divider().padding(.leading, 20)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("当前检测到")
                        Text(runningSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Circle()
                        .fill(monitor.isBusy ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
                .padding()

                Divider().padding(.leading, 20)

                ToggleRow(title: "AI 代理", description: "", isOn: kindBinding(.ai))

                Divider().padding(.leading, 20)

                ToggleRow(title: "构建与测试", description: "", isOn: kindBinding(.build))

                Divider().padding(.leading, 20)

                ToggleRow(
                    title: "终端命令",
                    description: "默认关闭——并非每条长命令都值得让屏幕常亮。",
                    isOn: kindBinding(.command)
                )

                Divider().padding(.leading, 20)

                VStack(alignment: .leading, spacing: 4) {
                    CustomSliderRowView(
                        label: "完成后保持唤醒",
                        value: $settings.settings.caffeinateAutoTaskGrace,
                        range: 0...600,
                        specifier: "%.0fs"
                    )
                    Text("最后一个任务结束后的宽限期，避免连续运行之间显示器休眠。检测设置在「开发者活动」中。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !unmonitoredKinds.isEmpty {
                        Label(
                            "\(unmonitoredKinds.map(\.displayName).formatted(.list(type: .and))) "
                            + "\(unmonitoredKinds.count == 1 ? "is" : "are") switched off in Dev Activity, "
                            + "so nothing of that kind will keep the Mac awake.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
                .padding()
            }
        }
        .modifier(SettingsContainerModifier())
        .onAppear { monitor.refreshNow() }
    }
}