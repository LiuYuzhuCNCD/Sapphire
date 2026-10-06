//
//  AudioSettingsView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-10

import SwiftUI

struct AudioSettingsView: View {
    @EnvironmentObject var settings: SettingsEditingSession
    @ObservedObject private var audioManager = MultiAudioManager.shared
    @ObservedObject private var permissionsManager = PermissionsManager.shared
    @State private var showResetAppConfirmation = false
    @State private var showResetDeviceConfirmation = false
    @State private var mixerNavigationStack: [NotchWidgetMode] = []
    @State private var selectedAdjustment: AudioSettingsAdjustment?
    @AppStorage(AudioEQ.displayedBandCountDefaultsKey) private var displayedBandCount = AudioEQBandLayout.thirtyOne.rawValue

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Text("音频")
                    .font(.largeTitle.bold())
                    .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: 0) {
                    Text("刘海")
                        .font(.headline)
                        .padding([.top, .horizontal])

                    CompactToggleRow(
                        title: "刘海中的多音频",
                        description: "在展开的刘海显示分应用混音器。",
                        isOn: Binding(
                            get: { settings.settings.notchButtonOrder.contains(.multiAudio) },
                            set: { enabled in
                                if enabled && !settings.settings.notchButtonOrder.contains(.multiAudio) {
                                    settings.settings.notchButtonOrder.append(.multiAudio)
                                } else if !enabled {
                                    settings.settings.notchButtonOrder.removeAll { $0 == .multiAudio }
                                }
                            }
                        )
                    )
                    .disabled(permissionsManager.screenRecordingStatus != .granted)
                    Divider().padding(.leading, 20)
                    CompactToggleRow(
                        title: "触感反馈",
                        description: "调节音频控件时轻微振动。",
                        isOn: $settings.settings.hapticFeedbackEnabled
                    )
                    Divider().padding(.leading, 20)
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("均衡器频段")
                            Text("选择应用与设备均衡器显示的频段数。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("均衡器频段", selection: $displayedBandCount) {
                            ForEach(AudioEQBandLayout.allCases) { layout in
                                Text(layout.displayName).tag(layout.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 110)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .modifier(SettingsContainerModifier())

                MicrophoneAmplifierSettingsView()
                    .modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("应用与设备混音器")
                            .font(.headline)
                        Text("The same volume, routing, EQ, 8D, surround, balance, and delay controls available in the notch.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    SystemAudioPanel(navigationStack: $mixerNavigationStack)
                        .frame(maxWidth: .infinity)
                        .frame(height: 430)
                }
                .modifier(SettingsContainerModifier())

                VStack(alignment: .leading, spacing: 0) {
                    Text("重置")
                        .font(.headline)
                        .padding([.top, .horizontal])

                    AudioResetRow(
                        title: "重置分应用调节",
                        subtitle: "清空所有应用的自定义音量、静音、均衡器与 8D 空间音频。",
                        buttonTitle: "Reset Apps",
                        buttonColor: .red
                    ) {
                        showResetAppConfirmation = true
                    }
                    .alert("Reset Per-App Settings?", isPresented: $showResetAppConfirmation) {
                        Button("取消", role: .cancel) { }
                        Button("重置", role: .destructive) { resetAllAppSettings() }
                    } message: {
                        Text("这会把所有应用的音量、平坦均衡器、环绕声与 8D 音效恢复默认。")
                    }

                    Divider().padding(.leading, 20)

                    AudioResetRow(
                        title: "重置设备设置",
                        subtitle: "清空所有设备的总音量、平衡、延迟与均衡器。",
                        buttonTitle: "Reset Devices",
                        buttonColor: .red
                    ) {
                        showResetDeviceConfirmation = true
                    }
                    .alert("Reset Device Settings?", isPresented: $showResetDeviceConfirmation) {
                        Button("取消", role: .cancel) { }
                        Button("重置", role: .destructive) { resetAllDeviceSettings() }
                    } message: {
                        Text("这会把所有已连接的输出设备恢复默认状态。")
                    }
                }
                .modifier(SettingsContainerModifier())

                RequiredPermissionsView(section: .audio)
            }
            .padding(25)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: permissionsManager.screenRecordingStatus) { _, newStatus in
            if newStatus == .granted, !settings.settings.notchButtonOrder.contains(.multiAudio) {
                settings.settings.notchButtonOrder.append(.multiAudio)
            }
        }
        .onChange(of: mixerNavigationStack.count) { _, _ in
            presentLatestMixerAdjustment()
        }
        .sheet(item: $selectedAdjustment) { adjustment in
            AudioSettingsAdjustmentSheet(adjustment: adjustment)
        }
    }

    private func presentLatestMixerAdjustment() {
        guard let destination = mixerNavigationStack.last else { return }
        mixerNavigationStack.removeAll()

        switch destination {
        case .multiAudioDeviceAdjust(let device):
            selectedAdjustment = .deviceAdjust(device)
        case .multiAudioEQ(let device):
            selectedAdjustment = .deviceEQ(device)
        case .multiAudioAppEQ(let bundleID, let appName):
            selectedAdjustment = .appEQ(bundleID: bundleID, appName: appName)
        case .multiAudioApp8D(let bundleID, let appName):
            selectedAdjustment = .app8D(bundleID: bundleID, appName: appName)
        case .multiAudioAppSurround(let bundleID, let appName):
            selectedAdjustment = .appSurround(bundleID: bundleID, appName: appName)
        default:
            break
        }
    }

    private func resetAllAppSettings() {
        Task { @MainActor in
            PerAppAudioController.shared.clearAllPersistedState()
            MultiAudioManager.shared.clearAllEightDAudioSettings()
            MultiAudioManager.shared.activeTaps.values.forEach { tapMap in
                tapMap.values.forEach { $0.invalidate() }
            }
            MultiAudioManager.shared.notifyAdjustmentMade(for: "ResetAll")
        }
    }

    private func resetAllDeviceSettings() {
        Task { @MainActor in
            MultiAudioManager.shared.clearAllDeviceSettings()
        }
    }
}

