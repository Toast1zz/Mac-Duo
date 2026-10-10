import Foundation
import os

/// Read with:
///
///     log show --last 5m --predicate 'subsystem == "com.toast.ToastDuo"'
///
/// Notice level, not info: info level lives only in memory, and `log show`
/// reads the on-disk store.
enum Diagnostics {
    static let geometry = Logger(subsystem: "com.toast.ToastDuo", category: "geometry")
    static let lid = Logger(subsystem: "com.toast.ToastDuo", category: "lid")
}
