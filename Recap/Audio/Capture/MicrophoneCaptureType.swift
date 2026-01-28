//
//  MicrophoneCaptureType.swift
//  Recap
//
//  Created by Rawand Ahmad on 01/08/2025.
//


import AVFoundation
import AudioToolbox

protocol MicrophoneCaptureType: ObservableObject {
    var audioLevel: Float { get }
    var recordingFormat: AVAudioFormat? { get }

    func start(
        outputURL: URL?,
        targetFormat: AudioStreamBasicDescription?,
        onBuffer: ((AVAudioPCMBuffer) -> Void)?
    ) throws
    func stop()
}
