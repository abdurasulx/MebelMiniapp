# Security and Privacy Specification

## 1. Overview

Furniture Platform ko'p tomonlama tizim bo'lgani sababli xavfsizlik asosiy elementlardan biri hisoblanadi.

Platformada:

* kompaniya ma'lumotlari;
* mijoz ma'lumotlari;
* to'lovlar;
* ishlab chiqarish jarayonlari;
* 3D modellar;
* biznes statistikalar

saqlanadi.

Asosiy maqsad:

> Har bir foydalanuvchi faqat o'ziga tegishli ma'lumotlarga ega bo'lishi va platformaga ishonch bilan foydalanishi.

---

# 2. Security Principles

Asosiy tamoyillar:

## Least Privilege

Har bir foydalanuvchiga faqat kerakli huquq beriladi.

---

## Data Isolation

Kompaniyalar ma'lumotlari ajratiladi.

Misol:

```text id="a7m3qx"

Company A

cannot access

Company B data

```

---

## Defense In Depth

Bir nechta himoya qatlami:

```text id="p8x2mv"

Application Security

↓

API Security

↓

Database Security

↓

Infrastructure Security

```

---

# 3. User Authentication

Tizimda:

* telefon raqam;
* email;
* password;
* OTP.

---

Kelajak:

* Face ID;
* biometrik login.

---

# 4. Multi Factor Authentication

Muhim akkauntlar uchun:

* admin;
* kompaniya egasi;
* moliya.

Qo'shimcha:

* SMS;
* authenticator.

---

# 5. Role Based Access Control

Har bir rol o'z huquqiga ega.

Misol:

```text id="m5x9vq"

Owner

|

Manager

|

Employee

|

Customer

```

---

# 6. Permission System

Misollar:

Employee:

* buyurtma ko'radi.

Manager:

* buyurtma o'zgartiradi.

Owner:

* moliyani ko'radi.

---

# 7. Company Data Protection

Kompaniya ma'lumotlari:

* mahsulot;
* narx;
* material;
* ishlab chiqarish.

himoyalanadi.

---

# 8. Customer Privacy

Mijoz ma'lumotlari:

* ism;
* telefon;
* manzil;
* xona rasmlari.

maxfiy saqlanadi.

---

# 9. AR Data Privacy

AR ilova xona ma'lumotlarini olishi mumkin.

Shuning uchun:

* foydalanuvchi roziligi;
* saqlash qoidasi;
* o'chirish imkoniyati

bo'ladi.

---

# 10. Camera Permission Flow

Ilova kamera ishlatishdan oldin:

```text id="q4m8xp"

Request Permission

↓

Explain Purpose

↓

User Accept

↓

Start AR

```

---

Misol:

"AR orqali mebel joylashtirish uchun kamera kerak."

---

# 11. 3D Model Security

Kompaniya yuklagan modellar himoyalanadi.

Muammo:

Raqobatchilar nusxa olishi mumkin.

---

Yechim:

* private storage;
* signed URL;
* watermark;
* access control.

---

# 12. API Security

Himoya:

* JWT;
* token expiration;
* refresh token;
* rate limiting.

---

# 13. API Abuse Protection

Oldini olish:

* spam;
* bot;
* katta fayl hujumi.

---

Misol:

```text id="n7m3qx"

1000 requests/min

↓

Blocked

```

---

# 14. Payment Security

To'lovlarda:

* xavfsiz gateway;
* transaction log;
* verification.

---

Platforma:

kartalarni to'g'ridan-to'g'ri saqlamasligi kerak.

---

# 15. Audit System

Muhim harakatlar yoziladi.

Misol:

```text id="x5m8vp"

User:

Admin

Action:

Changed Subscription

Time:

2026-07-15

```

---

# 16. Fraud Detection

Kelajakda AI yordamida:

aniqlanadi:

* soxta kompaniya;
* spam buyurtma;
* shubhali faoliyat.

---

# 17. Marketplace Trust System

Ishonch yaratish:

## Company Verification

* telefon;
* biznes ma'lumot;
* manzil.

---

## Rating System

Baholanadi:

* sifat;
* vaqt;
* xizmat.

---

## Order History

Mijoz ko'radi:

* bajarilgan ishlar;
* reyting.

---

# 18. Data Encryption

Muhim ma'lumotlar:

* database;
* backup;
* transport.

himoyalanadi.

---

Standart:

HTTPS/TLS.

---

# 19. Backup Security

Backup:

* alohida joyda;
* shifrlangan;
* nazorat ostida.

---

# 20. Employee Device Security

Xodimlar iOS ilovadan foydalanganda:

Nazorat:

* session;
* device;
* login tarixi.

---

# 21. Lost Device Protection

Agar telefon yo'qolsa:

Admin:

* sessionni yopadi;
* accessni bekor qiladi.

---

# 22. International Privacy

Turli davlatlarda:

* lokal qonun;
* data saqlash talablari;
* foydalanuvchi huquqlari

hisobga olinadi.

---

# 23. Security Monitoring

Doimiy kuzatuv:

* loginlar;
* xatolar;
* hujumlar.

---

# 24. Incident Response

Muammo bo'lsa:

```text id="w8m2qx"

Detect

↓

Analyze

↓

Fix

↓

Notify

↓

Improve

```

---

# 25. Security Development Rules

Developerlar uchun:

* secret kodga yozilmaydi;
* environment variable ishlatiladi;
* dependency yangilanadi.

---

# 26. Future AI Security

AI uchun:

* model access;
* API limit;
* data filtering.

---

# 27. Security Roadmap

## MVP

* authentication;
* permissions;
* HTTPS.

---

## Growth

* 2FA;
* audit;
* monitoring.

---

## Enterprise

* advanced security;
* compliance;
* security audit.

---

# 28. Final Vision

Furniture Platform ishonchli sanoat tizimi bo'lishi kerak.

Chunki platformada:

* biznes;
* pul;
* mijoz;
* ishlab chiqarish

jarayonlari boshqariladi.

---

# 29. Summary

Security platformaning qo'shimcha funksiyasi emas.

Bu:

> kompaniyalarni platformaga jalb qiladigan asosiy ishonch omili.

Kuchli xavfsizlik:

* kompaniyalarni himoya qiladi;
* mijoz ishonchini oshiradi;
* xalqaro bozorga chiqishni osonlashtiradi.
