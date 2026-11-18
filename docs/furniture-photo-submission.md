# Mebel rasmlarini yuborish tartibi — dastlabki standart

Bu surat yuborish tartibi. Model mahsulotning aniq nusxasini yaratishiga kafolat
emas. 2026-10-26 sinovida bir xil Hunyuan 2mv modeliga uch rakurs berilganda
divanning ikki bo‘lakli orqa tuzilmasi tiklandi; bitta rasmda bu qism yaxlit
qilib yaratilgan edi. To‘rtta rakurs hali shu komplektda sinovdan o‘tmagan.

## Surat olish

1. Komplekt uchun kamida uchta turli rakursni maqsad qiling: old, orqa va bir
   yon. Ikkinchi yonni ham olish tavsiya qilinadi; API eng ko‘pi to‘rtta rasm oladi.
2. Asosiy old suratda divan, stol va barcha puflar to‘liq ko‘rinsin. Har rakursda
   oyoqlar va chetlar kesilmasin. Telefonni qiyalatmay, o‘xshash balandlikdan oling.
3. Suratlar orasida mebel, stol va puflar joyini o‘zgartirmang. Har xil
   komplektning suratlarini bitta so‘rovga qo‘shmang.
4. Odamlar, qo‘shni mebel va bezaklar maqsad obyektni to‘smasin. Imkon bo‘lsa
   stol ustidagi gullarni olib turing: model ularni ham geometriyaga qo‘shmoqda.
5. Original JPEG/PNG fayl yuboring. Skrinshot, messenjer yozuvi, filtr va
   portret xiralashtirishi bo‘lmasin. Yorug‘lik va rang barcha rakursda bir xil
   bo‘lsin. Hozirgi multipart so‘rov limiti jami 32 MiB.

## Yuborish

- Har rasmning `front`, `back`, `left` yoki `right` rolini aniq tanlang.
  Old yo‘nalishni bir marta belgilang, qolgan yo‘nalishlarni unga nisbatan
  tanlang. Qiya olingan ikkita old suratni old/orqa deb belgilamang.
- Kamida bitta `front` bo‘lishi, rollar takrorlanmasligi kerak. Bir nechta
  rasmning rolini API fayllar tartibidan taxmin qilmasligi kerak.
- Butun komplekt uchun `reconstruction_scope=set`, bitta buyum uchun `single`.
- Shaklni mustaqil baholash sinovida o‘lchamlar yuborilmaydi. Bunda avtomatik
  masshtab taxminiy; undan aniq santimetr yoki hajm olinmaydi.
- Mahsulotni joylashtirishdan oldin o‘lchangan eni, chuqurligi va balandligini
  alohida tekshiring. O‘lchamga cho‘zish noto‘g‘ri geometriyani tuzatmaydi.

## Natijani qabul qilish

Barcha qismlar, oyoqlar, suyanchiq, stol va puflar borligini old/orqa/yon
ko‘rinishda tekshiring. Ortiqcha devor/pol, bir-biriga yopishgan qismlar,
o‘zgargan joylashuv, yaltiroq mato va tekstura dog‘lari bo‘lsa qayta ko‘rib chiqing.
100% progress faqat hisoblash tugaganini bildiradi.

Hozir geometriya qo‘shimcha rakurslardan foydalanadi, tekstura esa `front`
rasmdan olinadi. FurnitureScanner iOS manbasida hozir faqat bitta rasm tanlash
bor; ushbu ko‘p rakursli tartib uchun mobil tanlash interfeysi alohida yangilanishi
kerak. Veb interfeys to‘rtta rasm va rol tanlashni qo‘llaydi.

Rollar modelning [rasmiy interfeysiga](https://huggingface.co/tencent/Hunyuan3D-2mv)
mos. Uch-to‘rt rakurs tavsiyasi bizning amaliy qabul tartibimiz; barcha mebellarda
tasdiqlangan sifat standarti sifatida talqin qilinmasin.
