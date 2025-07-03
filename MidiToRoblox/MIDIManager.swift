import SwiftUI
import CoreMIDI
import AVFoundation
import Carbon

// MARK: - MIDI Manager
class MIDIManager: ObservableObject {
    @Published var availablePorts: [String] = []
    @Published var keyMappings: [UInt8: String] = [:]
    @Published var activeNotes: Set<UInt8> = []
    @Published var activeKeys: Set<String> = []
    
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var audioEngine: AudioEngine?
    private let mappingsURL: URL
    private var soundTestEnabled = false
    
    // Lazy initialization of audio engine to avoid startup issues
    private var lazyAudioEngine: AudioEngine? {
        if audioEngine == nil && soundTestEnabled {
            audioEngine = AudioEngine()
        }
        return audioEngine
    }
    
    init() {
        // Set up mappings file URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        mappingsURL = documentsPath.appendingPathComponent("MidiToRobloxMappings.json")
        
        // Initialize MIDI client
        setupMIDI()
        
        // Don't initialize audio engine until needed
        
        // Load mappings (will use defaults if no saved mappings exist)
        loadMappings()
    }
    
    // MARK: - Sound Test
    func setSoundTestEnabled(_ enabled: Bool) {
        soundTestEnabled = enabled
    }
    
    // MARK: - MIDI Setup
    private func setupMIDI() {
        let clientName = "MidiToRoblox" as CFString
        MIDIClientCreate(clientName, nil, nil, &midiClient)
        
        let portName = "MidiToRoblox Input" as CFString
        MIDIInputPortCreate(midiClient, portName, midiReadProc, Unmanaged.passUnretained(self).toOpaque(), &inputPort)
    }
    
