import SwiftUI

enum SceneStageLayout: Equatable {
    case expanded
    case compact
}

// MARK: - Scene Stage

struct SceneStageView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var deskPet: DeskPetController
    let layout: SceneStageLayout
    var bottomInset: CGFloat = 0
    @State private var partnerPopoverPresented = false
    @State private var endFocusConfirmationPresented = false

    init(model: AppModel, layout: SceneStageLayout, bottomInset: CGFloat = 0) {
        self.model = model
        self.deskPet = model.deskPet
        self.layout = layout
        self.bottomInset = bottomInset
    }

    var body: some View {
        ZStack {
            SceneNativeRenderer(model: model)

            VStack(alignment: .leading, spacing: 10) {
                SceneStageHeader(
                    eyebrow: model.selectedScene.eyebrow,
                    headline: model.selectedScene.headline,
                    roomCode: model.currentDeskRoom?.code,
                    layout: layout
                )

                if model.activeFocusSession != nil {
                    Button {
                        endFocusConfirmationPresented = true
                    } label: {
                        Label("结束专注", systemImage: "stop.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 10)
                            .frame(minHeight: 32)
                    }
                    .buttonStyle(ZaichangPlainButtonStyle())
                    .foregroundStyle(.white)
                    .background(.black.opacity(0.28))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.white.opacity(0.58), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .adaptiveHitTarget(minHeight: 32)
                    .accessibilityLabel("结束专注")
                }
            }
            .shadow(color: .black.opacity(0.55), radius: 8, y: 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 30)
            .padding(.leading, 28)

            if let partner = model.currentDeskPartner {
                Button {
                    partnerPopoverPresented.toggle()
                } label: {
                    if layout == .compact {
                        Text(partner.character)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Palette.amberSoft)
                            .frame(width: 34, height: 34)
                            .adaptiveHitTarget(minWidth: 34, minHeight: 34)
                            .background(Color(red: 0.34, green: 0.29, blue: 0.24))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(Palette.moss)
                                    .frame(width: 8, height: 8)
                                    .overlay(Circle().stroke(.black.opacity(0.7), lineWidth: 2))
                                    .offset(x: 2, y: 2)
                            }
                    } else {
                        HStack(spacing: 9) {
                            Text(partner.character)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Palette.amberSoft)
                                .frame(width: 34, height: 34)
                                .background(Color(red: 0.34, green: 0.29, blue: 0.24))
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(partner.name)在这里").font(.system(size: 12, weight: .semibold))
                                Text("已专注 \(partner.focusSeconds / 60) 分钟").font(.system(size: 10)).foregroundStyle(Palette.muted)
                            }
                            Circle()
                                .fill(Color(red: 0.45, green: 0.73, blue: 0.48))
                                .frame(width: 7, height: 7)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .adaptiveHitTarget(minHeight: 38)
                        .background(.black.opacity(0.58))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.16)))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                }
                .buttonStyle(ZaichangPlainButtonStyle())
                .accessibilityLabel("查看同桌\(partner.name)的状态")
                .popover(isPresented: $partnerPopoverPresented, arrowEdge: .top) {
                    PartnerPopover(
                        model: model,
                        partner: partner,
                        isPresented: $partnerPopoverPresented
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 24)
                .padding(.trailing, 22)
            } else if let room = model.currentDeskRoom {
                Button {
                    model.activeSheet = .desk
                } label: {
                    Label(layout == .compact ? "" : "等待同桌 · \(room.code)", systemImage: "hourglass")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, layout == .compact ? 10 : 12)
                        .frame(minWidth: layout == .compact ? 38 : nil, minHeight: 38)
                        .adaptiveHitTarget(minWidth: 38, minHeight: 38)
                        .background(.black.opacity(0.58))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.16)))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(ZaichangPlainButtonStyle())
                .accessibilityLabel("查看等待中的同桌房间")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 24)
                .padding(.trailing, 22)
            }

            if let suggestion = model.activeSuggestion {
                PresenceSuggestionView(model: model, suggestion: suggestion)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.leading, layout == .compact ? 14 : 28)
                    .padding(.trailing, layout == .compact ? 14 : 28)
                    .padding(.bottom, 86 + bottomInset)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if !deskPet.isFloating {
                DeskPetPairOverlay(
                    controller: deskPet,
                    partnerProfile: deskPet.activePartnerProfile,
                    partnerName: model.currentDeskPartner?.name,
                    onPartnerDoubleTap: { model.nudgeDeskMate() }
                )
                    .padding(.trailing, layout == .compact ? 14 : 22)
                    .padding(.bottom, 84 + bottomInset)
                    .transition(.scale.combined(with: .opacity))
            }

            SceneControlsView(model: model, layout: layout)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.horizontal, layout == .compact ? 14 : 22)
                .padding(.bottom, 22 + bottomInset)
        }
        .clipped()
        .confirmationDialog(
            "现在结束这一段专注？",
            isPresented: $endFocusConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("确认结束专注", role: .destructive) {
                model.manuallyEndFocusSession()
            }
            Button("继续专注", role: .cancel) {}
        } message: {
            Text("结束后会引导你进入留声机，Todo 不会被自动完成。")
        }
    }
}

