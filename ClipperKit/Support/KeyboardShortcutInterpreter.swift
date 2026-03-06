import AppKit
import Foundation

struct KeyboardInput: Equatable {
    let keyCode: UInt16
    let characters: String
    let isShiftPressed: Bool

    init(keyCode: UInt16, characters: String, isShiftPressed: Bool) {
        self.keyCode = keyCode
        self.characters = characters
        self.isShiftPressed = isShiftPressed
    }

    init(event: NSEvent) {
        self.init(
            keyCode: event.keyCode,
            characters: event.charactersIgnoringModifiers ?? "",
            isShiftPressed: event.modifierFlags.contains(.shift)
        )
    }
}

enum KeyboardCommand: Equatable {
    case togglePlayback
    case seekBackwardFiveSeconds
    case seekForwardFiveSeconds
    case stepBackwardFrame
    case stepForwardFrame
    case markIn
    case markOut
    case deleteSelectedClip
}

enum KeyboardShortcutInterpreter {
    static func command(for input: KeyboardInput) -> KeyboardCommand? {
        switch input.keyCode {
        case 49:
            return .togglePlayback
        case 123:
            return input.isShiftPressed ? .stepBackwardFrame : .seekBackwardFiveSeconds
        case 124:
            return input.isShiftPressed ? .stepForwardFrame : .seekForwardFiveSeconds
        case 51, 117:
            return .deleteSelectedClip
        default:
            switch input.characters.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "i":
                return .markIn
            case "o":
                return .markOut
            default:
                return nil
            }
        }
    }
}
