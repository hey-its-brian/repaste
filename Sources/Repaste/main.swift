import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menu bar only: no Dock icon and no app menu. LSUIElement in Info.plist does the same for the
// bundled app; setting it here also covers `swift run`.
app.setActivationPolicy(.accessory)
app.run()
