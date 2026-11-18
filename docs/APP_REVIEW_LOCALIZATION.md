# VIDA Market: ruxsat oynalarining tili

Review: 1.1.0 (20261103), Guideline 4. Inglizcha onboarding ustida
joylashuv ruxsatining izohi o‘zbekcha chiqqan.

## Tuzatish

- XcodeGen `Resources` papkasini birgalikda skanerlaydi. Natijada
  `InfoPlist.strings` uchun 9 tilli variant guruhi yaratiladi va tarjimalar
  `Copy Bundle Resources` orqali tayyor ilovaga qo‘shiladi. Oldingi
  alohida `.lproj` source yozuvlari tarjimalarni buildga qo‘shmagan.
- Asosiy `Info.plist`dagi ruxsat matnlari development tili — inglizcha.
- SwiftUI interfeysi va ruxsat oynalari bir xil bundle tilidan foydalanadi.
  Eski `fp.locale` interfeysni tizimdan boshqa tilga o‘tkazmaydi.
- Onboarding va profildagi til tugmasi iOS’dagi ilova sozlamalarini ochadi.
  Til shu yerdan almashtiriladi; iOS ilovani yangi tilda qayta ochadi.
  Ishlayotgan jarayonda `AppleLanguages`ni yozib, faqat interfeys tilini
  darhol almashtirish olib tashlangan.
- Qayta yuborish uchun versiya 1.1.0, build 20261118 qilib belgilangan.

## Yuborishdan oldin

1. `ios/FurniturePlatform` ichida `xcodegen generate` bajaring va yangi
   Release archive yarating. Eski buildni qayta yuborish tuzatishni bermaydi.
2. Archive ichidagi tayyor ilovani tekshiring:

   ```sh
   python3 Scripts/verify_localizations.py /path/to/VidaMarket.xcarchive/Products/Applications/VidaMarket.app
   ```

3. Toza o‘rnatishda inglizcha, ruscha va o‘zbekcha onboarding hamda birinchi
   joylashuv ruxsatini tekshiring. Kamera va mikrofon ruxsatlarini ham yangi
   o‘rnatish yoki tiklangan ruxsat holatida tekshiring.
4. Til tugmasi orqali iOS sozlamalarida tilni o‘zgartiring. Qayta ochilgan
   interfeys va hali so‘ralmagan ruxsatning izohi shu tilda chiqishi kerak.
5. Joylashuvni rad etganda viloyatni qo‘lda tanlab davom etishni tekshiring.
   iPhone ilovasini iPad moslik rejimida ham tekshiring.

## Tekshiruv natijalari — 2026-11-14

- To‘liq iOS simulator `build-for-testing`: muvaffaqiyatli.
- Tayyor `.app` ichida 9 tilning har birida 3 tadan ruxsat izohi: muvaffaqiyatli.
- iPhone 17 Pro Max, iOS 26.5, tizim tili inglizcha: inglizcha joylashuv
  ruxsati va onboarding mosligi tekshirildi.
- Shu simulyatorning tizim tili ruscha qilib qayta ishga tushirilganda:
  ruscha joylashuv ruxsati va onboarding mosligi tekshirildi.
- Onboarding: uz/de/ru/tr/en va qo‘llanmaydigan fr → en holatlari o‘tdi.
- Til tugmasining iOS Settings’ni ochishi tekshirildi. Ushbu simulyatorda
  u ba’zan Settings bosh sahifasini ochadi; Apps → VIDA Market → Language
  orqali ilova tiliga kirish mumkin.

**Ochiq qolgan holat:** tizim tili inglizcha bo‘lib, faqat VIDA Market tili
iOS Settings orqali ruschaga o‘zgartirilganda, ushbu simulyatorda ruxsat
oynasi inglizcha qoldi. Ilova sozlamasida `AppleLanguages` ruscha saqlangani
tekshirildi; simulyatorni qayta ochish ham bu holatni bartaraf etmadi.
Buni faqat kesh xatosi deb tasdiqlab bo‘lmaydi. Shu kombinatsiyani haqiqiy
iPhone’da tekshirmasdan barcha til holatlari tuzatilgan deb hisoblamang.
Tekshiruv vaqtida haqiqiy iPhone ulanmagan edi. Kamera/mikrofonning haqiqiy
ruxsat oynalari ham qurilmada tekshirilishi kerak; hozir ularning tarjima
resurslari tekshirildi. iPad moslik rejimi tekshirilmagan.

Ruxsat oynasini tekshirishda faqat Xcode scheme yoki `-AppleLanguages`
argumentidan foydalanish yetarli emas. Apple ham ruxsat oynasi uchun
qurilma tilini o‘zgartirib sinashni tavsiya qiladi:
https://developer.apple.com/forums/thread/663802

Apple til tanlovi haqida:
https://developer.apple.com/library/archive/qa/qa1828/_index.html
