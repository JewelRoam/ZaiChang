import PhotosUI
import SwiftUI

struct SettingsSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    enum Category: String, CaseIterable, Identifiable {
        case api = "API 设置"
        case ownPet = "我的桌宠"
        case reset = "重置数据"
        var id: String { rawValue }
    }

    @State private var category: Category = .api
    @State private var config = APIConfiguration.load()
    @State private var saveError: String?
    @State private var didSave = false
    @State private var ownPetPhotoItem: PhotosPickerItem?
    @State private var resetConfirmationPresented = false
    @State private var didReset = false
    @FocusState private var focusSink: Bool

    var body: some View {
        SheetContainer(eyebrow: "", title: "设置", dismiss: dismiss, maxWidth: 620) {
            VStack(alignment: .leading, spacing: 16) {
                Picker("", selection: $category) {
                    ForEach(Category.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                switch category {
                case .api: apiSettings
                case .ownPet: ownPetSettings
                case .reset: resetSettings
                }
            }
        }
    }

    private var apiSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 吸收 macOS 打开时的初始焦点，避免第一个输入框被自动高亮
                TextField("", text: .constant(""))
                    .focused($focusSink)
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .accessibilityHidden(true)

                textModelSection
                imageModelSection
                mattingSection

                if let saveError {
                    Label(saveError, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.90, green: 0.52, blue: 0.46))
                }

                HStack {
                    if didSave {
                        Label("已保存", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.amberSoft)
                    }
                    Spacer()
                    Button("保存", action: save)
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.amber)
                }
                .padding(.top, 4)
            }
            .padding(.bottom, 12)
        }
        .frame(height: 480)
    }

    private var ownPetSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ownDeskPetSection
            }
            .padding(.bottom, 12)
        }
        .frame(height: 480)
    }

    private var resetSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section(title: "重置 APP 数据", subtitle: "清空所有本地持久化数据，恢复到初始状态") {
                    VStack(alignment: .leading, spacing: 12) {
                        Label {
                            Text("将删除以下内容，且不可恢复：")
                                .font(.system(size: 11, weight: .semibold))
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Palette.amber)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            resetItem("留声与记忆")
                            resetItem("生成的场景与背景图")
                            resetItem("好友桌宠与我的桌宠形象")
                            resetItem("其他本地缓存与偏好")
                        }
                        Text("API 设置会被保留，不会清除。")
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.muted)

                        Button(role: .destructive) {
                            resetConfirmationPresented = true
                        } label: {
                            Label("重置 APP 数据", systemImage: "trash")
                                .font(.system(size: 12, weight: .semibold))
                                .adaptiveFullWidthHitTarget(minHeight: 38)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.82, green: 0.32, blue: 0.28))
                        .padding(.top, 4)

                        if didReset {
                            Label("已重置全部数据", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Palette.amberSoft)
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .frame(height: 480)
        .confirmationDialog(
            "确定要重置全部数据吗？",
            isPresented: $resetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("清空全部数据", role: .destructive, action: performReset)
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作会删除全部本地持久化数据，且无法恢复。界面会立即恢复到初始状态。")
        }
    }

    private func resetItem(_ text: String) -> some View {
        Label(text, systemImage: "circle.fill")
            .labelStyle(.titleAndIcon)
            .font(.system(size: 10))
            .foregroundStyle(Palette.muted)
            .imageScale(.small)
    }

    private var textModelSection: some View {
        section(title: "文本模型", subtitle: "用于留声、建议等文字生成（OpenAI 兼容接口）") {
            field("Base URL", text: $config.text.baseURL, placeholder: "https://api.openai.com/v1")
            secureField("API Key", text: $config.text.apiKey)
            field("Model", text: $config.text.model, placeholder: "gpt-4o-mini")
        }
    }

    private var imageModelSection: some View {
        section(title: "图像模型", subtitle: "用于生成桌宠形象与场景背景") {
            providerPicker(selection: $config.image.provider)
            secureField("API Key", text: $config.image.apiKey)
            if config.image.provider == .openAI {
                field("Base URL", text: $config.image.baseURL, placeholder: "https://api.openai.com/v1")
            } else {
                field("Endpoint", text: $config.image.endpoint, placeholder: "https://dashscope.aliyuncs.com/...")
            }
            field("桌宠模型 Model", text: $config.image.model, placeholder: "qwen-image-edit-plus")
            field("桌宠尺寸 Size", text: $config.image.size, placeholder: "1024x1024")
            field("场景模型 Scene Model", text: $config.image.sceneModel, placeholder: "qwen-image-3.0")
            field("场景尺寸 Scene Size", text: $config.image.sceneSize, placeholder: "1664x928")
        }
    }

    private var mattingSection: some View {
        section(title: "抠图模型", subtitle: "把生成的桌宠处理为透明背景") {
            mattingProviderPicker(selection: $config.matting.provider)
            if config.matting.provider != .disabled {
                secureField("API Key", text: $config.matting.apiKey)
                field("Endpoint", text: $config.matting.endpoint, placeholder: "https://api.remove.bg/v1.0/removebg")
            }
        }
    }

    private var ownDeskPetSection: some View {
        section(title: "我的桌宠", subtitle: "用你的照片生成一个专属桌宠形象") {
            OwnDeskPetSettingsContent(controller: model.ownDeskPet, photoItem: $ownPetPhotoItem)
        }
    }

    // PLACEHOLDER_HELPERS

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(Palette.muted)
            }
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .background(Palette.surface3)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
#if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
#endif
        }
    }

    private func secureField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
            SecureField("", text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
        }
    }

    private func providerPicker(selection: Binding<APIConfiguration.Provider>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Provider").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
            Picker("", selection: selection) {
                Text("DashScope").tag(APIConfiguration.Provider.dashScope)
                Text("OpenAI 兼容").tag(APIConfiguration.Provider.openAI)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private func mattingProviderPicker(selection: Binding<APIConfiguration.Matting.Provider>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Provider").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
            Picker("", selection: selection) {
                Text("关闭").tag(APIConfiguration.Matting.Provider.disabled)
                Text("remove.bg").tag(APIConfiguration.Matting.Provider.removeBG)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private func save() {
        do {
            try config.save()
            saveError = nil
            withAnimation { didSave = true }
        } catch {
            didSave = false
            saveError = "保存失败：\(error.localizedDescription)"
        }
    }

    private func performReset() {
        model.resetAllData()
        saveError = nil
        didSave = false
        withAnimation { didReset = true }
    }
}

/// 复用好友桌宠的选图/生成/预览流程，管理「我的桌宠」形象。
private struct OwnDeskPetSettingsContent: View {
    @ObservedObject var controller: OwnDeskPetController
    @Binding var photoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch controller.state {
            case .idle, .failed:
                if let data = controller.displayImageData {
                    currentPreview(
                        data: data,
                        caption: controller.isUsingDefaultImage
                            ? "当前是默认桌宠形象，可上传照片生成专属形象。"
                            : "当前桌宠形象，可重新选择照片更换。"
                    )
                }
                photoPicker(title: controller.isUsingDefaultImage ? "上传照片生成" : "更换我的形象")
                if case let .failed(message) = controller.state {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 0.90, green: 0.52, blue: 0.46))
                }
            case .photoSelected:
                HStack(spacing: 10) {
                    if let data = controller.selectedPhotoData {
                        DeskPetImage(data: data)
                            .frame(width: 54, height: 54)
                            .background(Palette.surface3)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("照片已经准备好").font(.system(size: 11, weight: .semibold))
                        Text("生成时会自动处理为透明背景。")
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Button("生成", action: controller.generate)
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.amber)
                }
            case .generating:
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small).tint(Palette.amber)
                    Text("正在生成我的桌宠")
                        .font(.system(size: 11, weight: .semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            case .ready:
                if let data = controller.displayImageData {
                    currentPreview(data: data, caption: "桌宠已经生成，会出现在场景里。")
                }
                photoPicker(title: "更换我的形象")
            }
        }
    }

    private func currentPreview(data: Data, caption: String) -> some View {
        HStack(spacing: 10) {
            DeskPetImage(data: data)
                .frame(width: 64, height: 64)
                .background(Palette.surface3)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 4) {
                Text("我的桌宠预览").font(.system(size: 11, weight: .semibold))
                Text(caption)
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
        }
    }

    private func photoPicker(title: String) -> some View {
        DeskPetPhotoPicker(selection: $photoItem) { data in
            controller.selectPhoto(data)
        } label: {
            Label(title, systemImage: "photo.badge.plus")
                .font(.system(size: 11, weight: .semibold))
                .adaptiveFullWidthHitTarget(minHeight: 38)
                .foregroundStyle(Palette.ink)
                .background(Palette.surface3)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.16)))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(ZaichangPlainButtonStyle())
    }
}
