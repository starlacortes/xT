//
//  NotificationContentTests.swift
//  xTTests
//
//  NT1 · X35 — the reminder layout. Exercises the four presets, the custom field
//  subsets, the own-words title (empty fallback, max length), fields whose data
//  is missing, and the "Reminder" placeholder that keeps a hidden preview blank.
//
//  The builder is pure, so every expectation is a plain string comparison. The
//  time segment is computed with the same formatter the builder uses, so the test
//  holds under any locale.
//

import Testing
import Foundation
import UserNotifications
@testable import xT

@Suite("Notification content (NT1)")
struct NotificationContentTests {

    private let context = DoseContext(
        medication: "Estradiol valerate",
        amountMg: 4,
        route: "Injection",
        scheduledDate: Calendar.current.date(
            from: DateComponents(year: 2026, month: 3, day: 4, hour: 18, minute: 0)),
        suggestedSite: "Right thigh"
    )

    private func title(_ layout: NotificationLayout) -> String {
        NotificationContentBuilder.title(for: layout)
    }

    private func body(_ layout: NotificationLayout) -> String {
        NotificationContentBuilder.body(for: context, layout: layout)
    }

    // MARK: - Presets

    @Test func discreetNamesNothing() {
        let layout = NotificationLayout.preset(.discreet)
        let content = NotificationContentBuilder.content(for: context, layout: layout)

        #expect(content.title == "Reminder")
        #expect(content.body == "Your scheduled entry is ready.")
        #expect(content.categoryIdentifier == NotificationType.doseReminderOpen.rawValue)
    }

    @Test func standardNamesMedicationAndAmount() {
        let content = NotificationContentBuilder.content(for: context, layout: NotificationLayout.preset(.standard))

        #expect(content.title == "Dose reminder")
        #expect(content.body == "Estradiol valerate 4 mg")
        #expect(content.categoryIdentifier == NotificationType.doseReminderLog.rawValue)
    }

    @Test func detailedNamesEverything() {
        let layout = NotificationLayout.preset(.detailed)
        let time = AppDateFormatters.time.string(from: context.scheduledDate!)

        #expect(title(layout) == "Dose due")
        #expect(body(layout) == "Estradiol valerate 4 mg · Injection · due \(time) · suggested site: Right thigh")
        #expect(NotificationContentBuilder.categoryIdentifier(for: layout) == NotificationType.doseReminderLog.rawValue)
    }

    @Test func presetsCarryTheRightShapes() {
        #expect(NotificationLayout.preset(.discreet).fields.isEmpty)
        #expect(!NotificationLayout.preset(.discreet).actionLogsDose)
        #expect(NotificationLayout.preset(.standard).title == .doseReminder)
        #expect(NotificationLayout.preset(.standard).actionLogsDose)
        #expect(NotificationLayout.preset(.detailed).title == .doseDue)
        #expect(NotificationLayout.preset(.detailed).fields.contains(.site))
    }

    // MARK: - Custom

    private func custom(title: NotificationLayout.Title = .reminder,
                        fields: Set<NotificationLayout.Field>,
                        actionLogsDose: Bool = false) -> NotificationLayout {
        NotificationLayout(preset: .custom, title: title, fields: fields, actionLogsDose: actionLogsDose)
    }

    @Test func customSubsetJoinsWithSeparator() {
        #expect(body(custom(fields: [.medication, .route])) == "Estradiol valerate · Injection")
    }

    @Test func amountOnlyRendersMilligrams() {
        #expect(body(custom(fields: [.amount])) == "4 mg")
    }

    @Test func missingSiteIsDropped() {
        var noSite = context
        noSite.suggestedSite = nil
        let time = AppDateFormatters.time.string(from: noSite.scheduledDate!)
        let rendered = NotificationContentBuilder.body(for: noSite, layout: NotificationLayout.preset(.detailed))

        #expect(rendered == "Estradiol valerate 4 mg · Injection · due \(time)")
        #expect(!rendered.contains("suggested site"))
    }

    @Test func missingMedicationIsDropped() {
        var noMed = context
        noMed.medication = nil

        #expect(NotificationContentBuilder.body(for: noMed, layout: custom(fields: [.medication]))
                == "Your scheduled entry is ready.")
    }

    @Test func actionCodingFollowsTheToggle() {
        #expect(NotificationContentBuilder.categoryIdentifier(for: custom(fields: [], actionLogsDose: true))
                == NotificationType.doseReminderLog.rawValue)
        #expect(NotificationContentBuilder.actionTitle(for: custom(fields: [], actionLogsDose: true)) == "Log dose")
        #expect(NotificationContentBuilder.actionTitle(for: custom(fields: [])) == "Open")
    }

    // MARK: - Own words

    @Test func ownWordsPassThroughVerbatim() {
        #expect(title(custom(title: .own("Water the plants"), fields: [])) == "Water the plants")
    }

    @Test func blankOwnWordsFallBackToReminder() {
        #expect(title(custom(title: .own("   "), fields: [])) == "Reminder")
        #expect(title(custom(title: .own(""), fields: [])) == "Reminder")
    }

    @Test func ownWordsClampToTheLimit() {
        #expect(NotificationLayout.ownWordsMaxLength == 40)

        let exactly = String(repeating: "b", count: NotificationLayout.ownWordsMaxLength)
        #expect(title(custom(title: .own(exactly), fields: [])) == exactly)

        let overlong = String(repeating: "a", count: NotificationLayout.ownWordsMaxLength + 20)
        let clamped = custom(title: .own(overlong), fields: []).normalized()
        #expect(clamped.title == .own(String(repeating: "a", count: NotificationLayout.ownWordsMaxLength)))
    }

    // MARK: - Journal

    @Test func journalNamesNoDataAndUsesTheChosenTitle() {
        let content = NotificationContentBuilder.journalContent(layout: NotificationLayout.preset(.standard))

        #expect(content.title == "Dose reminder")
        #expect(content.body.isEmpty)
        #expect(content.categoryIdentifier == NotificationType.journalReminder.rawValue)
    }

    // MARK: - Hidden preview

    @Test func hiddenPreviewPlaceholderNamesNothing() {
        #expect(NotificationContentBuilder.hiddenPreviewPlaceholder == "Reminder")
        #expect(NotificationContentBuilder.hiddenPreviewPlaceholder
                == NotificationContentBuilder.title(for: .discreet))
    }

    // MARK: - Persistence

    @MainActor
    @Test func layoutRoundTripsThroughDefaultsAndDefaultsToDiscreet() {
        let defaults = TestDefaults.suite()

        #expect(NotificationLayout.load(from: defaults) == .discreet)

        let saved = custom(title: .own("Plant water"), fields: [.time, .site], actionLogsDose: true)
        saved.save(to: defaults)

        #expect(NotificationLayout.load(from: defaults) == saved)
    }
}
