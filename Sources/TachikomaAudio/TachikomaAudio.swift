import Foundation

/*
 TachikomaAudio provides comprehensive audio processing capabilities including
 transcription, speech synthesis, and audio recording.

 ## Features

 - **Transcription**: Convert audio to text using multiple providers (OpenAI, Groq, Deepgram)
 - **Speech Synthesis**: Generate speech from text (OpenAI TTS, ElevenLabs)
 - **Audio Recording**: Cross-platform audio recording with AVFoundation
 - **Format Support**: WAV, MP3, FLAC, M4A, and more

 ## Usage

 ```swift
 import TachikomaAudio

 // Transcribe audio
 let text = try await transcribe(contentsOf: audioURL)

 // Generate speech
 let audio = try await generateSpeech("Hello world")
 try audio.write(to: outputURL)

 // Record audio
 let recorder = AudioRecorder()
 try await recorder.startRecording()
 let audioData = try await recorder.stopRecording()
 ```
 */

// Module documentation only - all types are public in their respective files