private struct PartnerPopover: View {
    @ObservedObject var model: AppModel
    let partner: DeskPartner
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Text(partner.character)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.amberSoft)
                    .frame(width: 42, height: 42)
                    .background(Color(red: 0.34, green: 0.29, blue: 0.24))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 3) {
                    Text(partner.name).font(.system(size: 13, weight: .semibold))
                    Label("专注中 · \(partner.focusText)", systemImage: "circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.moss)
                }
            }
            .padding(.bottom, 14)

            Divider().overlay(Palette.line)

            PopoverAction(title: "留一句话", symbol: "mic") {
                open(.voice)
            }
            PopoverAction(title: "查看同桌房间", symbol: "person.2") {
                open(.desk)
            }
        }
        .padding(14)
        .frame(width: 250)
        .background(Palette.surface2)
        .foregroundStyle(Palette.ink)
    }

    private func open(_ sheet: AppSheet) {
        isPresented = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            model.activeSheet = sheet
        }
    }
}

private struct SceneStageHeader: View {
    let eyebrow: String
    let headline: String
    let roomCode: String?
    let layout: SceneStageLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(eyebrow)
                    .eyebrowStyle()
                Spacer(minLength: 8)
                if let roomCode {
                    Text("房间 \(roomCode)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.07), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 1))
                }
            }

            Text(headline)
                .font(.system(size: layout == .compact ? 20 : 24, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.20), radius: 14, y: 4)
        .frame(maxWidth: layout == .compact ? 310 : 380, alignment: .leading)
    }
}

private struct PopoverAction: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol).frame(width: 18)
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.muted)
            }
            .font(.system(size: 11, weight: .medium))
            .adaptiveFullWidthHitTarget(minHeight: 38)
        }
        .buttonStyle(ZaichangPlainButtonStyle())
    }
}

private struct PresenceSuggestionView: View {
    @ObservedObject var model: AppModel
    let suggestion: PresenceSuggestion

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lamp.desk")
                .foregroundStyle(Palette.amberSoft)
                .frame(width: 30, height: 30)
                .background(Color(red: 0.36, green: 0.28, blue: 0.18))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 7) {
                Text("在场建议")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.amberSoft)
                Text(suggestion.message)
                    .font(.system(size: 12))
                    .lineLimit(3)

                HStack(spacing: 8) {
                    Button {
                        model.performSuggestion(suggestion.id)
                    } label: {
                        Label(
                            suggestion.primaryOption.title,
                            systemImage: suggestion.primaryOption.action.symbol
                        )
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .frame(minHeight: 30)
                            .adaptiveHitTarget(minHeight: 30)
                            .foregroundStyle(Color(red: 0.17, green: 0.13, blue: 0.09))
                            .background(Palette.amber)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(ZaichangPlainButtonStyle())

                    if let secondaryOption = suggestion.secondaryOption {
                        Button {
                            model.performSuggestion(suggestion.id, action: secondaryOption.action)
                        } label: {
                            Label(secondaryOption.title, systemImage: secondaryOption.action.symbol)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10)
                                .frame(minHeight: 30)
                                .adaptiveHitTarget(minHeight: 30)
                                .foregroundStyle(Palette.ink)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.24))
                                )
                        }
                        .buttonStyle(ZaichangPlainButtonStyle())
                    }
                }
            }
            .frame(maxWidth: 330, alignment: .leading)
            .layoutPriority(1)

            Button {
                model.dismissSuggestion(suggestion.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .adaptiveHitTarget(minWidth: 28, minHeight: 28)
            }
            .buttonStyle(ZaichangPlainButtonStyle())
            .accessibilityLabel("关闭在场建议")
        }
        .padding(10)
        .background(.black.opacity(0.70))
        .overlay(alignment: .leading) { Rectangle().fill(Palette.amber).frame(width: 2) }
        .frame(maxWidth: 480, alignment: .leading)
    }
}

