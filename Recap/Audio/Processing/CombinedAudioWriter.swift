import Foundation
import AVFoundation

final class CombinedAudioWriter {
    private let queue = DispatchQueue(label: "CombinedAudioWriter")
    private let audioFile: AVAudioFile
    private let targetFormat: AVAudioFormat
    private var latestMicBuffer: AVAudioPCMBuffer?

    init(outputURL: URL, targetFormat: AVAudioFormat) throws {
        self.targetFormat = targetFormat
        self.audioFile = try AVAudioFile(
            forWriting: outputURL,
            settings: targetFormat.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: targetFormat.isInterleaved
        )
    }

    func handleMicBuffer(_ buffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            guard let self else { return }
            self.latestMicBuffer = self.cloneBuffer(buffer)
        }
    }

    func handleSystemBuffer(_ buffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            guard let self else { return }
            let systemBuffer = self.cloneBuffer(buffer)
            if let micBuffer = self.latestMicBuffer {
                self.mix(systemBuffer: systemBuffer, micBuffer: micBuffer)
            }
            do {
                try self.audioFile.write(from: systemBuffer)
            } catch {
                // Intentionally ignore write errors to avoid breaking recording
            }
        }
    }

    private func cloneBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let frameLength = buffer.frameLength
        let channels = Int(buffer.format.channelCount)
        let newBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameLength)!
        newBuffer.frameLength = frameLength

        guard let src = buffer.floatChannelData, let dst = newBuffer.floatChannelData else {
            return newBuffer
        }

        for channel in 0..<channels {
            memcpy(dst[channel], src[channel], Int(frameLength) * MemoryLayout<Float>.size)
        }
        return newBuffer
    }

    private func mix(systemBuffer: AVAudioPCMBuffer, micBuffer: AVAudioPCMBuffer) {
        guard let systemData = systemBuffer.floatChannelData,
              let micData = micBuffer.floatChannelData else { return }

        let frameLength = Int(min(systemBuffer.frameLength, micBuffer.frameLength))
        let systemChannels = Int(systemBuffer.format.channelCount)
        let micChannels = Int(micBuffer.format.channelCount)

        for channel in 0..<systemChannels {
            let systemChannel = systemData[channel]
            let micChannel = micData[min(channel, micChannels - 1)]
            for frame in 0..<frameLength {
                let mixed = systemChannel[frame] + micChannel[frame]
                systemChannel[frame] = min(max(mixed, -1.0), 1.0)
            }
        }
    }
}
