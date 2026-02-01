import Cocoa

/// A spotlight-style floating window for AI suggestions.
/// Features a glassmorphism background, input field, and selectable suggestion cards.
final class SuggestionOverlayWindow: NSWindow {
    
    // MARK: - Properties
    
    /// Current suggestions displayed
    private(set) var suggestions: [String] = []
    
    /// Currently selected suggestion index (-1 means Input Field is focused)
    private var selectedIndex: Int = -1 {
        didSet { updateSelection() }
    }
    
    /// Callback when a suggestion is selected
    var onSelect: ((String) -> Void)?
    
    /// Callback when a prompt is submitted
    var onSubmitPrompt: ((String) -> Void)?
    
    /// Callback when cancelled
    var onCancel: (() -> Void)?
    
    /// Custom content view
    private let mainView = NSVisualEffectView()
    
    /// Input field for prompts
    private let promptField: InterceptableTextField = {
        let field = InterceptableTextField()
        field.placeholderString = "Ask AI to edit... (e.g. 'More polite')"
        field.bezelStyle = .roundedBezel
        field.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        field.drawsBackground = false
        field.isBezeled = false
        field.focusRingType = .none
        field.textColor = .labelColor
        return field
    }()
    
    /// Stack view to hold suggestion cards
    private let stackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading // Changed from .fill (invalid)
        stack.distribution = .fill
        return stack
    }()
    
    private let hintsLabel: NSTextField = {
        let label = NSTextField(labelWithString: "⌘↩ Refine  ↩ Insert  Esc to Close")
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        return label
    }()
    
    // MARK: - Initialization
    
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        configureWindow()
        setupUI()
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    // MARK: - Setup
    
    private func configureWindow() {
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        titlebarAppearsTransparent = true
        hasShadow = true
        isMovableByWindowBackground = true
        center()
    }
    
    private func setupUI() {
        // 1. Background (Glassmorphism)
        mainView.material = .hudWindow
        mainView.state = .active
        mainView.blendingMode = .behindWindow
        mainView.wantsLayer = true
        mainView.layer?.cornerRadius = 16
        mainView.layer?.cornerCurve = .continuous
        
        contentView = mainView
        
        // 2. Input Container (Top)
        let inputContainer = NSView()
        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3).cgColor
        inputContainer.layer?.cornerRadius = 10
        
        mainView.addSubview(inputContainer)
        inputContainer.addSubview(promptField)
        
        // Setup Field Callbacks
        promptField.onArrowKey = { [weak self] keyCode in
            self?.handleArrowKey(keyCode)
        }
        promptField.onEscape = { [weak self] in
            self?.onCancel?()
        }
        promptField.onEnter = { [weak self] in
            guard let self = self else { return }
            
            if self.selectedIndex == -1 {
                // Focus is on input -> Submit Prompt
                self.submitPrompt()
            } else {
                // Focus is on list -> Insert Selection
                self.confirmSelection()
            }
        }
        
        // 3. Stack View (Middle)
        mainView.addSubview(stackView)
        
        // 4. Hints (Bottom)
        mainView.addSubview(hintsLabel)
        
        // Layout
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        promptField.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        hintsLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Input Container
            inputContainer.topAnchor.constraint(equalTo: mainView.topAnchor, constant: 20),
            inputContainer.leadingAnchor.constraint(equalTo: mainView.leadingAnchor, constant: 20),
            inputContainer.trailingAnchor.constraint(equalTo: mainView.trailingAnchor, constant: -20),
            inputContainer.heightAnchor.constraint(equalToConstant: 44),
            
            // Prompt Field
            promptField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            promptField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 12),
            promptField.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12),
            
            // Stack View
            stackView.topAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: mainView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: mainView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: hintsLabel.topAnchor, constant: -20),
            
            // Hints
            hintsLabel.bottomAnchor.constraint(equalTo: mainView.bottomAnchor, constant: -12),
            hintsLabel.trailingAnchor.constraint(equalTo: mainView.trailingAnchor, constant: -20),
            hintsLabel.leadingAnchor.constraint(equalTo: mainView.leadingAnchor, constant: 20)
        ])
    }
    
    // MARK: - internal helpers
    
    private func handleArrowKey(_ keyCode: Int) {
        if keyCode == 126 { // Up
             if selectedIndex > -1 {
                 selectedIndex -= 1
             }
        } else if keyCode == 125 { // Down
             if selectedIndex < suggestions.count - 1 {
                 selectedIndex += 1
             }
        }
    }
    
    private func submitPrompt() {
        let text = promptField.stringValue
        if !text.isEmpty {
            onSubmitPrompt?(text)
        }
    }
    
    private func confirmSelection() {
        if !suggestions.isEmpty {
            onSelect?(suggestions[selectedIndex])
        }
    }
    
    // MARK: - Public Methods
    
    func showSuggestions(_ items: [String]) {
        self.suggestions = items
        self.selectedIndex = -1 // Default to input focus
        
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for (index, text) in items.enumerated() {
            let card = SuggestionCard(text: text, index: index)
            stackView.addArrangedSubview(card)
            card.translatesAutoresizingMaskIntoConstraints = false
            card.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }
        
        updateSelection()
        
        self.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.makeFirstResponder(promptField)
    }
    
    func hide() {
        orderOut(nil)
    }
    
    /// Debug mode: Display raw captured context for verification
    func showDebug(_ context: CapturedContext) {
        self.suggestions = []
        self.selectedIndex = -1
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let debugText = """
        [APP] \(context.appName)
        [SELECTED] "\(context.selectedText)"
        [BOUNDS] \(context.selectionBounds ?? .zero)
        """
        
        // Use NSTextView for scrolling and wrapping
        let textView = NSTextView()
        textView.string = debugText
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.textContainer?.lineBreakMode = .byCharWrapping
        textView.textContainer?.widthTracksTextView = true
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.heightAnchor.constraint(equalToConstant: 300).isActive = true
        scrollView.widthAnchor.constraint(equalToConstant: 560).isActive = true
        
        stackView.addArrangedSubview(scrollView)
        
        self.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    // MARK: - Event Handling
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // Esc
            onCancel?()
            
        case 126: // Up Arrow
            if selectedIndex > -1 {
                 selectedIndex -= 1
            }
            
        case 125: // Down Arrow
            if selectedIndex < suggestions.count - 1 {
                 selectedIndex += 1
            }
            
        case 48: // Tab -> Insert selection (always inserts if something is selected, or maybe just toggles?)
            // If at -1, Tab usually moves focus. For now, let's say Tab inserts first item if nothing selected?
            // Or just stick to: Tab inserts IF selectedIndex >= 0
             if selectedIndex >= 0 {
                confirmSelection()
             } else if !suggestions.isEmpty {
                 // Friendly behavior: Tab at input selects first item
                 selectedIndex = 0
             }
            
        case 36: // Enter
             if selectedIndex == -1 {
                 submitPrompt()
             } else {
                 confirmSelection()
             }
            
        default:
            super.keyDown(with: event)
        }
    }
    
    private func updateSelection() {
        stackView.arrangedSubviews.enumerated().forEach { (index, view) in
            guard let card = view as? SuggestionCard else { return }
            card.isSelected = (index == selectedIndex)
        }
    }
}

