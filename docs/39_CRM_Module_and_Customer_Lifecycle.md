# CRM Module and Customer Lifecycle Specification

## 1. Overview

Furniture Platform CRM moduli mijoz bilan bo'ladigan barcha munosabatlarni boshqarish uchun yaratiladi.

Asosiy maqsad:

> Mijozni birinchi qiziqishidan boshlab doimiy xaridorgacha bo'lgan jarayonni raqamlashtirish.

CRM orqali kompaniya:

* yangi mijozlarni;
* so'rovlarni;
* takliflarni;
* muzokaralarni;
* buyurtmalarni;
* tarixni

boshqaradi.

---

# 2. CRM Architecture

```text id="c8m2qx"

Customer

↓

Lead

↓

Contact

↓

Design

↓

Quote

↓

Order

↓

Repeat Customer

```

---

# 3. Customer Sources

Mijoz qayerdan kelgani yoziladi.

Manbalar:

* AR ilova;
* marketplace;
* Instagram;
* Telegram;
* reklama;
* tavsiya.

---

Misol:

```text id="m7x4pq"

Customer:

Ali

Source:

Instagram AR Campaign

```

---

# 4. Lead Management

Lead:

hali buyurtma bermagan qiziqqan mijoz.

---

Saqlanadi:

* ism;
* telefon;
* qiziqqan mahsulot;
* budjet;
* joylashuv.

---

# 5. Lead Status System

```text id="p5m8vx"

New Lead

↓

Contacted

↓

Measurement Scheduled

↓

Design Created

↓

Offer Sent

↓

Won / Lost

```

---

# 6. Customer Profile

Har mijoz uchun:

* kontakt;
* manzil;
* oldingi loyihalar;
* buyurtmalar;
* AR dizaynlar.

---

Misol:

```text id="q9m3px"

Customer:

Aziz

Projects:

Kitchen 2026

Bedroom 2027

```

---

# 7. Customer Visit Management

Mebel biznesida joyiga borish muhim.

CRM boshqaradi:

* tashrif vaqti;
* xodim;
* manzil;
* natija.

---

Flow:

```text id="x4m8vq"

Customer Request

↓

Assign Employee

↓

Visit

↓

AR Measurement

↓

Proposal

```

---

# 8. Sales Pipeline

Sotuv jarayoni ko'rinadi.

---

Misol:

```text id="n8m2qx"

10 New Leads

5 Measurements

3 Offers

2 Orders

```

---

# 9. Quotation System

Taklif tayyorlash.

Ichida:

* mahsulot;
* konfiguratsiya;
* narx;
* chegirma;
* muddat.

---

Misol:

```text id="w6m3px"

Kitchen Design

Price:

18 000 000 UZS

Delivery:

20 days

```

---

# 10. AR Proposal Integration

Eng katta ustunlik.

Oddiy taklif:

PDF.

Furniture Platform:

```text id="v7m2qx"

Customer Room

↓

AR Design

↓

Products

↓

Price

↓

Confirm Order

```

---

# 11. Communication History

Barcha aloqa saqlanadi:

* qo'ng'iroq;
* chat;
* xabar;
* tashrif.

---

Maqsad:

Hech qanday mijoz yo'qolmasligi.

---

# 12. Automatic Follow Up

CRM eslatadi:

Misol:

```text id="z5m8qx"

Customer viewed design

3 days ago.

Send follow-up message.

```

---

# 13. Customer Segmentation

Mijozlar bo'linadi:

## New

Yangi.

---

## Interested

Qiziqqan.

---

## Existing

Buyurtma bergan.

---

## VIP

Katta xaridor.

---

# 14. Repeat Sales System

Mebel bir martalik emas.

Kelajak:

Mijozga taklif:

* yangi xona;
* dekor;
* boshqa mebel.

---

# 15. Customer Loyalty

Tizim:

* bonus;
* chegirma;
* tarix.

---

# 16. Review System

Buyurtmadan keyin:

Mijoz baho beradi.

Baholanadi:

* sifat;
* vaqt;
* xizmat.

---

# 17. Complaint Management

Muammo bo'lsa:

CRM yozadi:

* sabab;
* javobgar;
* yechim.

---

# 18. AI CRM Assistant

Kelajak:

AI sotuvchiga yordam beradi.

Misol:

```text id="a8m5qx"

Customer likes modern style.

Recommend:

Minimal kitchen package.

```

---

# 19. Customer Analytics

Kompaniya ko'radi:

* qancha lead;
* conversion;
* o'rtacha chek;
* qayta xarid.

---

# 20. CRM + ERP Integration

Muhim bog'lanish:

```text id="m3q7px"

CRM

↓

Order

↓

ERP Production

↓

Delivery

```

---

# 21. CRM + Marketplace Integration

Marketplace orqali kelgan mijoz:

avtomatik CRMga tushadi.

---

# 22. CRM MVP Scope

Birinchi versiya:

Kerak:

✅ Customer database

✅ Lead management

✅ Sales pipeline

✅ Order connection

✅ Notifications

---

Keyinchalik:

* AI;
* automation;
* loyalty.

---

# 23. Business Value

CRM kompaniyaga beradi:

* ko'proq sotuv;
* kam yo'qotilgan mijoz;
* tezroq xizmat;
* professional ish jarayoni.

---

# 24. Final Vision

Furniture Platform CRM:

oddiy kontakt daftar emas.

Bu:

```text id="s8m4qx"

Marketing

+

Sales

+

Customer Experience

+

AI Assistant

```

markazi bo'ladi.

---

# 25. Summary

ERP biznes ichini boshqaradi.

CRM esa biznesning mijoz bilan munosabatini boshqaradi.

Ikkalasi birlashganda:

> Mebelchi nafaqat ishlab chiqaradi, balki tizimli ravishda sotadi.
