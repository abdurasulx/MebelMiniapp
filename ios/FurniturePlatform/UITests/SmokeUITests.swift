import XCTest

/// Backend http://127.0.0.1:8000 ishga tushirilgan bo'lishi kerak (dev muhitida).
/// Har bir test `-uiTestingResetState` bilan boshlanadi — shu orqali oldingi
/// testdan qolgan login sessiyasi tozalanib, testlar bir-biriga bog'liq bo'lmaydi
/// (AuthStore.swift shu argumentni o'qib UserDefaults'dagi tokenni tozalaydi).
final class SmokeUITests: XCTestCase {
    /// Login'dan keyin iOS "Save Password?" tizim so'rovi chiqishi mumkin — avtomatik yopamiz.
    private func addSavePasswordInterruptionMonitor() {
        addUIInterruptionMonitor(withDescription: "Save Password") { alert in
            for label in ["Not Now", "Not Now, Thanks", "Cancel"] {
                let button = alert.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
    }

    private func freshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingResetState"]
        app.launch()
        return app
    }

    func testHomeShowsHeroAndFeaturedProducts() throws {
        let app = freshApp()
        XCTAssertTrue(app.staticTexts["Uyingizga\nqulaylik va hashamat"].waitForExistence(timeout: 10), "Hero banner ko'rinmadi")
        XCTAssertTrue(app.staticTexts["Ommabop mahsulotlar"].waitForExistence(timeout: 5), "Ommabop mahsulotlar bo'limi yo'q")
        XCTAssertTrue(app.staticTexts["Oshxona garnituri"].waitForExistence(timeout: 10), "Mahsulot carousel'da ko'rinmadi")
    }

    func testShopTabSearchAndFilter() throws {
        let app = freshApp()
        app.tabBars.buttons["Katalog"].tap()

        let searchField = app.textFields["Mahsulot yoki firma qidirish…"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10), "Qidiruv maydoni yo'q")

        let card = app.staticTexts["Oshxona garnituri"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Katalog to'rida mahsulot yo'q")

        searchField.tap()
        searchField.typeText("Oshxona")
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Qidiruv mos mahsulotni yashirdi")

        app.buttons["clearSearchButton"].tap()
        searchField.typeText("hechnarsatopilmaydi")
        XCTAssertTrue(app.staticTexts["Mahsulot topilmadi"].waitForExistence(timeout: 5), "Bo'sh natija holati ko'rinmadi")
    }

    func testCatalogToProductDetailToOrderForm() throws {
        let app = freshApp()

        let firstCard = app.staticTexts["Oshxona garnituri"]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10), "Bosh sahifa mahsulotni ko'rsatmadi")
        firstCard.tap()

        let orderButton = app.buttons["📦 Buyurtma berish"]
        XCTAssertTrue(orderButton.waitForExistence(timeout: 10), "Mahsulot sahifasi ochilmadi")
        orderButton.tap()

