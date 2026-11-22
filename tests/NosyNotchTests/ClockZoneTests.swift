import Foundation
import Testing
@testable import NosyNotch

struct ClockZoneTests {
    @Test
    func includesSystemZonesWithoutDuplicateIdentifiers() {
        let ids = ClockZone.all.map(\.identifier)
        #expect(Set(ids).count == ids.count)
        #expect(Set(TimeZone.knownTimeZoneIdentifiers).isSubset(of: Set(ids)))
        #expect(ids.contains("UTC"))
        #expect(!ClockZone.matching("cordoba").isEmpty)
    }

    @Test
    func searchesAcrossCityAndRegionIgnoringCaseAccentsAndWhitespace() {
        #expect(ClockZone.matching("  AMERICA  new york ").contains { $0.identifier == "America/New_York" })
        #expect(ClockZone.matching("São Paulo").contains { $0.identifier == "America/Sao_Paulo" })
        #expect(ClockZone.matching("Mumbai").contains { $0.identifier == "Asia/Kolkata" })
        #expect(ClockZone.matching("Kolkata").contains { $0.identifier == "Asia/Kolkata" })
        #expect(ClockZone.matching("not-a-real-city").isEmpty)
        #expect(ClockZone.matching("   ") == ClockZone.all)
    }

    @Test
    func resolvesPreviouslyStoredIdentifiersAndRejectsInvalidValues() {
        let previous = ["America/Los_Angeles", "America/New_York", "America/Sao_Paulo", "Europe/London",
                        "Europe/Berlin", "Asia/Dubai", "Asia/Kolkata", "Asia/Singapore", "Asia/Tokyo", "Australia/Sydney"]
        #expect(ClockZone.suggested.map(\.identifier) == previous)
        for identifier in previous {
            #expect(ClockZone.resolve(identifier)?.identifier == identifier)
        }
        #expect(ClockZone.resolve("America/Argentina/Cordoba")?.city == "Cordoba")
        #expect(ClockZone.resolve("") == nil)
        #expect(ClockZone.resolve("Unknown/Invalid") == nil)
    }

    @Test
    func offsetsFollowDaylightSavingAndPreserveFractionalHours() {
        let winter = Date(timeIntervalSince1970: 1_768_478_400) // 2026-01-15 UTC
        let summer = Date(timeIntervalSince1970: 1_784_073_600) // 2026-07-15 UTC
        #expect(ClockZone.resolve("Europe/London")?.utcOffsetText(at: winter) == "UTC")
        #expect(ClockZone.resolve("Europe/London")?.utcOffsetText(at: summer) == "UTC+01:00")
        #expect(ClockZone.resolve("Asia/Kolkata")?.utcOffsetText(at: winter) == "UTC+05:30")
        #expect(ClockZone.resolve("Asia/Kathmandu")?.utcOffsetText(at: winter) == "UTC+05:45")
        #expect(ClockZone.resolve("America/Argentina/Cordoba")?.utcOffsetText(at: winter) == "UTC−03:00")
    }
}
