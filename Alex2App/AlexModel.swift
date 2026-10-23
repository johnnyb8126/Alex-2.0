import Foundation
import SwiftUI
import Speech
import AVFoundation

struct ChatMessage: Codable, Identifiable {
    var id = UUID()
    var role: String
    var content: String
}

@MainActor final class AlexModel: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var messages: [ChatMessage] = []
    @Published var draft = ""
    @Published var endpoint = UserDefaults.standard.string(forKey: "endpoint") ?? ""
    @Published var accessToken = UserDefaults.standard.string(forKey: "accessToken") ?? ""
    @Published var investorMode = false
    @Published var listening = false
    @Published var speaking = false
    @Published var busy = false
    @Published var error: String?
    @Published var selectedVoice = UserDefaults.standard.string(forKey: "voice") ?? ""
    private let synth = AVSpeechSynthesizer()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    override init() {
        super.init()
        synth.delegate = self
        if let data = UserDefaults.standard.data(forKey: "messages"),
           let stored = try? JSONDecoder().decode([ChatMessage].self, from: data) { messages = stored }
    }
    func saveSettings() {
        UserDefaults.standard.set(endpoint.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "endpoint")
        UserDefaults.standard.set(accessToken, forKey: "accessToken")
        UserDefaults.standard.set(selectedVoice, forKey: "voice")
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(Array(messages.suffix(100))) { UserDefaults.standard.set(data, forKey: "messages") }
    }
    func clearHistory() { messages = []; persist() }
    func say(_ text: String) {
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.51
        if let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.identifier == selectedVoice }) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        synth.speak(utterance)
    }
    func stopSpeaking() { synth.stopSpeaking(at: .immediate); speaking = false }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = true }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false }
    }
    func send(_ value: String? = nil) async {
        let content = (value ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !busy else { return }
        draft = ""; error = nil; busy = true
        messages.append(ChatMessage(role: "user", content: content)); persist()
        defer { busy = false }
        guard let url = URL(string: endpoint), url.scheme == "https" || (url.host == "localhost" && url.scheme == "http") else {
            error = "Configure a valid HTTPS server URL in Settings."
            return
        }
        var request = URLRequest(url: url.appendingPathComponent("chat"))
        request.httpMethod = "POST"
        request.timeoutInterval = 65
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !accessToken.isEmpty { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        let body = ChatRequest(messages: Array(messages.suffix(20)), investorMode: investorMode)
        request.httpBody = try? JSONEncoder().encode(body)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw NSError(domain: "Alex", code: 1, userInfo: [NSLocalizedDescriptionKey: "Server rejected the request. Check your URL, token and server logs."])
            }
            let result = try JSONDecoder().decode(ChatReply.self, from: data)
            messages.append(ChatMessage(role: "assistant", content: result.reply)); persist()
            say(result.reply)
        } catch { self.error = error.localizedDescription }
    }
    func startListening() async {
        guard !listening else { stopListening(); return }
        error = nil
        let authorization = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard authorization == .authorized else { error = "Speech recognition permission is required."; return }
        let mic = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard mic else { error = "Microphone permission is required."; return }
        do {
            stopSpeaking()
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            recognitionTask?.cancel(); recognitionTask = nil
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            recognitionRequest = req
            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in req.append(buffer) }
            audioEngine.prepare(); try audioEngine.start()
            listening = true
            recognitionTask = recognizer?.recognitionTask(with: req) { [weak self] result, taskError in
                Task { @MainActor in
                    guard let self else { return }
                    if let result { self.draft = result.bestTranscription.formattedString }
                    if taskError != nil { self.stopListening() }
                }
            }
        } catch {self error = error.localizedDescription; stopListening() }
    }
    func stopListening() {
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil; recognitionRequest = nil
        listening = false
    }
}
private struct ChatRequest: Encodable { let messages: [ChatMessage]; let investorMode: Bool }
private struct ChatReply: Decodable { let reply: String }
