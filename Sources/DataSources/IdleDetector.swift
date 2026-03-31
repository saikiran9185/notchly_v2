import Foundation
import IOKit

// Returns system idle time in seconds via IOKit HIDSystem
class IdleDetector {
    static let shared = IdleDetector()
    private init() {}

    func idleSeconds() -> Double {
        var iter: io_iterator_t = 0
        defer { IOObjectRelease(iter) }

        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDSystem"),
            &iter) == KERN_SUCCESS
        else { return 0 }

        let entry = IOIteratorNext(iter)
        defer { IOObjectRelease(entry) }
        guard entry != 0 else { return 0 }

        var dict: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(
            entry, &dict, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let d = dict?.takeRetainedValue() as NSDictionary?
        else { return 0 }

        guard let idle = d["HIDIdleTime"] as? Int64 else { return 0 }
        return Double(idle) / 1_000_000_000   // nanoseconds → seconds
    }

    var idleMinutes: Int { Int(idleSeconds() / 60) }

    // IOKit idle > 1200s = 20 minutes
    var isIdle: Bool { idleSeconds() > 1200 }

    // 5 hours idle → morning gate condition
    var is5HoursIdle: Bool { idleSeconds() > 18000 }
}
