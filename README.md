# MidiToRoblox

A macOS application that converts MIDI keyboard input to Roblox piano keyboard shortcuts, enabling you to play Roblox piano games with your MIDI keyboard.

## Features

- **Real-time MIDI to keyboard mapping** - Play Roblox pianos with your MIDI keyboard
- **61-key support** - Full 5-octave range from C2 to C7
- **Visual feedback** - See active keys highlighted on the virtual keyboard
- **Customizable mappings** - Click any key to customize its keyboard shortcut
- **Sound test mode** - Test your MIDI connection with realistic piano sounds
- **Low latency** - Optimized for responsive gameplay
- **Floating window** - Stays on top for easy access while gaming
- **Auto-device detection** - Automatically selects the first available MIDI device

## Requirements

- macOS 11.0 or later
- MIDI keyboard (tested with iRig KEYS)
- Roblox piano game that supports keyboard input

## Installation

1. Download the latest release from the [Releases](https://github.com/yourusername/MidiToRoblox/releases) page
2. Drag MidiToRoblox.app to your Applications folder
3. On first launch:
   - Right-click the app and select "Open"
   - Click "Open" in the security dialog
   - Grant accessibility permissions when prompted (required for keyboard simulation)

## Usage

1. Connect your MIDI keyboard to your Mac
2. Launch MidiToRoblox
3. Select your MIDI device from the dropdown menu (auto-selects if only one device)
4. Click "Start" to begin mapping MIDI to keyboard shortcuts
5. (Optional) Click the speaker icon to enable sound test mode
6. Open your Roblox piano game
7. Play your MIDI keyboard - the app will send the corresponding keyboard shortcuts

### Controls

- **Start/Stop** - Enable or disable MIDI to keyboard mapping
- **🔄 Reset** - Reset all key mappings to default
- **ℹ️ Info** - View app version and links
- **🔊/🔇 Sound** - Toggle sound test mode (useful for testing without Roblox)
- **↻ Refresh** - Rescan for MIDI devices

## Default Key Mappings

The app maps 61 keys starting from C2:
- **White keys**: Numbers 1-0, then lowercase letters (qwertyuiop, asdfghjkl, zxcvbnm)
- **Black keys**: Shift + numbers (!@#$%^&*), then uppercase letters

## Customizing Key Mappings

1. Click any key on the virtual keyboard
2. Enter the desired keyboard shortcut
3. Click "Save"
4. Your custom mappings are saved automatically

To reset all mappings to default, click the reset button (↻) in the toolbar.

## Troubleshooting

### MIDI device not showing up
- Click the refresh button (↻) next to the MIDI dropdown
- Ensure your MIDI device is properly connected
- Try unplugging and reconnecting your MIDI device

### Keys not working in Roblox
- Make sure MidiToRoblox is running and "Active" 
- Ensure Roblox is the active window when playing
- Check that your key mappings match the Roblox piano's expected inputs

### Console warnings about CoreAudio
You may see warnings like "AddInstanceForFactory: No factory registered" in the console. These are harmless CoreAudio initialization messages that don't affect functionality. This is a known issue with AVAudioEngine on macOS.

### Sound test not working
If the sound test plays beeps instead of piano sounds, the audio engine couldn't initialize. The app will still work perfectly for playing Roblox - the sound test is just for verification.

## Privacy & Security

MidiToRoblox requires accessibility permissions to send keyboard events. The app:
- Does not collect any personal data
- Does not connect to the internet
- Only reads MIDI input and sends keyboard events
- All settings are stored locally on your Mac

## Building from Source

1. Clone the repository
2. Open `MidiToRoblox.xcodeproj` in Xcode
3. Select "MidiToRoblox" scheme
4. Build and run (Cmd+R) or archive for distribution (Product → Archive)

## Support

For issues, feature requests, or questions, please visit the [GitHub Issues](https://github.com/yourusername/MidiToRoblox/issues) page.

## Credits

Created by [Your Name] • Powered by SwiftUI and CoreMIDI

## License

This project is licensed under the MIT License - see the LICENSE file for details.