# Mobile App User Flow Specification

## 1. Overview

Furniture Platform mobil ekotizimi ikki asosiy foydalanuvchi uchun ishlab chiqiladi:

1. Customer App
2. Employee Professional App

Maqsad:

> Mijozga qulay xarid tajribasi, xodimga esa professional sotuv va o'lchash vositasini berish.

---

# 2. Mobile Application Architecture

```text id="a7m3qx"

                 Mobile App

                     |

          ----------------------

          |                    |

    Customer Mode       Employee Mode

          |                    |

     Marketplace          AR Tools

          |                    |

       Orders             CRM Tasks

```

---

# 3. Customer App Flow

## 3.1 First Launch

Birinchi kirish:

```text id="m8x2pq"

Open App

↓

Language Select

↓

Location Permission

↓

Login/Register

↓

Home Page

```

---

# 4. Registration

Variantlar:

* Telefon raqam;
* Email;
* Apple ID;
* Google Account.

---

Natija:

User profile yaratiladi.

---

# 5. Home Screen

Asosiy bo'limlar:

* Search;
* Categories;
* Recommended;
* AR Preview;
* Orders.

---

Misol:

```text id="q4m8vx"

🔥 Popular

Kitchen

Bedroom

Living Room

AR Try

```

---

# 6. Product Discovery

Mijoz:

* kategoriya;
* narx;
* material;
* rang;
* kompaniya

bo'yicha qidiradi.

---

Filter:

```text id="p9x3mq"

Price

Size

Style

Location

Rating

```

---

# 7. Product Detail Page

Ko'rsatiladi:

* rasm;
* video;
* 3D model;
* material;
* narx;
* kompaniya;
* reyting.

---

Asosiy tugma:

```text id="w6m2qx"

Try In My Room

```

---

# 8. AR Experience Flow

```text id="x8m4pv"

Open AR

↓

Camera Permission

↓

Scan Room

↓

Detect Surface

↓

Place Furniture

↓

Adjust

↓

Save Design

↓

Request Quote

```

---

# 9. AR Interaction

Mijoz qila oladi:

* aylantirish;
* kattalashtirish;
* rang almashtirish;
* joyini o'zgartirish.

---

# 10. Multi Product Scene

Mijoz:

bir xonaga:

* sofa;
* stol;
* shkaf

qo'yishi mumkin.

---

Misol:

```text id="v5m8qx"

Living Room Design

3 products selected

Estimated price:

25 mln UZS

```

---

# 11. AR Warning System

Tizim tekshiradi:

* joy yetarlimi;
* devorga to'g'ri keladimi;
* to'siq bormi.

---

Misol:

```text id="n3m7px"

Warning:

This cabinet blocks the door.

Move 30 cm left.

```

---

# 12. Design Saving

Mijoz saqlashi mumkin:

* xona dizayni;
* mahsulotlar;
* narx.

---

Keyin:

* oilasi bilan ulashadi;
* kompaniyaga yuboradi.

---

# 13. Order Request Flow

```text id="k7m2qx"

Send Request

↓

Company Receives

↓

Price Confirmation

↓

Production Start

↓

Tracking

```

---

# 14. Order Tracking

Mijoz ko'radi:

```text id="z9m4px"

Order Created

↓

Measurement

↓

Production

↓

Quality Check

↓

Delivery

```

---

# 15. Employee App Flow

Professional rejim.

---

# 16. Employee Login

Xodim:

* kompaniya akkaunti;
* ruxsat darajasi

orqali kiradi.

---

# 17. Employee Dashboard

Ko'rsatadi:

* bugungi tashriflar;
* mijozlar;
* buyurtmalar;
* vazifalar.

---

# 18. Customer Visit Workflow

```text id="m5x8qp"

Open Customer

↓

Navigate Address

↓

Scan Room

↓

Create Design

↓

Calculate Estimate

↓

Send Proposal

```

---

# 19. Professional Room Scan

Xodim rejimi:

oddiy foydalanuvchidan kuchliroq.

Qo'shimcha:

* aniq o'lchash;
* xona xaritasi;
* saqlash.

---

# 20. Measurement System

O'lchanadi:

* devor uzunligi;
* balandlik;
* bo'sh joy.

---

Natija:

```text id="r4m8vx"

Wall:

420 cm

Height:

280 cm

```

---

# 21. Existing Object Detection

Xodim ko'rishi mumkin:

* eski shkaf;
* texnika;
* stol.

---

Tizim:

yangi dizaynni hisoblaydi.

---

# 22. Proposal Generation

Xodim:

AR loyihadan:

* mahsulot;
* konfiguratsiya;
* taxminiy narx

yaratadi.

---

# 23. Employee CRM

Xodim ko'radi:

* mijoz tarixi;
* oldingi loyihalar;
* aloqa.

---

# 24. Notifications

Mobil xabarlar:

Customer:

* buyurtma yangilanishi.

Employee:

* yangi mijoz.

Company:

* yangi lead.

---

# 25. Offline Mode

Muhim:

Ba'zi joylarda internet sust bo'lishi mumkin.

Shuning uchun:

* oldindan yuklangan katalog;
* vaqtinchalik AR fayllar.

---

# 26. Performance Requirements

Ilova:

* tez ochilishi;
* AR silliq ishlashi;
* katta 3D fayllarni optimallashtirishi kerak.

---

# 27. Future Features

Kelajak:

* AI designer;
* voice assistant;
* virtual consultant;
* automatic room design.

---

# 28. Final Vision

Mobil ilova:

oddiy katalog emas.

U:

```text id="s8m2qx"

Shopping

+

AR

+

CRM

+

Sales Tool

```

birlashtirgan platforma bo'ladi.

---

# 29. Summary

Customer uchun:

"Uyimda qanday ko'rinadi?"

savoliga javob beradi.

Employee uchun:

"Qanday qilib tez va ishonchli sotaman?"

savolini hal qiladi.

Furniture Platform mobil ilovasi butun sotuv jarayonini raqamlashtiruvchi vosita bo'ladi.
