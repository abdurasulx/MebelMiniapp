# Mobile AR Technical Specification

## 1. Overview

Furniture Platform AR Mobile Application oddiy virtual mebel ko'rish dasturi emas.

Uning vazifasi:

> Mijoz yoki xodimga real xona ichida mebelni aniq joylashtirish, o'lchamni tekshirish va interyer o'zgarishini oldindan ko'rsatish.

Asosiy platforma:

* iOS;
* ARKit;
* RealityKit;
* LiDAR Scanner (qo'llab-quvvatlovchi qurilmalarda).

---

# 2. AR Application Roles

Ilova ikki asosiy rejimda ishlaydi.

---

## Customer Mode

Mijoz:

* mebelni ko'radi;
* xonasiga joylashtiradi;
* variantlarni solishtiradi;
* buyurtma yuboradi.

---

## Employee Professional Mode

Mebelchi xodimi:

* mijoz uyiga boradi;
* aniq o'lchaydi;
* professional loyiha ko'rsatadi;
* buyurtma yaratadi.

---

# 3. AR System Architecture

```text id="ar8m2q"

Camera

↓

LiDAR Sensor

↓

Scene Understanding

↓

Room Mapping

↓

Object Placement Engine

↓

AR Visualization

↓

Order System

```

---

# 4. Environment Understanding

AR tizim faqat kamerani emas, xonani tushunishi kerak.

Aniqlanadigan obyektlar:

* pol;
* devor;
* shift;
* eshik;
* deraza;
* stol;
* stul;
* mavjud mebellar.

---

# 5. Room Scanning System

## Scan Process

Foydalanuvchi:

1. Kamerani aylantiradi.
2. Xona xaritasi yig'iladi.
3. Surface aniqlanadi.
4. 3D room model yaratiladi.

---

Natija:

```text id="m4q8px"

Room

├── Walls

├── Floor

├── Ceiling

├── Objects

└── Measurements

```

---

# 6. Surface Detection

AR tizimi har bir joylashuv nuqtasini aniqlaydi.

---

## Floor Placement

Misol:

* divan;
* shkaf;
* stol;
* kreslo.

---

## Wall Placement

Misol:

* televizor paneli;
* osma shkaf;
* dekor.

---

## Table Surface

Misol:

* kichik dekor;
* stol usti buyumlari.

---

# 7. Furniture Placement Rules

Har bir 3D model metadata bilan keladi.

Misol:

```json
{
"type":"kitchen_cabinet",

"placement":"wall",

"size":

{

"width":120,

"height":80

}

}
```

---

Boshqa misol:

```json
{
"type":"chair",

"placement":"floor",

"rotation":"free"
}
```

---

# 8. Smart Placement Engine

Tizim tekshiradi:

## Joy yetarlimi?

Misol:

Shkaf:

Width:
200 cm

Bo'sh joy:

150 cm

Natija:

```text
Mebel sig'maydi.

Tavsiya:
Kichik model tanlang.
```

---

# 9. Collision Detection

AR tizimi to'qnashuvni tekshiradi.

Tekshiriladi:

* devor;
* eshik;
* boshqa mebel;
* odam yurish joyi.

---

Misol:

```text
Warning:

Door opening area blocked.

Move cabinet 40 cm left.
```

---

# 10. Existing Furniture Recognition

Katta loyiha uchun muhim modul.

Misol:

Mijoz oshxonani almashtirmoqchi.

Tizim ko'radi:

* eski shkaf;
* muzlatgich;
* stol;
* texnika.

---

# 11. Old Furniture Removal Mode

Ikki xil rejim bo'ladi.

---

## Simulation Mode

Eski jihozlar virtual o'chiriladi.

Misol:

```text
Old Kitchen

↓

Remove Simulation

↓

New Kitchen Preview
```

---

## Replacement Mode

Tizim:

eski obyekt joyini hisobga oladi.

---

# 12. Object Removal Warning

Muhim xavfsizlik qismi.

Agar foydalanuvchi eski obyektni olib tashlamoqchi bo'lsa:

Tizim ogohlantiradi.

Misol:

```text
Diqqat!

Bu obyekt devorga yoki elektr tizimiga bog'langan bo'lishi mumkin.

Davom etish uchun tasdiqlang.
```

---

# 13. Permission System

Har qanday katta o'zgarish uchun:

Tasdiqlash kerak.

Flow:

```text id="v5m8qx"

User Action

↓

Risk Detection

↓

Warning

↓

Confirmation

↓

Continue

```

---

# 14. Kitchen Planning Mode

Oshxona eng murakkab modul.

Hisobga olinadi:

* devor uzunligi;
* burchak;
* deraza;
* eshik;
* gaz;
* elektr nuqtalari;
* suv chiqishi.

---

# 15. Kitchen Intelligence

Tizim tekshiradi:

## Ish zonasi

* muzlatgich;
* rakovina;
* plita.

---

## Ergonomika

Masalan:

* yurish joyi;
* ochilish masofasi;
* shkaf eshigi.

---

# 16. Furniture Configuration

Mebel o'zgarishi mumkin:

* uzunlik;
* rang;
* material;
* modul soni.

---

Masalan:

```text
Kitchen:

3 metr

↓

4 metr

↓

New Price Estimate
```

---

# 17. Dynamic Price Calculation

AR o'zgarishi ERP bilan bog'lanadi.

Formula:

```text
New Configuration

+

Materials

+

Production Cost

=

Estimated Price
```

---

Muhim:

Bu yakuniy narx emas.

Ko'rsatiladi:

```text
Taxminiy narx

Aniq narx ustaxonadan olinadi.
```

---

# 18. Employee AR Workflow

Xodim keladi:

```text
Login

↓

Select Customer

↓

Scan Room

↓

Place Furniture

↓

Save Design

↓

Generate Estimate

↓

Send Proposal

```

---

# 19. Customer Experience

Mijoz:

* telefon orqali ko'radi;
* variant tanlaydi;
* saqlaydi;
* oilasi bilan ulashadi.

---

# 20. Multi Furniture Scene

Bir vaqtning o'zida:

* stol;
* stul;
* shkaf;
* divan

joylashtirish mumkin.

---

# 21. AR Snapshot and Video

Marketing uchun:

* screenshot;
* video;
* before/after.

---

Misol:

```text
Old Room

↓

New Design

↓

Share Instagram
```

---

# 22. AI Future Integration

Kelajak:

Kamera:

↓

AI tushunadi:

"Bu oshxona"

↓

Tavsiya beradi:

"Mana bu model mos keladi"

---

# 23. Technical Challenges

Asosiy qiyinchiliklar:

* aniq o'lchash;
* yorug'lik;
* katta xonalar;
* turli telefonlar.

---

# 24. MVP AR Scope

Birinchi versiyada:

Kerak:

✅ floor detection

✅ wall detection

✅ furniture placement

✅ size adjustment

✅ screenshot

---

Keyinga:

* object recognition;
* AI design;
* automatic removal.

---

# 25. Final Vision

AR modulning maqsadi:

> Mijozga mebelni sotishdan oldin uni o'z uyida ko'rsatish.

Lekin uzoq muddatli maqsad:

> Telefon orqali butun xonani raqamlashtirib, AI yordamida interyer yaratish.

---

# 26. Summary

Mobile AR tizim:

oddiy "3D qo'yish" emas.

U:

* xona tushunadi;
* o'lchaydi;
* xavfni tekshiradi;
* variantlarni solishtiradi;
* ERP bilan bog'lanadi;
* real biznes jarayoniga ulanadi.

Shu sababli AR Furniture Platformning eng katta texnologik ustunliklaridan biri bo'ladi.
32_Investor_Pitch_Deck_Content.md