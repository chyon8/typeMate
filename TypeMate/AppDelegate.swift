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
    
    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[AppDelegate] App launched. Checking permissions...")
        let isTrusted = permissionManager.isTrusted
        print("[AppDelegate] Initial Permission Status: \(isTrusted ? "TRUSTED" : "NOT TRUSTED")")
        
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
            
            // 1. Capture Context
            if let _ = self.contextReader.captureContext() {
                // Future: Use captured context for AI
                
                // 2. Show Overlay with Mock Data
                let mockSuggestions = [
                    "Option 1: I appreciate the offer, but I will have to decline at this time.",
                    "Option 2: Unfortunately, I cannot accept your invitation. I wish you the best.",
                    "Option 3: Thank you for reaching out. Perhaps we can discuss this later."
                ]
                
                self.suggestionWindow?.showSuggestions(mockSuggestions)
                
            } else {
                 print("[AppDelegate] Failed to capture context")
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
        
        // Handle Prompt Submission (Refine Suggestions)
        suggestionWindow?.onSubmitPrompt = { [weak self] prompt in
            print("[AppDelegate] Prompt Submitted: \(prompt)")
            
            var newSuggestions: [String] = []
            
            let lowered = prompt.lowercased()
            
            if lowered.contains("polite") {
                 newSuggestions = [
                    "I sincerely appreciate your kind offer, however, I must respectfully decline.",
                    "Thank you so much for thinking of me. Unfortunately, I won't be able to make it.",
                    "It is a great honor, but I will have to pass this time. Warm regards."
                 ]
            } else if lowered.contains("short") || lowered.contains("brief") {
                 newSuggestions = [
                    "No thanks.",
                    "Can't make it.",
                    "Pass."
                 ]
            } else if lowered.contains("angry") {
                 newSuggestions = [
                    "Stop emailing me.",
                    "This is unacceptable.",
                    "I am very disappointed."
                 ]
            } else {
                 newSuggestions = [
                    "Refined Option 1: Based on \"\(prompt)\"...",
                    "Refined Option 2: Here is another way to say it...",
                    "Refined Option 3: A third alternative for you."
                 ]
            }
            
            self?.suggestionWindow?.showSuggestions(newSuggestions)
        }
        
        suggestionWindow?.onCancel = { [weak self] in
            self?.suggestionWindow?.hide()
            NSApplication.shared.hide(nil)
        }
    }
    
    // ContextReader is now passive, no setup needed
    
    func applicationWillTerminate(_ notification: Notification) {
        permissionManager.stopMonitoring()
        inputManager.stopMonitoring()
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
        
        // Open settings item
        let settingsItem = NSMenuItem(
            title: "Open Accessibility Settings...",
            action: #selector(openSettingsClicked),
            keyEquivalent: ","
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
    
    @objc private func quitClicked() {
        NSApplication.shared.terminate(nil)
    }
}
