import Foundation

public enum AppExclusions {
    /// Excluded out of the box. Most of these also mark copied passwords as concealed, but not
    /// every copy they make is (usernames, notes, one-time codes), so skip the whole app.
    public static let defaultExcluded: [String] = [
        "com.1password.1password",       // 1Password 8
        "com.agilebits.onepassword7",    // 1Password 7
        "com.apple.Passwords",           // Passwords (macOS 15+)
        "com.apple.keychainaccess",      // Keychain Access
        "com.bitwarden.desktop",         // Bitwarden
        "org.keepassxc.keepassxc",       // KeePassXC
        "com.lastpass.LastPass",         // LastPass
    ]

    /// The watcher cannot tell exactly which app wrote to the pasteboard, only which apps were
    /// frontmost around the time it changed. Skip the copy if any of them is excluded, so that
    /// switching apps right after copying a password cannot sneak it into the history.
    public static func shouldSkip(candidateApps: Set<String>, excluded: Set<String>) -> Bool {
        !candidateApps.isDisjoint(with: excluded)
    }
}
