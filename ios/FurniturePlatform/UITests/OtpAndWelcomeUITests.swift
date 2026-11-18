import XCTest

/// Birinchi ochilish ekranidagi til tanlash va OTP kirish oqimining yangi
/// xatti-harakatlari: debug kod ekranda ko'rinmasligi, O'zbekistondan boshqa
/// davlatda SMS-OTP "qo'llanilmaydi" ogohlantirishi va tizimga mos til.
final class OtpAndWelcomeUITests: XCTestCase {
    /// Lokal backend (OTP_DEBUG_RETURN=True) — prod serverda SMS o'chirilgan, shuning
    /// kod bosqichi/cooldown testlari shu manzilga ulanadi (faqat DEBUG build'da ishlaydi).
    private static let localAPI = "http://127.0.0.1:8000/api/v1"

    func testLocationExplanationPrecedesPermissionAndRegionPickerIsRemoved() throws {
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = ["-uiTestingResetState", "-hasCompletedLocationOnboarding", "NO", "-fp.locale", "en"]
        app.launch()
        let useLocation = app.buttons["welcomeUseLocation"]
        XCTAssertTrue(useLocation.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["welcomeLocationExplanation"].exists)
        XCTAssertFalse(app.buttons["Choose a region"].exists)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertFalse(springboard.alerts.firstMatch.waitForExistence(timeout: 2))
        useLocation.tap()
        XCTAssertTrue(springboard.alerts.firstMatch.waitForExistence(timeout: 5))
    }

    func testContinueWithoutLocationOpensCatalogueWithoutPermissionPrompt() throws {
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = ["-uiTestingResetState", "-hasCompletedLocationOnboarding", "NO", "-fp.locale", "en"]
        app.launch()
        let skip = app.buttons["welcomeContinueWithoutLocation"]
        XCTAssertTrue(skip.waitForExistence(timeout: 20))
        skip.tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.waitForExistence(timeout: 2))
    }

    private func launch(onboarded: Bool, locale: String, localAPI: Bool = false, resetLocation: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestingResetState",
            "-hasCompletedLocationOnboarding", onboarded ? "YES" : "NO",
            "-AppleLanguages", "(\(locale))",
            "-AppleLocale", locale,
            // A preference saved by an older release must not override iOS.
            "-fp.locale", locale == "en" ? "uz" : "en",
        ] + (localAPI ? ["-apiBaseURL", Self.localAPI] : [])
        if resetLocation { app.resetAuthorizationStatus(for: .location) }
        app.launch()
        return app
    }

    func testWelcomeFollowsSystemAppLanguage() throws {
        let expectations: [(String, String)] = [
            ("uz", "Uyingiz uchun to‘g‘ri tanlov"),
            ("de", "Die richtige Wahl für Ihr Zuhause"),
            ("ru", "Правильный выбор для вашего дома"),
            ("tr", "Eviniz için doğru seçim"),
            ("en", "The right choice for your home"),
            // Unsupported languages use the English development localization.
            ("fr", "The right choice for your home"),
        ]
        for (language, title) in expectations {
            let app = launch(onboarded: false, locale: language)
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 15), "\(language): noto'g'ri til")
            XCTAssertTrue(app.buttons["appLanguageSettingsButton"].exists)
            app.terminate()
        }
    }

    func testEnglishLocationPermissionMatchesWelcome() throws {
        assertLocationPermission(
            language: "en",
            welcome: "The right choice for your home",
            action: "Use my location",
            purpose: "We need your location to show available furniture products and delivery options in your region."
        )
    }

    func testLanguageButtonOpensSystemSettings() throws {
        let app = launch(onboarded: false, locale: "en")
        let button = app.buttons["appLanguageSettingsButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 10))
    }

    func testRussianLocationPermissionMatchesWelcome() throws {
        assertLocationPermission(
            language: "ru",
            welcome: "Правильный выбор для вашего дома",
            action: "Использовать мою геолокацию",
            purpose: "Ваше местоположение необходимо для показа доступной мебели и условий доставки в вашем регионе."
        )
    }

    private func assertLocationPermission(language: String, welcome: String, action: String, purpose: String) {
        let app = launch(onboarded: false, locale: language, resetLocation: true)
        // Launch arguments affect Bundle in the app process, but permission
        // dialogs use iOS's persisted per-app language. Change that in Settings.
        if Locale.preferredLanguages.first?.hasPrefix(language) != true {
            guard selectSystemAppLanguage(app, language: language) else { return }
        }
        app.resetAuthorizationStatus(for: .location)
        app.launch()
        XCTAssertTrue(app.staticTexts[welcome].waitForExistence(timeout: 15))
        app.buttons[action].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let message = springboard.staticTexts[purpose]
        XCTAssertTrue(message.waitForExistence(timeout: 10), "Permission text must match the app language")
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "\(language)-location-permission"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let alert = springboard.alerts.firstMatch
        if alert.exists, alert.buttons.count > 0 {
            // Complete the request so locationd doesn't retain a pending dialog
            // across tests. The last action in the location prompt is Deny.
            alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
        }
        app.terminate()
    }

    private func selectSystemAppLanguage(_ app: XCUIApplication, language: String) -> Bool {
        let button = app.buttons["appLanguageSettingsButton"]
        guard button.waitForExistence(timeout: 15) else {
            XCTFail("Language settings button is missing")
            return false
        }
        button.tap()
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 10))

        // Some simulator versions open the Settings root for app-settings:.
        if !settings.staticTexts["Language"].exists {
            let apps = settings.staticTexts["Apps"]
            for _ in 0..<8 where !apps.isHittable { settings.swipeUp() }
            if apps.isHittable { apps.tap() }
            let search = settings.searchFields.firstMatch
            if search.waitForExistence(timeout: 5) {
                search.tap()
                search.typeText("VIDA Market")
            }
            let appRow = settings.staticTexts["VIDA Market"].firstMatch
            if appRow.waitForExistence(timeout: 5) { appRow.tap() }
        }

        let languageRow = settings.staticTexts["Language"]
        guard languageRow.waitForExistence(timeout: 5) else {
            let details = XCTAttachment(string: settings.debugDescription)
            details.name = "language-settings-hierarchy"
            details.lifetime = .keepAlways
            add(details)
            XCTFail("The app's Language setting is missing")
            return false
        }
        languageRow.tap()
        let name = language == "ru" ? "Русский" : "English"
        let option = settings.staticTexts[name].firstMatch
        guard option.waitForExistence(timeout: 5) else {
            let details = XCTAttachment(string: settings.debugDescription)
            details.name = "language-options-hierarchy"
            details.lifetime = .keepAlways
            add(details)
            XCTFail("The system language option is missing: \(name)")
            return false
        }
        option.tap()
        app.terminate()
        return true
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