private extension PresenceSuggestionAction {
    var symbol: String {
        switch self {
        case .beginFocus: "play.fill"
        case .resumeFocus: "play.fill"
        case .inviteDeskMate: "person.badge.plus"
        case .openPhonograph: "record.circle"
        case .beginRest: "cup.and.saucer"
        }
    }
}

private struct SceneControlsView: View {
    @ObservedObject var model: AppModel
    let layout: SceneStageLayout
    @State private var presencePickerPresented = false

    @ViewBuilder
    var body: some View {
        if layout == .compact {
            Group {
                compactControls
            }
        } else {
            Group {
                expandedControls
            }
        }
    }

    @ViewBuilder
    private var expandedControls: some View {
        HStack(spacing: 10) {
            Button {
                presencePickerPresented.toggle()
            } label: {
                HStack(spacing: 8) {
                    Circle().fill(Palette.moss).frame(width: 8, height: 8)
                    Text(model.presence.title).font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.up").font(.system(size: 9, weight: .bold))
                }
                .frame(width: 126, height: 46)
                .liquidSceneControl()
            }
            .buttonStyle(ZaichangPlainButtonStyle())
            .popover(isPresented: $presencePickerPresented, arrowEdge: .bottom) {
                VStack(spacing: 0) {
                    ForEach(PresenceMode.selectable) { mode in
                        Button {
                            model.setPresence(mode)
                            presencePickerPresented = false
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: mode.symbol)
                                    .foregroundStyle(Palette.amber)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.title).font(.system(size: 12, weight: .semibold))
                                    Text(mode.detail).font(.system(size: 10)).foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                if model.presence == mode {
                                    Image(systemName: "checkmark").foregroundStyle(Palette.moss)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(width: 240, height: 50)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(ZaichangPlainButtonStyle())
                        if mode != PresenceMode.selectable.last {
                            Divider().overlay(Palette.line)
                        }
                    }
                }
                .padding(.vertical, 6)
                .background(Palette.surface2)
            }

            HStack(spacing: 4) {
                Button { model.toggleTimer() } label: {
                    Image(systemName: model.timerRunning ? "pause" : "play")
                        .adaptiveHitTarget(minWidth: 32, minHeight: 32)
                }
                .accessibilityLabel(model.timerRunning ? "暂停计时" : "开始计时")
                .help(model.timerRunning ? "暂停计时" : "开始计时")
                VStack(spacing: 1) {
                    Text(model.timerText)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    Text("方案收尾").font(.system(size: 9)).foregroundStyle(Palette.muted)
                }
                .frame(width: 72)
                Button { model.resetTimer() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .adaptiveHitTarget(minWidth: 32, minHeight: 32)
                }
                .disabled(model.activeFocusSession != nil)
                .accessibilityLabel("重置计时器")
                .help("重置计时器")
            }
            .buttonStyle(ZaichangPlainButtonStyle())
            .frame(height: 46)
            .padding(.horizontal, 5)
            .liquidSceneControl()

            if model.supportsWeatherEffects {
                SceneIconButton(
                    symbol: "cloud.sun",
                    isOn: model.weatherEffectsEnabled,
                    onColor: Palette.blue,
                    help: "窗外天气",
                    action: model.toggleWeather
                )
            }
            Menu {
                Button {
                    model.toggleAmbient()
                } label: {
                    Label(
                        model.ambientEnabled ? "关闭环境声音" : "打开环境声音",
                        systemImage: model.ambientEnabled ? "speaker.slash" : "speaker.wave.2"
                    )
                }
                Divider()
                ForEach(model.availableAmbientPresets, id: \.self) { preset in
                    Button {
                        model.selectAmbientPreset(preset)
                    } label: {
                        if preset == model.selectedScene.ambientPreset {
                            Label(preset.displayName, systemImage: "checkmark")
                        } else {
                            Text(preset.displayName)
                        }
                    }
                }
            } label: {
                Image(systemName: model.ambientEnabled ? "speaker.wave.2" : "speaker.slash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(model.ambientEnabled ? Palette.blue : Color.gray)
                    .frame(width: 46, height: 46)
                    .liquidSceneControl()
            }
            .buttonStyle(ZaichangPlainButtonStyle())
            .menuIndicator(.hidden)
            .help("选择环境声音")
            .accessibilityLabel("选择环境声音")
        }
    }

    private var compactControls: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(PresenceMode.selectable) { mode in
                    Button {
                        model.setPresence(mode)
                    } label: {
                        Label(mode.title, systemImage: mode.symbol)
                    }
                }
            } label: {
                Label(model.presence.title, systemImage: model.presence.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .frame(width: 96, height: 44)
                    .liquidSceneControl()
            }
            .buttonStyle(ZaichangPlainButtonStyle())
            .menuIndicator(.hidden)

            HStack(spacing: 2) {
                Button { model.toggleTimer() } label: {
                    Image(systemName: model.timerRunning ? "pause" : "play")
                        .adaptiveHitTarget(minWidth: 26, minHeight: 30)
                }
                .accessibilityLabel(model.timerRunning ? "暂停计时" : "开始计时")
                Text(model.timerText)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .frame(width: 60)
                Button { model.resetTimer() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .adaptiveHitTarget(minWidth: 26, minHeight: 30)
                }
                .disabled(model.activeFocusSession != nil)
                .accessibilityLabel("重置计时器")
            }
            .buttonStyle(ZaichangPlainButtonStyle())
            .frame(
                width: InteractionMetrics.minimumHitDimension * 2 + 64,
                height: 44
            )
            .liquidSceneControl()

            Menu {
                if model.supportsWeatherEffects {
                    Toggle(isOn: binding(for: \AppModel.weatherEffectsEnabled, toggle: model.toggleWeather)) {
                        Label("窗外天气", systemImage: "cloud.sun")
                    }
                }
                Toggle(isOn: binding(for: \AppModel.ambientEnabled, toggle: model.toggleAmbient)) {
                    Label(model.selectedScene.ambientPreset.displayName, systemImage: "speaker.wave.2")
                }
                Divider()
                ForEach(model.availableAmbientPresets, id: \.self) { preset in
                    Button {
                        model.selectAmbientPreset(preset)
                    } label: {
                        if preset == model.selectedScene.ambientPreset {
                            Label(preset.displayName, systemImage: "checkmark")
                        } else {
                            Text(preset.displayName)
                        }
                    }
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 44, height: 44)
                    .liquidSceneControl()
            }
            .buttonStyle(ZaichangPlainButtonStyle())
            .menuIndicator(.hidden)
            .accessibilityLabel("场景选项")
        }
    }

    private func binding(
        for keyPath: KeyPath<AppModel, Bool>,
        toggle: @escaping () -> Void
    ) -> Binding<Bool> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: { newValue in
                if newValue != model[keyPath: keyPath] { toggle() }
            }
        )
    }
}

private struct SceneIconButton: View {
    let symbol: String
    let isOn: Bool
    let onColor: Color
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isOn ? onColor : Color.gray)
                .frame(width: 46, height: 46)
                .liquidSceneControl()
        }
        .buttonStyle(ZaichangPlainButtonStyle())
        .help(help)
        .accessibilityLabel(help)
        .accessibilityValue(isOn ? "已打开" : "已关闭")
    }
}