private enum AudioSettingsAdjustment: Identifiable {
    case deviceAdjust(AudioDevice)
    case deviceEQ(AudioDevice)
    case appEQ(bundleID: String, appName: String)
    case app8D(bundleID: String, appName: String)
    case appSurround(bundleID: String, appName: String)

    var id: String {
        switch self {
        case .deviceAdjust(let device):
            return "device-adjust-\(device.id)"
        case .deviceEQ(let device):
            return "device-eq-\(device.id)"
        case .appEQ(let bundleID, _):
            return "app-eq-\(bundleID)"
        case .app8D(let bundleID, _):
            return "app-8d-\(bundleID)"
        case .appSurround(let bundleID, _):
            return "app-surround-\(bundleID)"
        }
    }
}

private struct AudioSettingsAdjustmentSheet: View {
    let adjustment: AudioSettingsAdjustment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("音频调节")
                    .font(.headline)
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .frame(height: 48)

            Divider()

            adjustmentView
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var adjustmentView: some View {
        switch adjustment {
        case .deviceAdjust(let device):
            DeviceAdjustView(device: device)
        case .deviceEQ(let device):
            DeviceEQView(device: device)
        case .appEQ(let bundleID, let appName):
            AppEQView(bundleID: bundleID, appName: appName)
        case .app8D(let bundleID, let appName):
            EightDAudioView(bundleID: bundleID, appName: appName)
        case .appSurround(let bundleID, let appName):
            SurroundAudioView(bundleID: bundleID, appName: appName)
        }
    }
}

// MARK: - Microphone gain preview

private struct MicrophoneAmplifierSettingsView: View {
    @ObservedObject private var mic = MicrophoneUsageManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("麦克风增益预览")
                .font(.headline)
                .padding([.top, .horizontal])

            CompactToggleRow(
                title: "预览增益",
                description: "Applies gain to Sapphire's live level meter so you can check clipping. Other apps still receive the original microphone signal.",
                isOn: $mic.amplifierEnabled
            )

            Divider().padding(.leading, 20)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("预览增益")
                    Spacer()
                    Text("×\(mic.amplifierGain, specifier: "%.1f")")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Slider(value: $mic.amplifierGain, in: 1...4, step: 0.1)
                    .tint(.orange)
                    .disabled(!mic.amplifierEnabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().padding(.leading, 20)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(mic.isClipping ? "Clipping detected" : "Live input level", systemImage: mic.isClipping ? "exclamationmark.triangle.fill" : "mic.fill")
                        .foregroundStyle(mic.isClipping ? .red : .primary)
                    Spacer()
                    Text("\(Int(mic.audioLevel * 100))%")
                        .font(.caption.monospacedDigit())
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.18))
                        Capsule()
                            .fill(mic.isClipping ? Color.red : (mic.audioLevel > 0.85 ? Color.orange : Color.green))
                            .frame(width: proxy.size.width * CGFloat(mic.audioLevel))
                        Rectangle()
                            .fill(Color.red.opacity(0.8))
                            .frame(width: 2)
                            .offset(x: max(0, proxy.size.width - 2))
                    }
                }
                .frame(height: 8)
                Text(mic.isMicInUse ? (mic.isClipping ? "Lower the gain or microphone input level." : "Peak: \(Int(mic.peakLevel * 100))%") : "Start using the microphone to see its level.")
                    .font(.caption)
                    .foregroundStyle(mic.isClipping ? .red : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Rows

private struct AudioResetRow: View {
    let title: String
    let subtitle: String
    let buttonTitle: String
    let buttonColor: Color
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
                .tint(buttonColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}