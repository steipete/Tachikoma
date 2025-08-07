//
//  RealtimeConversationView.swift
//  Tachikoma
//

#if canImport(SwiftUI)
import SwiftUI
@preconcurrency import AVFoundation

// MARK: - Realtime Conversation View

/// SwiftUI view for realtime voice conversations
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
public struct RealtimeConversationView: View {
    @StateObject private var viewModel: RealtimeConversationViewModel
    @State private var showingSettings = false
    @State private var inputText = ""
    
    public init(
        apiKey: String? = nil,
        configuration: EnhancedRealtimeConversation.ConversationConfiguration = .init()
    ) {
        _viewModel = StateObject(wrappedValue: RealtimeConversationViewModel(
            apiKey: apiKey,
            configuration: configuration
        ))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                    }
                }
            }
            
            // Audio visualizer
            audioVisualizerView
            
            // Controls
            controlsView
        }
        .onAppear {
            Task {
                await viewModel.initialize()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(viewModel: viewModel)
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            // Connection status
            HStack(spacing: 8) {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.connectionStatus.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // State indicator
            if viewModel.state != .idle {
                Text(stateText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue.opacity(0.1)))
            }
            
            // Settings button
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape")
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
    }
    
    private var audioVisualizerView: some View {
        HStack(spacing: 2) {
            ForEach(0..<20) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue.opacity(barOpacity(for: i)))
                    .frame(width: 4, height: barHeight(for: i))
                    .animation(.easeInOut(duration: 0.1), value: viewModel.audioLevel)
            }
        }
        .frame(height: 40)
        .padding(.horizontal)
    }
    
    private var controlsView: some View {
        VStack(spacing: 16) {
            // Text input
            HStack {
                TextField("Type a message...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendTextMessage()
                    }
                
                Button(action: sendTextMessage) {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(inputText.isEmpty || !viewModel.isReady)
            }
            
            // Voice controls
            HStack(spacing: 32) {
                // Record button
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(viewModel.isRecording ? Color.red : Color.blue)
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: viewModel.isRecording ? "mic.fill" : "mic")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
                
                // Interrupt button
                Button(action: interrupt) {
                    Image(systemName: "stop.circle")
                        .font(.title)
                }
                .disabled(!viewModel.isPlaying)
                
                // Clear button
                Button(action: { viewModel.clearHistory() }) {
                    Image(systemName: "trash")
                        .font(.title)
                }
                .disabled(viewModel.messages.isEmpty)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
    }
    
    // MARK: - Helper Methods
    
    private var connectionColor: Color {
        switch viewModel.connectionStatus {
        case .connected: .green
        case .connecting, .reconnecting: .orange
        case .disconnected: .gray
        case .error: .red
        }
    }
    
    private var stateText: String {
        switch viewModel.state {
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
            await viewModel.toggleRecording()
        }
    }
    
    private func interrupt() {
        Task {
            await viewModel.interrupt()
        }
    }
    
    private func sendTextMessage() {
        guard !inputText.isEmpty else { return }
        
        Task {
            await viewModel.sendMessage(inputText)
            await MainActor.run {
                inputText = ""
            }
        }
    }
}

// MARK: - Message Bubble

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
struct MessageBubble: View {
    let message: EnhancedRealtimeConversation.ConversationMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(bubbleColor)
                    )
                    .foregroundColor(textColor)
                
                Text(timeString(from: message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.role != .user {
                Spacer()
            }
        }
    }
    
    private var bubbleColor: Color {
        switch message.role {
        case .user: .blue
        case .assistant: Color.secondary.opacity(0.1)
        case .system: .orange.opacity(0.2)
        case .tool: .green.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        message.role == .user ? .white : .primary
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
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Voice Settings") {
                    Picker("Voice", selection: $viewModel.selectedVoice) {
                        ForEach(RealtimeVoice.allCases, id: \.self) { voice in
                            Text(voice.rawValue.capitalized).tag(voice)
                        }
                    }
                    
                    Toggle("Voice Activity Detection", isOn: $viewModel.enableVAD)
                    Toggle("Echo Cancellation", isOn: $viewModel.enableEchoCancellation)
                    Toggle("Noise Suppression", isOn: $viewModel.enableNoiseSupression)
                }
                
                Section("Connection") {
                    Toggle("Auto Reconnect", isOn: $viewModel.autoReconnect)
                    Toggle("Session Persistence", isOn: $viewModel.sessionPersistence)
                }
                
                Section("About") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(viewModel.connectionStatus.rawValue.capitalized)
                            .foregroundColor(.secondary)
                    }
                    
                    if let duration = viewModel.sessionDuration {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(formatDuration(duration))
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
                        dismiss()
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