        // Login qilinmagan bo'lsa xatolik ko'rsatiladi
        let loginHint = app.staticTexts["Buyurtma berish uchun Profil bo'limidan tizimga kiring"]
        XCTAssertTrue(loginHint.waitForExistence(timeout: 5), "Login talabi ko'rsatilmadi")
    }

    func testLoginFlow() throws {
        let app = freshApp()

        app.tabBars.buttons["Profil"].tap()

        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText("owner@test.uz")

        let passwordField = app.secureTextFields["Parol"]
        passwordField.tap()
        passwordField.typeText("test12345")

        addSavePasswordInterruptionMonitor()
        app.buttons["authSubmitButton"].tap()
        app.swipeUp() // interruption monitor'ni ishga tushirish uchun

        let logoutButton = app.buttons["Chiqish"]
        XCTAssertTrue(logoutButton.waitForExistence(timeout: 10), "Login muvaffaqiyatsiz — profil ekrani ochilmadi")
    }

    func testFullOrderFlowAsLoggedInCustomer() throws {
        let app = freshApp()

        // Mijoz sifatida kirish
        app.tabBars.buttons["Profil"].tap()
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText("mijoz2@test.uz")
        app.secureTextFields["Parol"].tap()
        app.secureTextFields["Parol"].typeText("test12345")
        addSavePasswordInterruptionMonitor()
        app.buttons["authSubmitButton"].tap()
        XCTAssertTrue(app.buttons["Chiqish"].waitForExistence(timeout: 10))

        // Token UserDefaults'ga saqlanadi — ilovani (reset argumentisiz) qayta
        // ishga tushirib, sessiya tiklanishini va Bosh sahifada (default)
        // qolishini tekshiramiz — bu ilovani qayta ochgan haqiqiy foydalanuvchi holati.
        app.terminate()
        app.launchArguments = []
        app.launch()

        let card = app.staticTexts["Oshxona garnituri"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Sessiya tiklanmadi yoki katalog yuklanmadi")
        card.tap()

        // Buyurtma berish (dims default variant o'lchamlaridan avtomatik to'ldirilgan)
        let orderButton = app.buttons["📦 Buyurtma berish"]
        XCTAssertTrue(orderButton.waitForExistence(timeout: 10))
        orderButton.tap()

        // Checkout sheet
        let phoneField = app.textFields["Telefon (+998…)"]
        XCTAssertTrue(phoneField.waitForExistence(timeout: 5), "Checkout oynasi ochilmadi")
        phoneField.tap()
        phoneField.typeText("+998901112244")
        let addressField = app.textFields["Manzil"]
        addressField.tap()
        addressField.typeText("Toshkent, Yunusobod")

        app.buttons["Buyurtmani tasdiqlash"].tap()

        let successAlert = app.alerts["Buyurtma qabul qilindi"]
        XCTAssertTrue(successAlert.waitForExistence(timeout: 10), "Buyurtma muvaffaqiyat xabari chiqmadi")
        successAlert.buttons["OK"].tap()
    }

    func testLikeProductAppearsInLikesTab() throws {
        let app = freshApp()

        // Mijoz sifatida kirish
        app.tabBars.buttons["Profil"].tap()
        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText("mijoz2@test.uz")
        app.secureTextFields["Parol"].tap()
        app.secureTextFields["Parol"].typeText("test12345")
        addSavePasswordInterruptionMonitor()
        app.buttons["authSubmitButton"].tap()
        XCTAssertTrue(app.buttons["Chiqish"].waitForExistence(timeout: 10))

        // Token saqlanadi — tab bar login'dan keyin darhol "hittable" bo'lmasligi
        // mumkin bo'lgan holatning oldini olish uchun ilovani qayta ochamiz
        // (haqiqiy foydalanuvchi ilovani qayta ochgan holatga ham mos keladi).
        app.terminate()
        app.launchArguments = []
        app.launch()

        // Sevimlilar dastlab bo'sh
        app.tabBars.buttons["Sevimlilar"].tap()
        XCTAssertTrue(app.staticTexts["Hali sevimli mahsulot yo'q"].waitForExistence(timeout: 10))

        // Bosh sahifadan mahsulotni yoqtirish
        app.tabBars.buttons["Bosh sahifa"].tap()
        let card = app.staticTexts["Oshxona garnituri"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()

        let likeButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'likeButton-'")).firstMatch
        XCTAssertTrue(likeButton.waitForExistence(timeout: 10), "Mahsulot sahifasida yurakcha yo'q")
        likeButton.tap()

        // Sevimlilarda endi ko'rinishi kerak
        app.tabBars.buttons["Sevimlilar"].tap()
        XCTAssertTrue(app.staticTexts["Oshxona garnituri"].waitForExistence(timeout: 20), "Yoqtirilgan mahsulot Sevimlilarda ko'rinmadi")

        // Olib tashlash — bo'sh holatga qaytishi kerak
        let unlikeButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'likeButton-'")).firstMatch
        XCTAssertTrue(unlikeButton.waitForExistence(timeout: 10))
        unlikeButton.tap()
        XCTAssertTrue(app.staticTexts["Hali sevimli mahsulot yo'q"].waitForExistence(timeout: 20))
    }

    func testARButtonReactsToVariantSelection() throws {
        // Bitta 3D model butun mahsulotga tegishli (Product.model3d) — shuning uchun
        // AR tugmasi HAR IKKI variantda ham ko'rinadi, faqat tugma labelidagi variant
        // nomi almashadi (rang/material tanlangan variantga qarab AR ichida qo'llanadi).
        let app = freshApp()

        let card = app.staticTexts["Oshxona garnituri"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()

        let arButtonPredicate = NSPredicate(format: "label CONTAINS 'sinash'")

        // "Oq" standart tanlangan — mahsulot 3D modeliga ega, tugma darhol ko'rinadi
        let arButton = app.buttons.matching(arButtonPredicate).firstMatch
        XCTAssertTrue(arButton.waitForExistence(timeout: 10), "AR tugmasi chiqmadi")
        XCTAssertTrue(arButton.label.contains("Oq"), "AR tugmasi tanlangan variant nomini ko'rsatmadi")

        // "Yong'oq" variantiga o'tamiz — bitta model bo'lgani uchun AR tugmasi
        // yo'qolmaydi, faqat labeldagi variant nomi yangilanadi.
        let yongoqSegment = app.buttons["Yong'oq — 🧊 AR"]
        XCTAssertTrue(yongoqSegment.waitForExistence(timeout: 5), "Yong'oq variant segmentda topilmadi")
        yongoqSegment.tap()
        let arButtonAfter = app.buttons.matching(arButtonPredicate).firstMatch
        XCTAssertTrue(arButtonAfter.waitForExistence(timeout: 5), "Yong'oq variantda AR tugmasi yo'qolib qoldi")
        XCTAssertTrue(arButtonAfter.label.contains("Yong'oq"), "AR tugmasi 'Yong'oq' nomini ko'rsatmadi")
    }
}
