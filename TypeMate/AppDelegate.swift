import Cocoa

/// Main application delegate for TypeMate.
/// Manages the app lifecycle and status bar item.
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    /// Status bar item displayed in the menu bar
    /// Must be a strong reference to prevent deallocation
    private var statusItem: NSStatusItem?
    
    /// Permission manager instance
    private let permissionManager = AccessibilityPermissionManager.shared
    
    /// Suggestion overlay window
    private var suggestionWindow: SuggestionOverlayWindow?
    
    /// Context reader for monitoring typing
    private let contextReader = ContextReader()
    
    /// Input manager for handling keyboard events
    private let inputManager = InputManager()
    
    /// Menu item showing current permission status
    private var statusMenuItem: NSMenuItem!
    
    /// Last captured context for AI generation
    private var lastCapturedContext: CapturedContext?
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[AppDelegate] App launched. Checking permissions...")
        let isTrusted = permissionManager.isTrusted
        print("[AppDelegate] Initial Permission Status: \(isTrusted ? "TRUSTED" : "NOT TRUSTED")")
        
        setupMainMenu()
        setupStatusBarItem()
        setupPermissionMonitoring()
        
        // Initialize suggestion window
        suggestionWindow = SuggestionOverlayWindow()
        
        // Setup dependencies
        setupInputManager()
        
        // Initial status update (starts components if trusted)
        updatePermissionStatus()
    }
    
    private func setupInputManager() {
        // Handle Shortcut Trigger (Cmd+Shift+I)
        inputManager.onTriggerShortcut = { [weak self] in
            print("[AppDelegate] Shortcut Triggered!")
            guard let self = self else { return }
            
            // 1. FIRST: Capture the focused element BEFORE showing our window
            //    (Once our window appears, focus shifts to us!)
            guard let focusedElement = self.contextReader.getFocusedElement() else {
                print("[AppDelegate] No focused element found")
                return
            }
            
            // 2. NOW show Loading Window
            self.suggestionWindow?.showLoading()
            self.suggestionWindow?.updateContextStatus()
            
            // 3. Capture Context in Background using the PRE-CAPTURED element
            DispatchQueue.global(qos: .userInitiated).async {
                let rawContext = self.contextReader.captureContext(from: focusedElement)
                
                // 4. Update UI on Main Thread
                DispatchQueue.main.async {
                    guard var context = rawContext else {
                        print("[AppDelegate] Failed to capture context")
                        self.suggestionWindow?.hide()
                        return
                    }
                    
                    // Apply context priority logic
                    let effectiveContext = ContextManager.shared.getEffectiveContext(
                        autoContext: context.selectedText
                    )
                    
                    // Create updated context with effective context
                    context = CapturedContext(
                        appName: context.appName,
                        selectedText: effectiveContext,
                        valueText: context.valueText,
                        selectionBounds: context.selectionBounds
                    )
                    
                    print("[AppDelegate] Captured: \(context.appName), Context: \(context.selectedText.prefix(30))...")
                    self.lastCapturedContext = context
                    self.suggestionWindow?.showDebug(context)
                }
            }
        }
        
        // Handle Save Context (Cmd+Shift+C)
        inputManager.onSaveContext = { [weak self] in
            print("[AppDelegate] Save Context Triggered!")
            guard let self = self else { return }
            
            // Get currently selected text from the focused element
            if let focusedElement = self.contextReader.getFocusedElement() {
                // Try to read selected text first
                var value: CFTypeRef?
                let result = AXUIElementCopyAttributeValue(
                    focusedElement, 
                    kAXSelectedTextAttribute as CFString, 
                    &value
                )
                
                if result == .success, let text = value as? String, !text.isEmpty {
                    ContextManager.shared.saveContext(text)
                    ToastWindow.show("문맥저장")
                    print("[AppDelegate] Context saved: \(text.prefix(50))...")
                } else {
                    print("[AppDelegate] No selected text to save")
                    ToastWindow.show("텍스트를 선택해주세요")
                }
            }
        }
        
        // Handle Selection from Window (Key Window logic)
        suggestionWindow?.onSelect = { [weak self] text in
            print("[AppDelegate] Selection made: \(text)")
            
            // 1. Hide Window
            self?.suggestionWindow?.hide()
            
            // 2. Hide App (Give focus back to previous app)
            NSApplication.shared.hide(nil)
            
            // 3. Inject Text (Wait slightly for focus to return)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.inputManager.injectText(text)
            }
        }
        
        // Handle Prompt Submission (Refine with additional instruction)
        suggestionWindow?.onSubmitPrompt = { [weak self] prompt in
            print("[AppDelegate] Prompt Submitted: \(prompt)")
            self?.generateAISuggestions(userInstruction: prompt)
        }
        
        // Handle Generate Button (immediate AI generation)
        suggestionWindow?.onGenerate = { [weak self] in
            print("[AppDelegate] Generate Button Pressed!")
            self?.generateAISuggestions(userInstruction: nil)
        }
        
        suggestionWindow?.onCancel = { [weak self] in
            self?.suggestionWindow?.hide()
            NSApplication.shared.hide(nil)
        }
    }
    
    // MARK: - AI Generation
    
    /// Generates AI suggestions using the captured context
    private func generateAISuggestions(userInstruction: String?) {
        guard AIManager.shared.hasAPIKey else {
            suggestionWindow?.showSuggestions(["⚠️ API 키가 설정되지 않았습니다. 메뉴바 → TypeMate Settings에서 API 키를 입력해주세요."])
            return
        }
        
        // Show loading state
        suggestionWindow?.showSuggestions(["⏳ AI가 생성 중입니다..."])
        
        // Get current persona
        let persona = PersonaManager.shared.selectedPersona
        
        // Get project context from ContextLibrary
        let projectContext = ContextLibrary.shared.getSelectedContent()
        
        // Get screen context and selection from captured context
        let screenContext = lastCapturedContext?.selectedText
        let selection = lastCapturedContext?.valueText
        
        AIManager.shared.generateSuggestions(
            persona: persona,
            projectContext: projectContext,
            screenContext: screenContext,
            selection: selection,
            userInstruction: userInstruction
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let suggestions):
                    print("[AppDelegate] AI returned \(suggestions.count) suggestions")
                    self?.suggestionWindow?.showSuggestions(suggestions)
                case .failure(let error):
                    print("[AppDelegate] AI error: \(error.localizedDescription)")
                    self?.suggestionWindow?.showSuggestions(["❌ 오류: \(error.localizedDescription)"])
                }
            }
        }
    }
    
    // ContextReader is now passive, no setup needed
    
    func applicationWillTerminate(_ notification: Notification) {
        permissionManager.stopMonitoring()
        inputManager.stopMonitoring()
    }
    
    // MARK: - Main Menu Setup
    
    /// Creates a standard main menu with an Edit menu
    /// so that Cmd+C/V/X/A work in text fields (e.g. Settings window).
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App menu (required placeholder)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Edit menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    // MARK: - Status Bar Setup
    
    /// Sets up the status bar item with menu
    private func setupStatusBarItem() {
        // Create status bar item with variable length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Configure the button
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "TypeMate")
            button.image?.size = NSSize(width: 18, height: 18)
            button.toolTip = "TypeMate - AI Text Assistant"
        }
        
        // Create and configure the menu
        let menu = NSMenu()
        
        // Status display item (disabled, just for display)
        statusMenuItem = NSMenuItem(title: "Checking permission...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Request permission item
        let requestItem = NSMenuItem(
            title: "Request Permission",
            action: #selector(requestPermissionClicked),
            keyEquivalent: "r"
        )
        requestItem.target = self
        menu.addItem(requestItem)
        
        // TypeMate Settings item
        let typemateSettingsItem = NSMenuItem(
            title: "TypeMate Settings...",
            action: #selector(openTypeMateSettings),
            keyEquivalent: ","
        )
        typemateSettingsItem.target = self
        menu.addItem(typemateSettingsItem)
        
        // Open accessibility settings item
        let settingsItem = NSMenuItem(
            title: "Open Accessibility Settings...",
            action: #selector(openSettingsClicked),
            keyEquivalent: ""
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit item
        let quitItem = NSMenuItem(
            title: "Quit TypeMate",
            action: #selector(quitClicked),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // MARK: - Permission Monitoring
    
    /// Sets up permission status monitoring
    private func setupPermissionMonitoring() {
        permissionManager.onPermissionStatusChanged = { [weak self] isTrusted in
            self?.updatePermissionStatus()
        }
        permissionManager.startMonitoring()
    }
    
    /// Updates the UI based on current permission status
    private func updatePermissionStatus() {
        let isTrusted = permissionManager.isTrusted
        
        if isTrusted {
            statusMenuItem.title = "🟢 Trusted - Accessibility Enabled"
            if let button = statusItem?.button {
                button.image = NSImage(systemSymbolName: "text.bubble.fill", accessibilityDescription: "TypeMate - Trusted")
            }
            // Start monitoring global hotkey
            inputManager.startMonitoring()
        } else {
            statusMenuItem.title = "🔴 Not Trusted - Permission Required"
            if let button = statusItem?.button {
                button.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "TypeMate - Not Trusted")
            }
            inputManager.stopMonitoring()
        }
    }
    
    // MARK: - Menu Actions
    
    @objc private func requestPermissionClicked() {
        permissionManager.requestPermission()
    }
    
    @objc private func openSettingsClicked() {
        permissionManager.openAccessibilitySettings()
    }
    
    @objc private func openTypeMateSettings() {
        SettingsWindowController.shared.showSettings()
    }
    
    @objc private func quitClicked() {
        NSApplication.shared.terminate(nil)
    }
}
