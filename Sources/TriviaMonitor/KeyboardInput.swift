import Foundation

/// Non-blocking keyboard input handler for terminal
class KeyboardInput {
    private var originalTermios: termios?
    private let inputQueue = DispatchQueue(label: "keyboard.input")
    private var isEnabled = false

    typealias KeyHandler = (Character) -> Void
    private var keyHandler: KeyHandler?

    init() {}

    /// Enable raw mode for non-blocking keyboard input
    func enable(handler: @escaping KeyHandler) {
        self.keyHandler = handler

        // Save original terminal settings
        var raw = termios()
        tcgetattr(STDIN_FILENO, &raw)
        originalTermios = raw

        // Modify for raw input
        raw.c_lflag &= ~(UInt(ECHO | ICANON))  // Disable echo and canonical mode
        raw.c_cc.16 = 0  // VMIN - minimum chars to read
        raw.c_cc.17 = 1  // VTIME - timeout in 0.1s

        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)

        // Set non-blocking
        let flags = fcntl(STDIN_FILENO, F_GETFL)
        _ = fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK)

        isEnabled = true
    }

    /// Check for pending input and call handler if available
    func poll() {
        guard isEnabled else { return }

        var buffer = [UInt8](repeating: 0, count: 1)
        let bytesRead = read(STDIN_FILENO, &buffer, 1)

        if bytesRead > 0 {
            let char = Character(UnicodeScalar(buffer[0]))
            keyHandler?(char)
        }
    }

    /// Restore original terminal settings
    func disable() {
        guard isEnabled else { return }

        if var original = originalTermios {
            tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
        }

        // Remove non-blocking
        let flags = fcntl(STDIN_FILENO, F_GETFL)
        _ = fcntl(STDIN_FILENO, F_SETFL, flags & ~O_NONBLOCK)

        isEnabled = false
    }

    deinit {
        disable()
    }
}
