import SwiftUI
import CoreMIDI
import AVFoundation

// MARK: - Main App Structure
@main
struct MidiToRobloxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 1440, height: 260)
                .fixedSize()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1440, height: 260)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set presentation options to auto-hide menu bar
        NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var midiManager = MIDIManager()
    @State private var selectedMIDIPort: String?
    @State private var statusMessage = "Ready"
    @State private var isRunning = false
    @State private var editingNote: UInt8?
    @State private var newKeyMapping = ""
    @State private var isCloseButtonHovered = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showAbout = false
    @State private var soundTestEnabled = false
    
    let keyboardWidth: CGFloat = 1440 // 36 white keys * 40 width
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Bar with Controls
            VStack(spacing: 0) {
                // Top section with title and controls
                HStack {
                    // Close button
                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Circle()
                            .fill(Color.red.opacity(isCloseButtonHovered ? 1 : 0.8))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.black.opacity(isCloseButtonHovered ? 0.8 : 0.5))
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isCloseButtonHovered = hovering
                    }
                    .help("Close")
                    
                    // App Title and Status
                    HStack(spacing: 12) {
                        Text("MIDI to Roblox")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Status indicator
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isRunning ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(isRunning ? "Active" : statusMessage)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    // MIDI Port Selection
                    HStack(spacing: 4) {
                        Text("MIDI:")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        
                        Picker("", selection: $selectedMIDIPort) {
                            Text("None").tag(nil as String?)
                            ForEach(midiManager.availablePorts, id: \.self) { port in
                                Text(port).tag(port as String?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                        .accentColor(.white)
                        
                        Button(action: { midiManager.rescanPorts() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                        .help("Rescan MIDI devices")
                    }
                    
                    Spacer()
                    
                    // Control Buttons
                    HStack(spacing: 8) {
                        Button(action: startSession) {
                            Text("Start")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(isRunning || selectedMIDIPort == nil ? .gray : .white)
                                .frame(width: 60)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isRunning || selectedMIDIPort == nil ? Color.gray.opacity(0.3) : Color.green.opacity(0.8))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isRunning || selectedMIDIPort == nil)
                        
                        Button(action: stopSession) {
                            Text("Stop")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(!isRunning ? .gray : .white)
                                .frame(width: 60)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(!isRunning ? Color.gray.opacity(0.3) : Color.red.opacity(0.8))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!isRunning)
                        
                        Button(action: { 
                            midiManager.loadDefaultMappings()
                            statusMessage = "Mappings reset"
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                        .help("Reset mappings to default")
                        
                        Button(action: { 
                            showAbout = true
                        }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                        .help("About MidiToRoblox")
                        
                        // Sound test toggle
                        Button(action: { 
                            soundTestEnabled.toggle()
                            midiManager.setSoundTestEnabled(soundTestEnabled)
                            statusMessage = soundTestEnabled ? "Sound test ON" : "Sound test OFF"
                        }) {
                            Image(systemName: soundTestEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill")
                                .font(.system(size: 14))
                                .foregroundColor(soundTestEnabled ? .green : .gray)
                        }
                        .buttonStyle(.plain)
                        .help(soundTestEnabled ? "Disable sound test" : "Enable sound test")
                    }
                    
                    Spacer()
                    
                    // Active keys display
                    ActiveKeysView(activeKeys: midiManager.activeKeys)
                        .frame(width: 180, alignment: .trailing)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .frame(width: keyboardWidth)
            .background(Color.black)
            .background(WindowDraggingView())
            
            // Piano Keyboard
            KeyboardView(
                midiManager: midiManager,
                editingNote: $editingNote,
                onKeyTapped: { note in
                    editingNote = note
                    newKeyMapping = midiManager.keyMappings[note] ?? ""
                }
            )
            .frame(width: keyboardWidth, height: 200)
            .background(Color(white: 0.15))
        }
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .sheet(item: $editingNote) { note in
            MappingDialog(
                note: note,
                currentMapping: midiManager.keyMappings[note] ?? "",
                onSave: { newMapping in
                    midiManager.updateMapping(note: note, key: newMapping)
                    statusMessage = "Mapped"
                    editingNote = nil
                }
            )
        }
        .alert("Connection Error", isPresented: $showError) {
            Button("OK") { 
                showError = false 
            }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .onAppear {
            midiManager.rescanPorts()
            // Auto-select first MIDI device if available
            if selectedMIDIPort == nil && !midiManager.availablePorts.isEmpty {
                selectedMIDIPort = midiManager.availablePorts.first
            }
        }
    }
    
    private func startSession() {
        guard let portName = selectedMIDIPort else { 
            errorMessage = "Please select a MIDI device"
            showError = true
            return 
        }
        
        if midiManager.startListening(portName: portName) {
            isRunning = true
            statusMessage = "Running..."
        } else {
            errorMessage = "Failed to connect to \(portName). Please check your MIDI connection and try again."
            showError = true
            statusMessage = "Connection failed"
        }
    }
    
    private func stopSession() {
        midiManager.stopListening()
        isRunning = false
        statusMessage = "Stopped"
    }
}

// MARK: - Piano Keyboard View
struct KeyboardView: View {
    let midiManager: MIDIManager
    @Binding var editingNote: UInt8?
    let onKeyTapped: (UInt8) -> Void
    
    // Define keyboard layout for 61 keys (C2 to C7)
    // 61 keys = 36 white keys + 25 black keys
    // Starting from C2 (MIDI note 36) to C7 (MIDI note 96)
    let whiteKeys: [UInt8] = [
        36, 38, 40, 41, 43, 45, 47, // C2 D2 E2 F2 G2 A2 B2
        48, 50, 52, 53, 55, 57, 59, // C3 D3 E3 F3 G3 A3 B3
        60, 62, 64, 65, 67, 69, 71, // C4 D4 E4 F4 G4 A4 B4
        72, 74, 76, 77, 79, 81, 83, // C5 D5 E5 F5 G5 A5 B5
        84, 86, 88, 89, 91, 93, 95, 96 // C6 D6 E6 F6 G6 A6 B6 C7
    ]
    let blackKeys: [UInt8] = [
        37, 39, 42, 44, 46, // C#2 D#2 F#2 G#2 A#2
        49, 51, 54, 56, 58, // C#3 D#3 F#3 G#3 A#3
        61, 63, 66, 68, 70, // C#4 D#4 F#4 G#4 A#4
        73, 75, 78, 80, 82, // C#5 D#5 F#5 G#5 A#5
        85, 87, 90, 92, 94  // C#6 D#6 F#6 G#6 A#6
    ]
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // White keys
            HStack(spacing: 0) {
                ForEach(whiteKeys, id: \.self) { note in
                    KeyView(
                        note: note,
                        isBlack: false,
                        mapping: midiManager.keyMappings[note] ?? "",
                        isActive: midiManager.activeNotes.contains(note),
                        onTap: { onKeyTapped(note) }
                    )
                }
            }
            
            // Black keys (positioned over white keys)
            ZStack(alignment: .leading) {
                // Place black keys based on the pattern of the piano keyboard
                ForEach(blackKeys, id: \.self) { blackNote in
                    if let position = blackKeyPosition(for: blackNote) {
                        KeyView(
                            note: blackNote,
                            isBlack: true,
                            mapping: midiManager.keyMappings[blackNote] ?? "",
                            isActive: midiManager.activeNotes.contains(blackNote),
                            onTap: { onKeyTapped(blackNote) }
                        )
                        .offset(x: position, y: 0)
                    }
                }
            }
        }
    }
    
    private func blackKeyPosition(for blackNote: UInt8) -> CGFloat? {
        // Calculate position based on which white keys the black key sits between
        let whiteKeyWidth: CGFloat = 40
        
        // Don't show black keys after the last white key (C7)
        if blackNote > 96 {
            return nil
        }
        
        // Find the white key just before this black key
        for (index, whiteNote) in whiteKeys.enumerated() {
            if index < whiteKeys.count - 1 {
                let nextWhiteNote = whiteKeys[index + 1]
                if whiteNote < blackNote && blackNote < nextWhiteNote {
                    // Position the black key between two white keys
                    return CGFloat(index) * whiteKeyWidth + (whiteKeyWidth * 0.7)
                }
            }
        }
        
        return nil
    }
}

// MARK: - Individual Key View
struct KeyView: View {
    let note: UInt8
    let isBlack: Bool
    let mapping: String
    let isActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Spacer()
                
                if !mapping.isEmpty {
                    Text(mapping)
                        .font(.system(size: isBlack ? 10 : 12, weight: .semibold, design: .rounded))
                        .foregroundColor(
                            isActive ? .white : 
                            (isBlack ? Color(white: 0.9) : Color(white: 0.2))
                        )
                }
                
                Text(noteName(note))
                    .font(.system(size: 9))
                    .foregroundColor(
                        isActive ? Color(white: 0.9) : 
                        (isBlack ? Color(white: 0.7) : Color(white: 0.5))
                    )
                    .padding(.bottom, isBlack ? 4 : 6)
            }
            .frame(
                width: isBlack ? 25 : 40,
                height: isBlack ? 120 : 200
            )
            .background(
                isActive ?
                    (isBlack ? Color(red: 1, green: 0.5, blue: 0) : Color(red: 0, green: 0.8, blue: 0.3)) :
                    (isBlack ? Color(white: 0.15) : Color(white: 0.95))
            )
            .overlay(
                Rectangle()
                    .stroke(
                        isBlack ? Color(white: 0.3) : Color(white: 0.8),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: isActive ? 
                    (isBlack ? Color.orange : Color.green).opacity(0.8) : 
                    Color.black.opacity(0.3),
                radius: isActive ? 12 : 3,
                x: 0,
                y: isActive ? 0 : 2
            )
            .scaleEffect(isActive ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.08), value: isActive)
        }
        .buttonStyle(.plain)
        .zIndex(isBlack ? 1 : 0)
    }
    
    private func noteName(_ note: UInt8) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(note) / 12 - 1
        let noteIndex = Int(note) % 12
        return "\(noteNames[noteIndex])\(octave)"
    }
}

// MARK: - Mapping Dialog
struct MappingDialog: View {
    let note: UInt8
    @State var currentMapping: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Map MIDI Note")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("\(noteName(note)) (MIDI \(note))")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            TextField("Enter key (e.g., W, Space, Shift)", text: $currentMapping)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .padding(10)
                .background(Color(white: 0.15))
                .cornerRadius(6)
                .foregroundColor(.white)
                .frame(width: 250)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(ModernButtonStyle(color: .gray))
                
                Button("Save") {
                    onSave(currentMapping)
                    dismiss()
                }
                .buttonStyle(ModernButtonStyle(color: .green))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
    
    private func noteName(_ note: UInt8) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(note) / 12 - 1
        let noteIndex = Int(note) % 12
        return "\(noteNames[noteIndex])\(octave)"
    }
}

