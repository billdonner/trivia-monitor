import Foundation

/// Non-blocking keyboard input handler for terminal
class KeyboardInput {
    private var originalTermios: termios?
    private var isEnabled = false

    typealias KeyHandler = (Character) -> Void
    private var keyHandler: KeyHandler?

    init() {}

    /// Enable raw mode for non-blocking keyboard input
    func enable(handler: @escaping KeyHandler) {
        self.keyHandler = handler

        // Save original terminal settings
        var raw = termios()
        if tcgetattr(STDIN_FILENO, &raw) != 0 {
            return  // Failed to get terminal attributes
        }
        originalTermios = raw

        // Modify for raw input
        raw.c_lflag &= ~(UInt(ECHO | ICANON))  // Disable echo and canonical mode
        raw.c_cc.16 = 0  // VMIN - minimum chars to read
        raw.c_cc.17 = 0  // VTIME - no timeout

        if tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw) != 0 {
            return  // Failed to set terminal attributes
        }

        // Set non-blocking
        let flags = fcntl(STDIN_FILENO, F_GETFL)
        if flags != -1 {
            _ = fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK)
        }

        isEnabled = true
    }

    /// Check for pending input and call handler if available
    func poll() {
        guard isEnabled, let handler = keyHandler else { return }

        var buffer: UInt8 = 0
        let bytesRead = read(STDIN_FILENO, &buffer, 1)

        // bytesRead == -1 with errno EAGAIN means no data available (normal for non-blocking)
        // bytesRead == 1 means we got a character
        if bytesRead == 1 {
            let char = Character(UnicodeScalar(buffer))
            handler(char)
        }
        // Ignore errors (EAGAIN is expected for non-blocking when no data)
    }

    /// Restore original terminal settings
    func disable() {
        guard isEnabled else { return }

        if var original = originalTermios {
            tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
        }

        // Remove non-blocking
        let flags = fcntl(STDIN_FILENO, F_GETFL)
        if flags != -1 {
            _ = fcntl(STDIN_FILENO, F_SETFL, flags & ~O_NONBLOCK)
        }

        isEnabled = false
        keyHandler = nil
    }

    deinit {
        disable()
    }
}
