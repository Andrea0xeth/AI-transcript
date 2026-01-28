import Foundation
import AVFoundation

enum AudioMergerError: LocalizedError {
    case invalidInputFiles
    case emptySystemAudio
    case conversionFailed

    var errorDescription: String? {
        switch self {
        case .invalidInputFiles:
            return "File audio non validi per il merge."
        case .emptySystemAudio:
            return "Il file audio di sistema è vuoto."
        case .conversionFailed:
            return "Conversione audio non riuscita."
        }
    }
}

final class AudioMerger {
    static func mergeSystemAndMicrophone(
        systemURL: URL,
        microphoneURL: URL,
        outputURL: URL
    ) throws {
        let systemFile = try AVAudioFile(forReading: systemURL)
        let micFile = try AVAudioFile(forReading: microphoneURL)

        let targetFormat = systemFile.processingFormat
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: targetFormat.settings)

        let bufferSize: AVAudioFrameCount = 4096
        guard let systemBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: bufferSize) else {
            throw AudioMergerError.invalidInputFiles
        }
        let micSourceFormat = micFile.processingFormat
        guard let micBuffer = AVAudioPCMBuffer(pcmFormat: micSourceFormat, frameCapacity: bufferSize) else {
            throw AudioMergerError.invalidInputFiles
        }

        let converter: AVAudioConverter? = micSourceFormat == targetFormat
            ? nil
            : AVAudioConverter(from: micSourceFormat, to: targetFormat)

        while true {
            try systemFile.read(into: systemBuffer, frameCount: bufferSize)
            if systemBuffer.frameLength == 0 {
                break
            }

            var micBufferConverted: AVAudioPCMBuffer?
            try micFile.read(into: micBuffer, frameCount: bufferSize)
            if micBuffer.frameLength > 0 {
                if let converter = converter {
                    guard let converted = AVAudioPCMBuffer(
                        pcmFormat: targetFormat,
                        frameCapacity: micBuffer.frameLength
                    ) else {
                        throw AudioMergerError.conversionFailed
                    }
                    var error: NSError?
                    let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                        outStatus.pointee = .haveData
                        return micBuffer
                    }
                    converter.convert(to: converted, error: &error, withInputFrom: inputBlock)
                    if error != nil {
                        throw AudioMergerError.conversionFailed
                    }
                    micBufferConverted = converted
                } else {
                    micBufferConverted = micBuffer
                }
            }

            mix(systemBuffer: systemBuffer, micBuffer: micBufferConverted)
            try outputFile.write(from: systemBuffer)
        }
    }

    private static func mix(systemBuffer: AVAudioPCMBuffer, micBuffer: AVAudioPCMBuffer?) {
        guard let systemData = systemBuffer.floatChannelData else { return }
        let frameLength = Int(systemBuffer.frameLength)
        let channelCount = Int(systemBuffer.format.channelCount)

        guard let micBuffer = micBuffer,
              let micData = micBuffer.floatChannelData,
              micBuffer.frameLength > 0 else {
            return
        }

        let micFrames = Int(micBuffer.frameLength)
        let framesToMix = min(frameLength, micFrames)
        let micChannels = Int(micBuffer.format.channelCount)

        for channel in 0..<channelCount {
            let systemChannel = systemData[channel]
            let micChannel = micData[min(channel, micChannels - 1)]
            for frame in 0..<framesToMix {
                let mixed = systemChannel[frame] + micChannel[frame]
                systemChannel[frame] = min(max(mixed, -1.0), 1.0)
            }
        }
    }
}
