import Foundation
import CoreAudio

/// The system's default audio output, as far as volume keys are concerned.
///
/// macOS cannot change the volume of DisplayPort/HDMI audio (the monitor's
/// speakers), so in that case the volume keys are routed to the monitor's
/// DDC/CI volume instead (VCP 0x62).
public enum AudioOutput {
    public struct Device {
        public let id: AudioObjectID
        public let name: String
        public let isDisplayAudio: Bool
        public let hasSoftwareVolume: Bool
    }

    public static func defaultDevice() -> Device? {
        var deviceID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID) == noErr,
              deviceID != 0 else { return nil }

        var transport = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyTransportType
        _ = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transport)
        let isDisplay = transport == kAudioDeviceTransportTypeDisplayPort || transport == kAudioDeviceTransportTypeHDMI

        var name: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        address.mSelector = kAudioObjectPropertyName
        _ = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)

        return Device(id: deviceID,
                      name: (name?.takeRetainedValue() as String?) ?? "",
                      isDisplayAudio: isDisplay,
                      hasSoftwareVolume: hasSettableVolume(deviceID))
    }

    private static func hasSettableVolume(_ device: AudioObjectID) -> Bool {
        for element in [kAudioObjectPropertyElementMain, 1] {
            var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar,
                                                     mScope: kAudioDevicePropertyScopeOutput,
                                                     mElement: element)
            guard AudioObjectHasProperty(device, &address) else { continue }
            var settable: DarwinBoolean = false
            if AudioObjectIsPropertySettable(device, &address, &settable) == noErr, settable.boolValue {
                return true
            }
        }
        return false
    }
}
