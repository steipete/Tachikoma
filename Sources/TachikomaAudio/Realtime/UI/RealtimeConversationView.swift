#if canImport(SwiftUI)
@preconcurrency import AVFoundation
import SwiftUI

// MARK: - Realtime Conversation View

/// SwiftUI view for realtime voice conversations
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct RealtimeConversationView: View {
    @StateObject private var viewModel: RealtimeConversationViewModel
    @State private var showingSettings = false
    @State private var inputText = ""

    public init(
        apiKey: String? = nil,
        configuration: RealtimeConversation.ConversationConfiguration = .init(),
    ) {
        _viewModel = StateObject(wrappedValue: RealtimeConversationViewModel(
            apiKey: apiKey,
            configuration: configuration,
        ))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            self.headerView

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(self.viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: self.viewModel.messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(self.viewModel.messages.last?.id, anchor: .bottom)
                    }
                }
            }

            // Audio visualizer
            self.audioVisualizerView

            // Controls
            self.controlsView
        }
        .onAppear {
            Task {
                await self.viewModel.initialize()
            }
        }
        .sheet(isPresented: self.$showingSettings) {
            SettingsView(viewModel: self.viewModel)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            // Connection status
            HStack(spacing: 8) {
                Circle()
                    .fill(self.connectionColor)
                    .frame(width: 8, height: 8)

                Text(String(describing: self.viewModel.connectionStatus).capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // State indicator
            if self.viewModel.state != .idle {
                Text(self.stateText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue.opacity(0.1)))
            }

            // Settings button
            Button(action: { self.showingSettings = true }, label: {
                Image(systemName: "gearshape")
            })
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
    }

    private var audioVisualizerView: some View {
        HStack(spacing: 2) {
            ForEach(0..<20) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(self.barOpacity(for: i)))
                    .frame(width: 4, height: self.barHeight(for: i))
                    .animation(.easeInOut(duration: 0.1), value: self.viewModel.audioLevel)
            }
        }
        .frame(height: 40)
        .padding(.horizontal)
    }

    private var controlsView: some View {
        VStack(spacing: 16) {
            // Text input
            HStack {
                TextField("Type a message...", text: self.$inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        self.sendTextMessage()
                    }

                Button(action: self.sendTextMessage) {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(self.inputText.isEmpty || !self.viewModel.isReady)
            }

            // Voice controls
            HStack(spacing: 32) {
                // Record button
                Button(action: self.toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(self.viewModel.isRecording ? Color.red : Color.blue)
                            .frame(width: 64, height: 64)

                        Image(systemName: self.viewModel.isRecording ? "mic.fill" : "mic")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(self.viewModel.isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: self.viewModel.isRecording)

                // Interrupt button
                Button(action: self.interrupt) {
                    Image(systemName: "stop.circle")
                        .font(.title)
                }
                .disabled(!self.viewModel.isPlaying)

                // Clear button
                Button(action: { self.viewModel.clearHistory() }, label: {
                    Image(systemName: "trash")
                        .font(.title)
                })
                .disabled(self.viewModel.messages.isEmpty)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
    }

    // MARK: - Helper Methods

    private var connectionColor: Color {
        switch self.viewModel.connectionStatus {
        case .connected: .green
        case .connecting, .reconnecting: .orange
        case .disconnected: .gray
        case .error: .red
        }
    }

    private var stateText: String {
        switch self.viewModel.state {
        case .idle: ""
        case .listening: "Listening..."
        case .processing: "Processing..."
        case .speaking: "Speaking..."
        case .error: "Error"
        }
    }

    private func barOpacity(for index: Int) -> Double {
        let normalizedIndex = Double(index) / 20.0
        let level = Double(viewModel.audioLevel)
        return normalizedIndex < level ? 1.0 : 0.3
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 10
        let maxHeight: CGFloat = 30
        let normalizedIndex = Double(index) / 20.0
        let level = Double(viewModel.audioLevel)

        if normalizedIndex < level {
            let variation = sin(Double(index) * 0.5 + Date().timeIntervalSince1970 * 2)
            return baseHeight + CGFloat(variation + 1) * (maxHeight - baseHeight) / 2
        }
        return baseHeight
    }

    private func toggleRecording() {
        Task {
            await self.viewModel.toggleRecording()
        }
    }

    private func interrupt() {
        Task {
            await self.viewModel.interrupt()
        }
    }

    private func sendTextMessage() {
        guard !self.inputText.isEmpty else { return }

        Task {
            await self.viewModel.sendMessage(self.inputText)
            await MainActor.run {
                self.inputText = ""
            }
        }
    }
}

// MARK: - Message Bubble

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
struct MessageBubble: View {
    let message: RealtimeConversation.ConversationMessage

    var body: some View {
        HStack {
            if self.message.role == .user {
                Spacer()
            }

            VStack(alignment: self.message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(self.message.content)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(self.bubbleColor),
                    )
                    .foregroundColor(self.textColor)

                Text(self.timeString(from: self.message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if self.message.role != .user {
                Spacer()
            }
        }
    }

    private var bubbleColor: Color {
        switch self.message.role {
        case .user: .blue
        case .assistant: Color.secondary.opacity(0.1)
        case .system: .orange.opacity(0.2)
        case .tool: .green.opacity(0.2)
        }
    }

    private var textColor: Color {
        self.message.role == .user ? .white : .primary
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Settings View

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
struct SettingsView: View {
    @ObservedObject var viewModel: RealtimeConversationViewModel
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Voice Settings") {
                    Picker("Voice", selection: self.$viewModel.selectedVoice) {
                        ForEach(RealtimeVoice.allCases, id: \.self) { voice in
                            Text(voice.rawValue.capitalized).tag(voice)
                        }
                    }

                    Toggle("Voice Activity Detection", isOn: self.$viewModel.enableVAD)
                    Toggle("Echo Cancellation", isOn: self.$viewModel.enableEchoCancellation)
                    Toggle("Noise Suppression", isOn: self.$viewModel.enableNoiseSupression)
                }

                Section("Connection") {
                    Toggle("Auto Reconnect", isOn: self.$viewModel.autoReconnect)
                    Toggle("Session Persistence", isOn: self.$viewModel.sessionPersistence)
                }

                Section("About") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(String(describing: self.viewModel.connectionStatus).capitalized)
                            .foregroundColor(.secondary)
                    }

                    if let duration = viewModel.sessionDuration {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(self.formatDuration(duration))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            self.dismiss()
                        }
                    }
                }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}

// MARK: - RealtimeVoice Extension

extension RealtimeVoice: CaseIterable {
    public static var allCases: [RealtimeVoice] {
        [.alloy, .echo, .fable, .onyx, .nova, .shimmer]
    }
}

#endif
