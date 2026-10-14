import XCTest

/// Birinchi ochilish ekranidagi til tanlash va OTP kirish oqimining yangi
/// xatti-harakatlari: debug kod ekranda ko'rinmasligi, O'zbekistondan boshqa
/// davlatda SMS-OTP "qo'llanilmaydi" ogohlantirishi, 9 tilda dinamik matn.
final class OtpAndWelcomeUITests: XCTestCase {
    /// Lokal backend (OTP_DEBUG_RETURN=True) — prod serverda SMS o'chirilgan, shuning
    /// kod bosqichi/cooldown testlari shu manzilga ulanadi (faqat DEBUG build'da ishlaydi).
    private static let localAPI = "http://127.0.0.1:8000/api/v1"

    private func launch(onboarded: Bool, locale: String, localAPI: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingResetState",
            "-hasCompletedLocationOnboarding", onboarded ? "YES" : "NO",
            "-fp.locale", locale,
        ] + (localAPI ? ["-apiBaseURL", Self.localAPI] : [])
        app.launch()
        return app
    }

    func testWelcomeLanguageMenuSwitchesEveryLanguage() throws {
        let app = launch(onboarded: false, locale: "uz")
        let menu = app.buttons["welcomeLanguageMenu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 15), "Til menyusi yo'q")
        XCTAssertTrue(app.staticTexts["Uyingiz uchun to‘g‘ri tanlov"].exists, "Boshlang'ich til o'zbekcha emas")

        let expectations: [(String, String)] = [
            ("🇩🇪 Deutsch", "Die richtige Wahl für Ihr Zuhause"),
            ("🇷🇺 Русский", "Правильный выбор для вашего дома"),
            ("🇹🇷 Türkçe", "Eviniz için doğru seçim"),
            ("🇬🇧 English", "The right choice for your home"),
        ]
        for (label, title) in expectations {
            menu.tap()
            let item = app.buttons[label]
            XCTAssertTrue(item.waitForExistence(timeout: 5), "\(label) menyuda yo'q")
            item.tap()
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), "\(label): sarlavha o'zgarmadi")
        }
    }

    func testForeignCountryShowsUnsupportedNoticeAndBlocksSend() throws {
        let app = launch(onboarded: true, locale: "en")
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "Tab bar yo'q: \(app.debugDescription)")
        tabBar.buttons.element(boundBy: tabBar.buttons.count - 1).tap() // Profil/Profile tab

        let phoneField = app.textFields["authPhoneField"]
        XCTAssertTrue(phoneField.waitForExistence(timeout: 10), "Telefon maydoni yo'q")
        XCTAssertFalse(app.staticTexts["authCountryUnsupportedNote"].exists)

        // Davlatni Rossiyaga o'zgartiramiz.
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'O\\'zbekiston'")).firstMatch.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Rossiya'")).firstMatch.tap()

        let note = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Uzbekistan numbers only'")
        ).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5), "Ogohlantirish ko'rinmadi")

        phoneField.tap()
        phoneField.typeText("9991234567")
        XCTAssertFalse(app.buttons["authSendCodeButton"].isEnabled, "Boshqa davlatga kod yuborish yoqilgan")
    }

    /// Kod bosqichi: kod ekranda ko'rinmaydi (faqat DEBUG'da ko'rinmas accessibilityValue),
    /// "Qayta yuborish" tugmasi countdown bilan o'chiq turadi. Yangi foydalanuvchi YARATILMAYDI
    /// (kod kiritilmaydi) — faqat bitta OTP so'rovi yuboriladi.
    func testCodeStepHidesCodeAndShowsResendCountdown() throws {
        let app = launch(onboarded: true, locale: "uz", localAPI: true)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20))
        tabBar.buttons.element(boundBy: tabBar.buttons.count - 1).tap()

        let phoneField = app.textFields["authPhoneField"]
        XCTAssertTrue(phoneField.waitForExistence(timeout: 10))
        phoneField.tap()
        phoneField.typeText("90\(Int.random(in: 1_000_000...9_999_999))")
        app.buttons["authSendCodeButton"].tap()

        let label = app.staticTexts["authDebugCodeLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 15), "Kod bosqichi ochilmadi")
        XCTAssertFalse(label.label.contains(where: \.isNumber), "Kod ekranda ko'rinyapti: \(label.label)")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label MATCHES '.*\\d{6}.*'")).firstMatch.exists)

        let resend = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Qayta yuborish'")).firstMatch
        XCTAssertTrue(resend.waitForExistence(timeout: 5))
        XCTAssertFalse(resend.isEnabled, "Countdown paytida qayta yuborish yoqilgan")
        XCTAssertTrue(resend.label.contains("("), "Countdown ko'rinmayapti: \(resend.label)")
    }

    /// Rate-limit/cooldown: qayta so'rov darhol yuborilsa server `otp_cooldown` kodi qaytaradi —
    /// ilova xabarni TANLANGAN tilda (inglizcha) ko'rsatadi, serverning o'zbekcha matnini emas.
    func testCooldownErrorIsLocalizedToSelectedLanguage() throws {
        let app = launch(onboarded: true, locale: "en", localAPI: true)
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20))
        tabBar.buttons.element(boundBy: tabBar.buttons.count - 1).tap()

        let phone = "90\(Int.random(in: 1_000_000...9_999_999))"
        let phoneField = app.textFields["authPhoneField"]
        XCTAssertTrue(phoneField.waitForExistence(timeout: 10))
        phoneField.tap()
        phoneField.typeText(phone)
        app.buttons["authSendCodeButton"].tap()
        XCTAssertTrue(app.staticTexts["authDebugCodeLabel"].waitForExistence(timeout: 15))

        app.buttons["Change number"].tap()
        let send = app.buttons["authSendCodeButton"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        send.tap()

        let message = app.alerts.firstMatch.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'Please wait'")
        ).firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 10), "Cooldown xabari inglizcha chiqmadi: \(app.alerts.firstMatch.debugDescription)")
    }
}
