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
    
    /// Callback when generate button is pressed (immediate AI generation)
    var onGenerate: (() -> Void)?
    
    /// Callback when cancelled
    var onCancel: (() -> Void)?
    
    /// Custom content view
    private let mainView = NSVisualEffectView()
    
    /// Input field for prompts
    private let promptField: InterceptableTextField = {
        let field = InterceptableTextField()
        field.placeholderString = "추가 지시사항 (예: '더 정중하게', '영어로')"
        field.bezelStyle = .roundedBezel
        field.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        field.drawsBackground = false
        field.isBezeled = false
        field.focusRingType = .none
        field.textColor = .labelColor
        return field
    }()
    
    /// Generate button for immediate AI generation
    private let generateButton: NSButton = {
        let button = NSButton(title: "✨ 생성", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        button.contentTintColor = .systemBlue
        return button
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
        let label = NSTextField(labelWithString: "✨생성  ⌘↩ Refine  ↩ Insert  Esc Close")
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        return label
    }()
    
    private let useContextCheckbox: NSButton = {
        let checkbox = NSButton(checkboxWithTitle: "문맥 이용하기", target: nil, action: nil)
        checkbox.font = NSFont.systemFont(ofSize: 11)
        checkbox.state = .on
        return checkbox
    }()
    
    private let contextStatusLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .systemBlue
        label.alignment = .left
        return label
    }()
    
    // Persona/Context Selectors
    private let personaPopup: NSPopUpButton = {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.font = NSFont.systemFont(ofSize: 12)
        return popup
    }()
    
    private let contextPopup: NSPopUpButton = {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.font = NSFont.systemFont(ofSize: 12)
        return popup
    }()
    
    private let modelLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 10)
        label.textColor = .tertiaryLabelColor
        label.alignment = .right
        return label
    }()
    
    /// Captured context for AI generation
    private var capturedContext: CapturedContext?
    
    /// Callback when AI generates suggestions
    var onAIGenerate: ((CapturedContext?) -> Void)?
    
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
        
        // 1.5 Top Bar (Persona + Context selectors)
        let topBar = NSStackView()
        topBar.orientation = .horizontal
        topBar.spacing = 12
        topBar.alignment = .centerY
        topBar.distribution = .fill
        
        // Persona selector
        let personaLabel = NSTextField(labelWithString: "페르소나:")
        personaLabel.font = NSFont.systemFont(ofSize: 11)
        personaLabel.textColor = .secondaryLabelColor
        topBar.addArrangedSubview(personaLabel)
        
        personaPopup.target = self
        personaPopup.action = #selector(personaChanged)
        topBar.addArrangedSubview(personaPopup)
        
        // Context selector
        let contextLabel = NSTextField(labelWithString: "컨텍스트:")
        contextLabel.font = NSFont.systemFont(ofSize: 11)
        contextLabel.textColor = .secondaryLabelColor
        topBar.addArrangedSubview(contextLabel)
        
        contextPopup.target = self
        contextPopup.action = #selector(contextChanged)
        topBar.addArrangedSubview(contextPopup)
        
        // Spacer
        let spacerTop = NSView()
        spacerTop.setContentHuggingPriority(.defaultLow, for: .horizontal)
        topBar.addArrangedSubview(spacerTop)
        
        // Model indicator
        topBar.addArrangedSubview(modelLabel)
        
        mainView.addSubview(topBar)
        
        // 2. Input Container
        let inputContainer = NSView()
        inputContainer.wantsLayer = true
        inputContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3).cgColor
        inputContainer.layer?.cornerRadius = 10
        
        mainView.addSubview(inputContainer)
        inputContainer.addSubview(promptField)
        
        // Generate button
        generateButton.target = self
        generateButton.action = #selector(generateClicked)
        inputContainer.addSubview(generateButton)
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        
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
        
        // 4. Bottom Bar (Checkbox + Status + Hints)
        let bottomBar = NSStackView()
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 12
        bottomBar.alignment = .centerY
        bottomBar.distribution = .fill
        
        // Configure checkbox action
        useContextCheckbox.target = self
        useContextCheckbox.action = #selector(checkboxToggled)
        
        bottomBar.addArrangedSubview(useContextCheckbox)
        bottomBar.addArrangedSubview(contextStatusLabel)
        
        // Spacer to push hints to the right
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        bottomBar.addArrangedSubview(spacer)
        
        bottomBar.addArrangedSubview(hintsLabel)
        
        mainView.addSubview(bottomBar)
        
        // Layout
        topBar.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        promptField.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Top Bar
            topBar.topAnchor.constraint(equalTo: mainView.topAnchor, constant: 12),
            topBar.leadingAnchor.constraint(equalTo: mainView.leadingAnchor, constant: 20),
            topBar.trailingAnchor.constraint(equalTo: mainView.trailingAnchor, constant: -20),
            topBar.heightAnchor.constraint(equalToConstant: 24),
            
            // Input Container
            inputContainer.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 12),
            inputContainer.leadingAnchor.constraint(equalTo: mainView.leadingAnchor, constant: 20),
            inputContainer.trailingAnchor.constraint(equalTo: mainView.trailingAnchor, constant: -20),
            inputContainer.heightAnchor.constraint(equalToConstant: 44),
            
            // Prompt Field
            promptField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            promptField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 12),
            promptField.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -80),
            
            // Generate Button
            generateButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            generateButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -8),
            generateButton.widthAnchor.constraint(equalToConstant: 65),
            
            // Stack View
            stackView.topAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: mainView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: mainView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -16),
            
            // Bottom Bar
            bottomBar.bottomAnchor.constraint(equalTo: mainView.bottomAnchor, constant: -12),
            bottomBar.leadingAnchor.constraint(equalTo: mainView.leadingAnchor, constant: 20),
            bottomBar.trailingAnchor.constraint(equalTo: mainView.trailingAnchor, constant: -20),
            bottomBar.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Initialize dropdowns
        refreshPersonaPopup()
        refreshContextPopup()
        updateModelLabel()
    }
    
    @objc private func checkboxToggled() {
        ContextManager.shared.useContext = (useContextCheckbox.state == .on)
        print("[SuggestionOverlay] Context toggle: \(ContextManager.shared.useContext)")
    }
    
    /// Updates the context status indicator
    func updateContextStatus() {
        if ContextManager.shared.hasSavedContext() {
            contextStatusLabel.stringValue = "📌 저장된 문맥"
            contextStatusLabel.textColor = .systemBlue
        } else {
            contextStatusLabel.stringValue = ""
        }
        useContextCheckbox.state = ContextManager.shared.useContext ? .on : .off
    }
    
    // MARK: - Dropdown Management
    
    private func refreshPersonaPopup() {
        personaPopup.removeAllItems()
        for persona in PersonaManager.shared.personas {
            personaPopup.addItem(withTitle: persona.name)
        }
        if let selected = PersonaManager.shared.selectedPersona,
           let index = PersonaManager.shared.personas.firstIndex(where: { $0.id == selected.id }) {
            personaPopup.selectItem(at: index)
        }
    }
    
    private func refreshContextPopup() {
        contextPopup.removeAllItems()
        contextPopup.addItem(withTitle: "없음")
        for ctx in ContextLibrary.shared.contexts {
            contextPopup.addItem(withTitle: ctx.name)
        }
        if let selected = ContextLibrary.shared.selectedContext,
           let index = ContextLibrary.shared.contexts.firstIndex(where: { $0.id == selected.id }) {
            contextPopup.selectItem(at: index + 1) // +1 for "없음"
        }
    }
    
    private func updateModelLabel() {
        let provider = AIManager.shared.selectedProvider
        if APIKeyManager.shared.hasKey(for: provider) {
            modelLabel.stringValue = "🤖 \(provider.displayName)"
            modelLabel.textColor = .tertiaryLabelColor
        } else {
            modelLabel.stringValue = "⚠️ API 키 필요"
            modelLabel.textColor = .systemOrange
        }
    }
    
    @objc private func personaChanged() {
        let index = personaPopup.indexOfSelectedItem
        guard index >= 0 && index < PersonaManager.shared.personas.count else { return }
        PersonaManager.shared.select(PersonaManager.shared.personas[index])
        print("[SuggestionOverlay] Persona changed: \(PersonaManager.shared.selectedPersona?.name ?? "none")")
    }
    
    @objc private func contextChanged() {
        let index = contextPopup.indexOfSelectedItem
        if index == 0 {
            ContextLibrary.shared.select(nil)
        } else {
            let ctxIndex = index - 1
            guard ctxIndex >= 0 && ctxIndex < ContextLibrary.shared.contexts.count else { return }
            ContextLibrary.shared.select(ContextLibrary.shared.contexts[ctxIndex])
        }
        print("[SuggestionOverlay] Context changed: \(ContextLibrary.shared.selectedContext?.name ?? "none")")
    }
    
    // MARK: - internal helpers
    
    @objc private func generateClicked() {
        onGenerate?()
    }
    
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
    
    /// Shows a loading indicator while context is being captured
    func showLoading() {
        self.suggestions = []
        self.selectedIndex = -1
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        promptField.stringValue = ""
        
        // Refresh dropdowns and model status every time overlay opens
        refreshPersonaPopup()
        refreshContextPopup()
        updateModelLabel()
        
        let loadingLabel = NSTextField(labelWithString: "⏳ Scanning context...")
        loadingLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        loadingLabel.textColor = .secondaryLabelColor
        loadingLabel.alignment = .center
        
        stackView.addArrangedSubview(loadingLabel)
        
        self.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    /// Stores the captured context and shows it ready for generation
    func showDebug(_ context: CapturedContext) {
        self.capturedContext = context
        self.suggestions = []
        self.selectedIndex = -1
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let debugText = """
        [APP] \(context.appName)
        ---------------------------
        [SELECTED (Context)]
        "\(context.selectedText)"
        
        [VALUE (Input)]
        "\(context.valueText)"
        ---------------------------
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
        
        // Window is already visible from showLoading, just update content
        // But if called directly, ensure window is shown
        if !self.isVisible {
            self.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
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
