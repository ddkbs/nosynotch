import Foundation
import Testing
import SwiftUI
@testable import NosyNotch

@Suite(.serialized)
@MainActor
struct MultiDisplayTests {
    private func withClock(_ body: (Date) -> Void) {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        Clock.startVirtual(at: date)
        defer { Clock.stopVirtual() }
        body(date)
    }

    @Test
    func testDisplaysShareServicesButKeepGeometryAndHoverIndependent() {
        withClock { _ in
            let owner = NotchViewModel(store: SessionStore(),
                                      media: NowPlaying(observeSystem: false), usage: UsageStore(load: false))
            autoreleasepool {
                var external: NotchViewModel? = NotchViewModel(store: owner.store, media: owner.media,
                    approvals: owner.approvals, usage: owner.usage, pet: owner.pet, shelf: owner.shelf,
                    sharedWith: owner)
                #expect(owner.displays.count == 2)
                #expect(external?.replyQueue === owner.replyQueue)
                #expect(external?.calendar === owner.calendar)
                #expect(external?.ports === owner.ports)
                #expect(external?.spectrum === owner.spectrum)
                #expect(external?.head === owner.head)
                external?.notchSize = CGSize(width: 120, height: 24)
                external?.hasPhysicalNotch = false
                external?.isHovering = true
                #expect(!owner.isHovering)
                #expect(owner.hasPhysicalNotch)
                #expect(owner.notchSize.width == 185)
                owner.replyQueue.add("next", to: "shared-session")
                #expect(external?.replyQueue.items["shared-session"]?.count == 1)
                external = nil
            }
            #expect(owner.displays.count == 1)
        }
    }

    @Test
    func testApprovalOnEitherDisplayResolvesOnceAndClosesEverywhere() {
        withClock { _ in
            let defaults = UserDefaults.standard
            let previous = defaults.object(forKey: Preferences.Key.approvalsInNotch)
            defaults.set(true, forKey: Preferences.Key.approvalsInNotch)
            defer {
                if let previous { defaults.set(previous, forKey: Preferences.Key.approvalsInNotch) }
                else { defaults.removeObject(forKey: Preferences.Key.approvalsInNotch) }
            }
            let store = SessionStore()
            let owner = NotchViewModel(store: store, media: NowPlaying(observeSystem: false),
                                      usage: UsageStore(load: false))
            let external = NotchViewModel(store: store, media: owner.media, approvals: owner.approvals,
                usage: owner.usage, pet: owner.pet, shelf: owner.shelf, sharedWith: owner)
            store.onChange = { [weak owner] in owner?.forEachDisplay { $0.recompute() } }
            let request = HookEvent(name: "PermissionRequest", sessionID: "approval", toolName: "Bash")
            store.handle(request)
            var replies = 0
            owner.approvals.add(request) { _ in replies += 1 }
            guard let approval = owner.attentionApproval else {
                Issue.record("Missing approval on owner display")
                return
            }
            #expect(external.attentionApproval?.id == approval.id)
            external.decide(approval, .allow)
            #expect(replies == 1)
            #expect(owner.approvals.pending.isEmpty)
            #expect(owner.attention == nil)
            #expect(external.attention == nil)
            owner.decide(approval, .deny)
            #expect(replies == 1)
            #expect(store.sessions["approval"]?.isBusy == true)
        }
    }

}