// MARK: - Helper Classes

/// A text field that intercepts arrow keys and forwards them
class InterceptableTextField: NSTextField {
    var onArrowKey: ((Int) -> Void)?
    var onEscape: (() -> Void)?
    var onEnter: (() -> Void)?
    
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: // Esc
            onEscape?()
            return true
        case 36, 76: // Enter
            onEnter?()
            return true
        case 126: // Up Arrow
            onArrowKey?(126)
            return true
        case 125: // Down Arrow
            onArrowKey?(125)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
    
    // Also catch standardkeyDown if not caught by keyEquivalent
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126, 125:
             onArrowKey?(Int(event.keyCode))
        default:
            super.keyDown(with: event)
        }
    }
}

/// A single suggestion row/card
class SuggestionCard: NSView {
    
    private let label: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 3
        label.font = NSFont.systemFont(ofSize: 13) // Reverted weight
        label.textColor = .labelColor
        label.drawsBackground = false
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        return label
    }()
    
    var isSelected: Bool = false {
        didSet {
            needsDisplay = true
            label.textColor = isSelected ? .white : .labelColor
        }
    }
    
    init(text: String, index: Int) {
        super.init(frame: .zero)
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 8
        self.layer?.borderWidth = 1
        
        addSubview(label)
        label.stringValue = text
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func updateLayer() {
        if isSelected {
            layer?.backgroundColor = NSColor.systemBlue.cgColor
            layer?.borderColor = NSColor.systemBlue.cgColor
        } else {
            layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.4).cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }
}