// MARK: - Modern Button Style
struct ModernButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(configuration.isPressed ? 0.6 : 0.8))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

// MARK: - Extension to make UInt8 Identifiable for sheet
extension UInt8: @retroactive Identifiable {
    public var id: UInt8 { self }
}

// MARK: - Window Dragging View
struct WindowDraggingView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        
        DispatchQueue.main.async {
            if let window = view.window {
                // Remove all window chrome
                window.styleMask = [.borderless, .fullSizeContentView]
                window.isMovableByWindowBackground = true
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.backgroundColor = .clear
                window.isOpaque = false
                window.hasShadow = true
                
                // Set level to floating window
                window.level = .floating
                
                // Hide menu bar when window is key
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            }
        }
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}


// MARK: - Active Keys View
struct ActiveKeysView: View {
    let activeKeys: Set<String>
    
    var body: some View {
        Group {
            if activeKeys.isEmpty {
                // Empty placeholder to maintain layout
                Color.clear
                    .frame(height: 20)
            } else {
                let keys = Array(activeKeys.sorted())
                if keys.count <= 3 {
                    // Show up to 3 keys horizontally
                    HStack(spacing: 4) {
                        ForEach(keys, id: \.self) { key in
                            KeyIndicator(key: key)
                        }
                    }
                } else {
                    // Show count when more than 3 keys
                    HStack(spacing: 2) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                        Text("\(keys.count) keys")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.3))
                    .cornerRadius(4)
                }
            }
        }
    }
}

