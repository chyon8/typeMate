import Cocoa

/// A lightweight, auto-dismissing toast notification window.
/// Displays a message with modern glassmorphism styling.
final class ToastWindow: NSWindow {
    
    // MARK: - Properties
    
    private static var currentToast: ToastWindow?
    
    private let messageLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        return label
    }()
    
    // MARK: - Initialization
    
    private init(message: String) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 44),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        configureWindow()
        setupUI(message: message)
        positionOnScreen()
    }
    
    // MARK: - Configuration
    
    private func configureWindow() {
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        ignoresMouseEvents = true
    }
    
    private func setupUI(message: String) {
        // Background with blur effect
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .fullScreenUI
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.cornerCurve = .continuous
        visualEffect.layer?.borderWidth = 0.5
        visualEffect.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        
        contentView = visualEffect
        
        // Success checkmark icon with green background
        let iconContainer = NSView()
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 12
        iconContainer.layer?.backgroundColor = NSColor.systemGreen.withAlphaComponent(0.15).cgColor
        
        let iconLabel = NSTextField(labelWithString: "✓")
        iconLabel.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        iconLabel.textColor = .systemGreen
        iconLabel.alignment = .center
        
        iconContainer.addSubview(iconLabel)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 24),
            iconContainer.heightAnchor.constraint(equalToConstant: 24),
            iconLabel.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor)
        ])
        
        // Message with refined typography
        messageLabel.stringValue = message
        messageLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        messageLabel.textColor = .labelColor
        
        let stack = NSStackView(views: [iconContainer, messageLabel])
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.alignment = .centerY
        
        visualEffect.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: visualEffect.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: visualEffect.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: visualEffect.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: visualEffect.trailingAnchor, constant: -20)
        ])
        
        // Resize window to fit content
        let fittingSize = stack.fittingSize
        let newWidth = max(fittingSize.width + 56, 160)
        setContentSize(NSSize(width: newWidth, height: 52))
    }
    
    private func positionOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.maxY - 100
        setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    // MARK: - Public API
    
    /// Shows a toast notification with the given message
    /// - Parameters:
    ///   - message: The message to display
    ///   - duration: How long to show the toast (default 1.5s)
    static func show(_ message: String, duration: TimeInterval = 1.5) {
        DispatchQueue.main.async {
            // Dismiss any existing toast
            currentToast?.orderOut(nil)
            
            let toast = ToastWindow(message: message)
            currentToast = toast
            
            // Fade in
            toast.alphaValue = 0
            toast.makeKeyAndOrderFront(nil)
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                toast.animator().alphaValue = 1
            }
            
            // Auto dismiss after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak toast] in
                guard let toast = toast, toast === currentToast else { return }
                
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.3
                    toast.animator().alphaValue = 0
                }, completionHandler: {
                    toast.orderOut(nil)
                    if currentToast === toast {
                        currentToast = nil
                    }
                })
            }
        }
    }
}
