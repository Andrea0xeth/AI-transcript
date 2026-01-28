import Foundation
import AVFoundation

final class CombinedAudioWriter {
    private let queue = DispatchQueue(label: "CombinedAudioWriter")
    private let audioFile: AVAudioFile
    private let targetFormat: AVAudioFormat
    private var latestMicBuffer: AVAudioPCMBuffer?
    private var systemConverter: AVAudioConverter?
    private var micConverter: AVAudioConverter?
    private let systemGain: Float = 1.0
    private let micGain: Float = 1.6

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
            self.latestMicBuffer = self.convertToTarget(buffer, converter: &self.micConverter)
        }
    }

    func handleSystemBuffer(_ buffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            guard let self else { return }
            let systemBuffer = self.convertToTarget(buffer, converter: &self.systemConverter)
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

    private func convertToTarget(_ buffer: AVAudioPCMBuffer, converter: inout AVAudioConverter?) -> AVAudioPCMBuffer {
        if buffer.format == targetFormat {
            return cloneBuffer(buffer)
        }
        if converter == nil {
            converter = AVAudioConverter(from: buffer.format, to: targetFormat)
        }
        guard let converter else {
            return cloneBuffer(buffer)
        }
        let output = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * (targetFormat.sampleRate / buffer.format.sampleRate))
        )!
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        if status == .error {
            return cloneBuffer(buffer)
        }
        return output
    }

    private func cloneBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let frameLength = buffer.frameLength
        let channels = Int(buffer.format.channelCount)
        let newBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: frameLength)!
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

        var peak: Float = 0
        for channel in 0..<systemChannels {
            let systemChannel = systemData[channel]
            let micChannel = micData[min(channel, micChannels - 1)]
            for frame in 0..<frameLength {
                let mixed = (systemChannel[frame] * systemGain) + (micChannel[frame] * micGain)
                let clamped = min(max(mixed, -1.0), 1.0)
                systemChannel[frame] = clamped
                peak = max(peak, abs(clamped))
            }
        }
        if peak > 0.95 {
            let scale = 0.95 / peak
            for channel in 0..<systemChannels {
                let systemChannel = systemData[channel]
                for frame in 0..<frameLength {
                    systemChannel[frame] = systemChannel[frame] * scale
                }
            }
        }
    }
}