    // MARK: - MIDI Port Management
    func rescanPorts() {
        availablePorts.removeAll()
        
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            if let name = getMIDIObjectDisplayName(source) {
                availablePorts.append(name)
            }
        }
    }
    
    private func getMIDIObjectDisplayName(_ object: MIDIObjectRef) -> String? {
        var name: Unmanaged<CFString>?
        let result = MIDIObjectGetStringProperty(object, kMIDIPropertyDisplayName, &name)
        
        if result == noErr, let name = name {
            return name.takeRetainedValue() as String
        }
        return nil
    }
    
    // MARK: - MIDI Listening
    func startListening(portName: String) -> Bool {
        let sourceCount = MIDIGetNumberOfSources()
        
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            if let name = getMIDIObjectDisplayName(source), name == portName {
                let result = MIDIPortConnectSource(inputPort, source, nil)
                if result == noErr {
                    return true
                }
            }
        }
        return false
    }
    
    func stopListening() {
        // Stop all playing sounds
        if soundTestEnabled {
            for note in heldNotes {
                lazyAudioEngine?.stopNote(note)
            }
        }
        
        // Release all held keys before disconnecting
        for note in heldNotes {
            if let keyMapping = keyMappings[note] {
                sendKeyUp(key: keyMapping)
            }
        }
        
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            MIDIPortDisconnectSource(inputPort, source)
        }
        
        // Clear all tracking
        heldNotes.removeAll()
        activeNotes.removeAll()
        activeKeys.removeAll()
    }
    
    // MARK: - MIDI Processing
    private let midiReadProc: MIDIReadProc = { pktList, readProcRefCon, srcConnRefCon in
        let manager = Unmanaged<MIDIManager>.fromOpaque(readProcRefCon!).takeUnretainedValue()
        
        let packetList = pktList.pointee
        var packet = packetList.packet
        
        for _ in 0..<packetList.numPackets {
            let data = packet.data
            
            // Check for Note On/Off messages
            let status = data.0
            let data1 = data.1
            let data2 = data.2
            
            let messageType = status & 0xF0
            
            switch messageType {
            case 0x90: // Note On
                if data2 > 0 {
                    manager.handleNoteOn(note: data1, velocity: data2)
                } else {
                    // Note On with velocity 0 is treated as Note Off
                    manager.handleNoteOff(note: data1)
                }
            case 0x80: // Note Off
                manager.handleNoteOff(note: data1)
            case 0xB0: // Control Change
                break // Ignore control change messages
            default:
                break // Ignore other message types
            }
            
            // Move to next packet
            packet = MIDIPacketNext(&packet).pointee
        }
    }
    
    
    // MARK: - Note Handling
    private var heldNotes: Set<UInt8> = [] // Track currently held notes
    
    private func handleNoteOn(note: UInt8, velocity: UInt8) {
        // Prevent duplicate key down events
        guard !heldNotes.contains(note) else { return }
        heldNotes.insert(note)
        
        // Play sound if test mode is enabled
        if soundTestEnabled {
            lazyAudioEngine?.playNote(note)
        }
        
        // Send keyboard event immediately for lowest latency
        if let keyMapping = keyMappings[note] {
            sendKeyDown(key: keyMapping)
            
            // Update UI on main queue
            DispatchQueue.main.async { [weak self] in
                self?.activeNotes.insert(note)
                self?.activeKeys.insert(keyMapping)
            }
        }
    }
    
    private func handleNoteOff(note: UInt8) {
        // Only send key up if note was actually held
        guard heldNotes.contains(note) else { return }
        heldNotes.remove(note)
        
        // Stop sound if test mode is enabled
        if soundTestEnabled {
            lazyAudioEngine?.stopNote(note)
        }
        
        // Send keyboard event immediately for lowest latency
        if let keyMapping = keyMappings[note] {
            sendKeyUp(key: keyMapping)
            
            // Update UI on main queue
            DispatchQueue.main.async { [weak self] in
                self?.activeNotes.remove(note)
                self?.activeKeys.remove(keyMapping)
            }
        }
    }
    
    // MARK: - Keyboard Event Synthesis
    private func sendKeyDown(key: String) {
        // Check if we need to send a shifted character
        let needsShift = isShiftedCharacter(key)
        let baseKey = getBaseKey(key)
        
        guard let keyCode = keyCodeForString(baseKey) else { return }
        
        let source = CGEventSource(stateID: .hidSystemState) // Use HID for lower latency
        source?.localEventsSuppressionInterval = 0.0 // Disable event suppression
        
        // Press Shift if needed
        if needsShift {
            let shiftDown = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: true) // Shift key
            shiftDown?.flags = .maskShift
            shiftDown?.post(tap: .cgSessionEventTap) // Use session tap for faster delivery
        }
        
        // Press the actual key with minimal delay
        let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        if needsShift {
            event?.flags = .maskShift
        }
        event?.post(tap: .cgSessionEventTap)
    }
    
    private func sendKeyUp(key: String) {
        // Check if we need to release shift
        let needsShift = isShiftedCharacter(key)
        let baseKey = getBaseKey(key)
        
        guard let keyCode = keyCodeForString(baseKey) else { return }
        
        let source = CGEventSource(stateID: .hidSystemState) // Use HID for lower latency
        source?.localEventsSuppressionInterval = 0.0
        
        // Release the actual key
        let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        if needsShift {
            event?.flags = .maskShift
        }
        event?.post(tap: .cgSessionEventTap)
        
        // Release Shift if it was pressed
        if needsShift {
            let shiftUp = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: false) // Shift key
            shiftUp?.flags = []
            shiftUp?.post(tap: .cgSessionEventTap)
        }
    }
    
    private func isShiftedCharacter(_ key: String) -> Bool {
        let shiftedChars = ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+", "{", "}", "|", ":", "\"", "<", ">", "?", "~"]
        let uppercaseLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        
        return shiftedChars.contains(key) || uppercaseLetters.contains(key)
    }
    
    private func getBaseKey(_ key: String) -> String {
        // Map shifted characters to their base keys
        let shiftMap: [String: String] = [
            "!": "1", "@": "2", "#": "3", "$": "4", "%": "5",
            "^": "6", "&": "7", "*": "8", "(": "9", ")": "0",
            "_": "-", "+": "=", "{": "[", "}": "]", "|": "\\",
            ":": ";", "\"": "'", "<": ",", ">": ".", "?": "/", "~": "`"
        ]
        
        // Check if it's a shifted special character
        if let baseKey = shiftMap[key] {
            return baseKey
        }
        
        // Check if it's an uppercase letter - return lowercase
        if key.count == 1 {
            let char = key.first!
            if char.isUppercase {
                return key.lowercased()
            }
        }
        
        return key
    }
    
    private func keyCodeForString(_ key: String) -> CGKeyCode? {
        let keyMap: [String: CGKeyCode] = [
            // Letters (lowercase only - uppercase handled by getBaseKey)
            "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03,
            "h": 0x04, "g": 0x05, "z": 0x06, "x": 0x07,
            "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
            "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10,
            "t": 0x11, "1": 0x12, "2": 0x13, "3": 0x14,
            "4": 0x15, "6": 0x16, "5": 0x17, "=": 0x18,
            "9": 0x19, "7": 0x1A, "-": 0x1B, "8": 0x1C,
            "0": 0x1D, "]": 0x1E, "o": 0x1F, "u": 0x20,
            "[": 0x21, "i": 0x22, "p": 0x23, "l": 0x25,
            "j": 0x26, "'": 0x27, "k": 0x28, ";": 0x29,
            "\\": 0x2A, ",": 0x2B, "/": 0x2C, "n": 0x2D,
            "m": 0x2E, ".": 0x2F, "`": 0x32, " ": 0x31
        ]
        
        return keyMap[key]
    }
    
    // MARK: - Mapping Management
    func updateMapping(note: UInt8, key: String) {
        keyMappings[note] = key
        saveMappings()
    }
    
    func loadDefaultMappings() {
        // Default mappings for 61-key keyboard starting from C2 = "1"
        // Pattern: numbers 1-0, then lowercase letters qwertyuiop asdfghjkl zxcvbnm
        // Black keys use shift characters and uppercase letters
        keyMappings = [
            // C2 to B2
            36: "1",   // C2
            37: "!",   // C#2
            38: "2",   // D2
            39: "@",   // D#2
            40: "3",   // E2
            41: "4",   // F2
            42: "$",   // F#2
            43: "5",   // G2
            44: "%",   // G#2
            45: "6",   // A2
            46: "^",   // A#2
            47: "7",   // B2
            
            // C3 to B3
            48: "8",   // C3
            49: "&",   // C#3
            50: "9",   // D3
            51: "*",   // D#3
            52: "0",   // E3
            53: "q",   // F3
            54: "Q",   // F#3
            55: "w",   // G3
            56: "W",   // G#3
            57: "e",   // A3
            58: "E",   // A#3
            59: "r",   // B3
            
            // C4 to B4
            60: "t",   // C4
            61: "T",   // C#4
            62: "y",   // D4
            63: "Y",   // D#4
            64: "u",   // E4
            65: "i",   // F4
            66: "I",   // F#4
            67: "o",   // G4
            68: "O",   // G#4
            69: "p",   // A4
            70: "P",   // A#4
            71: "a",   // B4
            
            // C5 to B5
            72: "s",   // C5
            73: "S",   // C#5
            74: "d",   // D5
            75: "D",   // D#5
            76: "f",   // E5
            77: "g",   // F5
            78: "G",   // F#5
            79: "h",   // G5
            80: "H",   // G#5
            81: "j",   // A5
            82: "J",   // A#5
            83: "k",   // B5
            
            // C6 to B6
            84: "l",   // C6
            85: "L",   // C#6
            86: "z",   // D6
            87: "Z",   // D#6
            88: "x",   // E6
            89: "c",   // F6
            90: "C",   // F#6
            91: "v",   // G6
            92: "V",   // G#6
            93: "b",   // A6
            94: "B",   // A#6
            95: "n",   // B6
            
            // C7
            96: "m",   // C7
        ]
    }
    
    // MARK: - Persistence
    func saveMappings() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        if let data = try? encoder.encode(keyMappings) {
            try? data.write(to: mappingsURL)
        }
    }
    
    func loadMappings() {
        if let data = try? Data(contentsOf: mappingsURL),
           let mappings = try? JSONDecoder().decode([UInt8: String].self, from: data) {
            keyMappings = mappings
        } else {
            loadDefaultMappings()
        }
    }
}

// MARK: - Audio Engine
class AudioEngine {
    private let audioEngine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private var isInitialized = false
    
    init() {
        setupAudio()
    }
    
    private func setupAudio() {
        // Attach sampler to engine
        audioEngine.attach(sampler)
        audioEngine.connect(sampler, to: audioEngine.mainMixerNode, format: nil)
        
        do {
            // Try system soundfont for piano sounds
            let systemSoundbank = "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"
            if FileManager.default.fileExists(atPath: systemSoundbank) {
                let url = URL(fileURLWithPath: systemSoundbank)
                try sampler.loadSoundBankInstrument(
                    at: url,
                    program: 0, // Acoustic Grand Piano
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: UInt8(kAUSampler_DefaultBankLSB)
                )
            }
            
            // Start the engine
            try audioEngine.start()
            isInitialized = true
        } catch {
            // Fallback - just use beep
            isInitialized = false
        }
    }
    
    func playNote(_ note: UInt8) {
        if isInitialized {
            sampler.startNote(note, withVelocity: 80, onChannel: 0)
        } else {
            // Fallback to system beep
            NSSound.beep()
        }
    }
    
    func stopNote(_ note: UInt8) {
        if isInitialized {
            sampler.stopNote(note, onChannel: 0)
        }
    }
}