// MARK: - Key Indicator
struct KeyIndicator: View {
    let key: String
    
    var isShifted: Bool {
        let shiftedChars = ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+", "{", "}", "|", ":", "\"", "<", ">", "?", "~"]
        let uppercaseLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return shiftedChars.contains(key) || uppercaseLetters.contains(key)
    }
    
    var body: some View {
        HStack(spacing: 2) {
            if isShifted {
                Text("⇧")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
            Text(key)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.green.opacity(0.3))
        .cornerRadius(4)
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // App Icon and Title
            VStack(spacing: 12) {
                Image(systemName: "pianokeys")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.2, green: 0.6, blue: 1.0),
                                    Color(red: 0.1, green: 0.3, blue: 0.8)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Text("MidiToRoblox")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Version \(appVersion) (Build \(buildNumber))")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Description
            VStack(spacing: 8) {
                Text("MIDI to Roblox Keyboard Mapper")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Play Roblox piano games with your MIDI keyboard")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            // Links
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/yourusername/MidiToRoblox") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Label("GitHub", systemImage: "link")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                    
                    Button(action: {
                        if let url = URL(string: "https://github.com/yourusername/MidiToRoblox/issues") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Label("Report Issue", systemImage: "exclamationmark.bubble")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // License
            Text("MIT License • 2025")
                .font(.system(size: 11))
                .foregroundColor(.gray)
            
            // Close button
            Button("Close") {
                dismiss()
            }
            .buttonStyle(ModernButtonStyle(color: .gray))
            .keyboardShortcut(.defaultAction)
        }
        .padding(30)
        .frame(width: 400)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
}
