import AppKit
import SwiftUI

struct KeyboardCaptureView: NSViewRepresentable {
    let onKeyDown: (KeyboardInput) -> Bool

    func makeNSView(context: Context) -> KeyboardCaptureNSView {
        let view = KeyboardCaptureNSView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyboardCaptureNSView, context: Context) {
        nsView.onKeyDown = onKeyDown
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class KeyboardCaptureNSView: NSView {
    var onKeyDown: ((KeyboardInput) -> Bool)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(KeyboardInput(event: event)) == true {
            return
        }
        super.keyDown(with: event)
    }
}
