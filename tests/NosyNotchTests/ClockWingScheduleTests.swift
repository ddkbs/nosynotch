import Foundation
import Testing
@testable import NosyNotch

struct ClockWingScheduleTests {
    @Test
    func idleClockUpdatesAtMinuteBoundariesWithoutSecondTicks() {
        let start = Date(timeIntervalSinceReferenceDate: 123.4)
        var dates = ClockWingSchedule().entries(from: start, mode: .normal)
        #expect(dates.next() == start)
        #expect(dates.next() == Date(timeIntervalSinceReferenceDate: 180))
        #expect(dates.next() == Date(timeIntervalSinceReferenceDate: 240))
        #expect(dates.next() == Date(timeIntervalSinceReferenceDate: 300))
    }

    @Test
    func meetingCountdownUpdatesAtItsOwnBoundariesAndAtTheMeetingStart() {
        let start = Date(timeIntervalSinceReferenceDate: 123.4)
        let meeting = Date(timeIntervalSinceReferenceDate: 250)
        var dates = ClockWingSchedule(meetingStart: meeting).entries(from: start, mode: .normal)
        let expected: [Double] = [123.4, 130, 180, 190, 240, 250, 300]
        for seconds in expected {
            #expect(dates.next() == Date(timeIntervalSinceReferenceDate: seconds))
        }
    }

    @Test
    func expiredMeetingsDoNotProducePastDatesOrExtraTicks() {
        let start = Date(timeIntervalSinceReferenceDate: 180)
        var dates = ClockWingSchedule(meetingStart: start.addingTimeInterval(-10))
            .entries(from: start, mode: .normal)
        #expect(dates.next() == start)
        #expect(dates.next() == start.addingTimeInterval(60))
    }
}
