import Foundation
import AudioToolbox

struct MicrophoneDeviceInfo: Identifiable, Hashable {
    let deviceID: AudioDeviceID
    let name: String
    let uid: String

    var id: String { uid }
}

struct MicrophoneSelectionOption: Identifiable, Hashable {
    let id: String
    let name: String
    let device: MicrophoneDeviceInfo?

    static func systemDefault() -> MicrophoneSelectionOption {
        MicrophoneSelectionOption(id: "system-default", name: "Sistema (Default)", device: nil)
    }
}
