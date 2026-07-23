# Localization and International Expansion Specification

## 1. Overview

Furniture Platform boshidanoq faqat bitta davlat uchun emas, xalqaro bozor uchun loyihalanadi.

Lekin har bir davlatning:

* tili;
* valyutasi;
* qonuni;
* biznes madaniyati;
* yetkazib berish tizimi

farq qiladi.

Maqsad:

> Platformani lokal ehtiyojlarga moslashtirish, lekin yagona global ekotizim sifatida saqlash.

---

# 2. Expansion Strategy

Bosqichlar:

```text id="a8m3qx"

Uzbekistan

↓

Central Asia

↓

CIS

↓

Global Market

```

---

# 3. Country Configuration System

Har davlat alohida sozlanadi.

Saqlanadi:

* country;
* currency;
* language;
* tax rules;
* measurement system;
* delivery rules.

---

Misol:

```json id="m7x2pq"
{
"country":"Kazakhstan",

"currency":"KZT",

"language":[

"kk",

"ru"

]

}
```

---

# 4. Language System

Platforma ko'p tilli bo'ladi.

Birinchi tillar:

* o'zbek;
* rus;
* qozoq.

---

Keyinchalik:

* ingliz;
* turk;
* boshqa tillar.

---

# 5. Translation Architecture

Matnlar kod ichida yozilmaydi.

Misol:

Noto'g'ri:

```python
text="Buyurtma yaratildi"
```

---

To'g'ri:

```python
translation_key="order_created"
```

---

Natija:

Har davlat o'z tarjimasiga ega bo'ladi.

---

# 6. Currency System

Har davlat:

o'z valyutasidan foydalanadi.

Misol:

```text id="q5m8vx"

Uzbekistan

UZS


Kazakhstan

KZT


Russia

RUB

```

---

# 7. Measurement System

Mebel sanoatida muhim.

Standart:

* santimetr;
* millimetr.

---

Lekin interfeys:

lokal formatda ko'rsatiladi.

---

# 8. Local Business Registration

Har davlatda:

kompaniya ro'yxatdan o'tadi.

Ma'lumotlar:

* nom;
* manzil;
* telefon;
* xizmat hududi.

---

# 9. Regional Availability Logic

Siz aytgan muhim funksiya:

Agar yangi davlat foydalanuvchisi kirsa:

Tizim tekshiradi:

```text id="x3m7pq"

User Location

↓

Search Companies

↓

Found?

```

---

Agar mavjud bo'lsa:

```text id="v8m2qx"

Available companies:

3

```

---

Agar mavjud bo'lmasa:

```text id="n5m3qx"

Hozircha sizning hududingizda
ro'yxatdan o'tgan ustaxonalar yo'q.

```

---

# 10. Test Mode For New Countries

Yangi davlat foydalanuvchisi uchun:

Demo rejim.

---

Misol:

```text id="r6m2qx"

Siz hozir test rejimidasiz.

Boshqa davlatlardagi mahsulotlarni
ko'rishingiz mumkin.

Buyurtma funksiyasi vaqtincha yopiq.

```

---

# 11. Marketplace Expansion Logic

Yangi davlatda:

birinchi bosqich:

* katalog;
* qiziqish yig'ish;
* kompaniyalarni jalb qilish.

---

Ikkinchi:

* buyurtma;
* to'lov;
* yetkazib berish.

---

# 12. Local Company Acquisition

Har davlat uchun:

mahalliy strategiya.

---

Yo'llar:

* to'g'ridan-to'g'ri sotuv;
* hamkorlar;
* marketing;
* tavsiya.

---

# 13. Legal Adaptation

Har davlat:

o'z qoidalariga ega.

Hisobga olinadi:

* soliq;
* elektron to'lov;
* iste'molchi huquqlari;
* ma'lumot himoyasi.

---

# 14. Delivery System Localization

Yetkazib berish:

lokal hamkorlar orqali.

---

Saqlanadi:

* xizmat hududi;
* narx;
* vaqt.

---

# 15. Regional Admin System

Har davlatda:

Country Admin bo'lishi mumkin.

Huquqlar:

* kompaniya tekshirish;
* support;
* moderatsiya.

---

# 16. Local Payment Integration

Har davlat:

o'z to'lov tizimlari.

---

Arxitektura:

```text id="s4m8qx"

Payment Layer

↓

Country Gateway

↓

Transaction

```

---

# 17. Data Residency

Kelajakda:

ayrim davlatlar ma'lumot lokal saqlanishini talab qilishi mumkin.

---

Shuning uchun:

region serverlar qo'llab-quvvatlanadi.

---

# 18. Cultural Localization

Faqat til emas.

Moslashadi:

* dizayn;
* rang;
* marketing;
* xizmat uslubi.

---

# 19. Global Product Catalog

Barcha davlatlarda:

umumiy katalog.

Lekin:

* narx;
* mavjudlik;
* kompaniya

lokal bo'ladi.

---

# 20. Expansion Metrics

Har davlat uchun:

o'lchanadi:

* kompaniya soni;
* aktiv mijoz;
* buyurtma;
* revenue.

---

# 21. Country Launch Checklist

Yangi davlat ochishdan oldin:

✅ Translation

✅ Currency

✅ Payment

✅ Legal

✅ Local Companies

✅ Support

---

# 22. MVP International Support

Birinchi versiyada:

Kerak:

✅ Multi language

✅ Country model

✅ Location filtering

✅ Company availability

---

Keyinchalik:

* lokal payment;
* lokal delivery;
* regional servers.

---

# 23. Strategic Advantage

Ko'p platformalar:

avval bitta davlatda quriladi, keyin moslashtiriladi.

Furniture Platform:

boshidanoq:

global tayyor arxitektura bilan quriladi.

---

# 24. Final Vision

Kelajak:

Foydalanuvchi qayerda bo'lishidan qat'i nazar:

```text id="h7m3qx"

Open App

↓

Select Country

↓

Find Local Furniture

↓

AR Preview

↓

Order

```

ishlaydi.

---

# 25. Summary

Localization tizimi platformaga:

* SNG;
* Osiyo;
* Yevropa;
* global bozor

uchun eshik ochadi.

Asosiy prinsip:

> Mahalliy ishlash, global miqyosda o'sish.
