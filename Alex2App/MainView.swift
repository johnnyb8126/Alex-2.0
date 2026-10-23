import SwiftUI
import AVFoundation

struct MainView: View {
    @EnvironmentObject var model: AlexModel
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var pulse = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.07, blue: 0.15), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("ALEX 2.0").font(.title.bold()).tracking(3)
                        Text(model.investorMode ? "OHMLOOM • INVESTOR MODE" : "YOUR AI COMPANION")
                            .font(.caption).foregroundStyle(.cyan)
                    }
                    Spacer()
                    Button { showHistory = true } label: { Image(systemName: "bubble.left.and.bubble.right").font(.title3) }
                    Button { showSettings = true } label: { Image(systemName: "gearshape.fill").font(.title3) }
                }.foregroundStyle(.white)
                AvatarView(speaking: model.speaking, listening: model.listening)
                    .frame(height: 310)
                Text(model.listening ? "LISTENING" : model.speaking ? "SPEAKING" : model.busy ? "THINKING" : "READY")
                    .font(.caption.monospaced().bold()).tracking(3).foregroundStyle(.cyan)
                Toggle("Investor presentation mode", isOn: $model.investorMode)
                    .tint(.cyan).font(.subheadline)
                if model.investorMode {
                    Button("Start investor introduction") {
                        Task { await model.send("Introduce yourself to our investor as Alex 2.0. Explain RepairLens and OhmLoom, their potential, and invite questions. Do not invent validated revenue, patents, costs or promises.") }
                    }.buttonStyle(.borderedProminent).tint(.indigo)
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(model.messages.suffix(8)) { message in
                                HStack {
                                    if message.role == "user" { Spacer(minLength: 36) }
                                    Text(message.content)
                                        .padding(12)
                                        .background(message.role == "user" ? Color.indigo.opacity(0.75) : Color.white.opacity(0.11))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .font(.subheadline)
                                        .textSelection(.enabled)
                                    if message.role != "user" { Spacer(minLength: 36) }
                                }.id(message.id)
                            }
                        }
                    }.onChange(of: model.messages.count) { _, _ in
                        if let id = model.messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                    }
                }
                if let error = model.error { Text(error).font(.caption).foregroundStyle(.red) }
                HStack(spacing: 12) {
                    Button {
                        Task { await model.startListening() }
                    } label: {
                        Image(systemName: model.listening ? "stop.circle.fill" : "mic.fill")
                            .frame(width: 46, height: 46)
                    }.buttonStyle(.borderedProminent).tint(model.listening ? .red : .cyan)
                    TextField("Talk to Alex...", text: $model.draft, axis: .vertical)
                        .lineLimit(1...3).padding(10)
                        .background(.white.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 12))
                    Button {
                        if model.listening { model.stopListening() }
                        Task { await model.send() }
                    } label: { Image(systemName: "arrow.up.circle.fill").font(.title) }
                        .disabled(model.busy || model.draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                HStack {
                    Text("OHMLOOM • BUILT WITH JOHNNY").font(.caption2).foregroundStyle(.gray)
                    Spacer()
                    Text("☕ CUP HOLDERS ✓").font(.caption2).foregroundStyle(.cyan)
                }
            }.padding(18)
        }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(model) }
        .sheet(isPresented: $showHistory) { HistoryView().environmentObject(model) }
    }
}

struct AvatarView: View {
    let speaking: Bool
    let listening: Bool
    @State private var animate = false
    var body: some View {
        ZStack {
            Circle().fill(.cyan.opacity(0.09)).frame(width: 280)
            Circle().stroke(.cyan.opacity(0.4), lineWidth: 2).frame(width: animate ? 276 : 255)
            Circle().stroke(.indigo.opacity(0.7), lineWidth: 6).frame(width: 228)
            RoundedRectangle(cornerRadius: 80).fill(LinearGradient(colors: [.indigo, Color(red: 0.08, green: 0.18, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 170, height: 210)
                .overlay {
                    VStack(spacing: 36) {
                        HStack(spacing: 32) {
                            Capsule().fill(.cyan).frame(width: 31, height: 8)
                            Capsule().fill(.cyan).frame(width: 31, height: 8)
                        }
                        Capsule().fill(.cyan).frame(width: speaking ? 42 : 28, height: speaking && animate ? 25 : 6)
                            .animation(.easeInOut(duration: 0.22), value: animate)
                    }
                }
                .shadow(color: .cyan.opacity(0.5), radius: 26)
            Text(listening ? "◉" : "✦").font(.title).foregroundStyle(.cyan)
                .offset(y: -117)
        }
        .onAppear { animate = true }
        .task(id: speaking) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(230))
                if Task.isCancelled { break }
                animate.toggle()
            }
        }
        .accessibilityLabel("Animated Alex avatar")
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AlexModel
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("AI server") {
                    TextField("https://your-server.example", text: $model.endpoint)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("App access token (optional)", text: $model.accessToken)
                    Text("Your AI API key belongs on the backend, never in the iPhone app.")
                        .font(.caption)
                }
                Section("Voice") {
                    Picker("Voice", selection: $model.selectedVoice) {
                        Text("Default English").tag("")
                        ForEach(AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }, id: \.identifier) { voice in
                            Text("\(voice.name) (\(voice.language))").tag(voice.identifier)
                        }
                    }
                    Text("Marco is available only if a compatible Marco voice is installed or a separate licensed voice provider is integrated.")
                        .font(.caption)
                }
                Section("Privacy") {
                    Text("Recent chat history is stored on this device. Messages are sent to your configured server for replies. Speech recognition may use Apple services.")
                        .font(.caption)
                    Button("Erase local conversation history", role: .destructive) { model.clearHistory() }
                }
            }
            .navigationTitle("Alex Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { model.saveSettings(); dismiss() } } }
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var model: AlexModel
    var body: some View {
        NavigationStack {
            List(model.messages) { message in
                VStack(alignment: .leading, spacing: 5) {
                    Text(message.role == "user" ? "YOU" : "ALEX").font(.caption.bold()).foregroundStyle(.cyan)
                    Text(message.content).textSelection(.enabled)
                }
            }.navigationTitle("Conversation History")
        }
    }
}
