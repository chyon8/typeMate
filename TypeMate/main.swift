import Cocoa

// Disable stdout buffering for immediate logging
setbuf(__stdoutp, nil)

// Create the shared application instance
let app = NSApplication.shared

// Create and set the app delegate
let delegate = AppDelegate()
app.delegate = delegate

// Activate the app
app.setActivationPolicy(.accessory)

// Run the application
app.run()
