# Security System Module

## 1. Overview

Furniture Platform bir vaqtning o'zida:

* ERP;
* CRM;
* Marketplace;
* AR platforma;
* B2B SaaS

bo'lgani uchun xavfsizlik eng muhim qatlamlardan biri hisoblanadi.

Asosiy maqsad:

> Kompaniya, mijoz va platforma ma'lumotlarini himoyalash hamda ishonchli raqamli ekotizim yaratish.

---

# 2. Security Principles

Asosiy tamoyillar:

1. Data Isolation
2. Authentication
3. Authorization
4. Encryption
5. Auditability
6. Privacy

---

# 3. Security Architecture

```mermaid id="f7k3pw"
graph TD

User

--> Authentication

--> Authorization

--> API Gateway

--> Application


Application

--> Database

Application

--> Storage

Application

--> Audit System
```

---

# 4. Authentication System

Foydalanuvchi tizimga kirishi:

Qo'llab-quvvatlanadi:

* telefon raqam;
* email;
* OAuth;
* biometrik login.

---

# 5. Token System

Mobil va web uchun:

JWT asosida.

Jarayon:

```text id="3n8h4x"
Login

↓

Access Token

↓

API Request

↓

Validation

↓

Response
```

---

# 6. Multi Tenant Security

Eng muhim qism.

Har bir kompaniya alohida ishlaydi.

Misol:

```text id="7k9p2m"
Company A

CAN VIEW:

Own Products

Own Employees

Own Orders


Company B

CAN VIEW:

Own Products

Own Employees

Own Orders
```

---

# 7. Database Isolation

Himoya:

Har bir jadvalda:

```text
company_id
```

bo'ladi.

Misol:

```sql id="k4p8sm"
SELECT *

FROM orders

WHERE company_id = current_company;
```

---

# 8. Role Based Access Control

RBAC tizimi.

---

## Company Owner

Ruxsat:

* moliya;
* xodim;
* mahsulot;
* ERP.

---

## Manager

Ruxsat:

* buyurtma;
* ishlab chiqarish;
* hisobot.

---

## Worker

Ruxsat:

* o'z vazifalari.

---

## Customer

Ruxsat:

* o'z buyurtmalari.

---

# 9. Permission System

Nozik boshqaruv.

Misol:

```text id="m8v2qs"
CREATE_PRODUCT

VIEW_COST

DELETE_ORDER

EXPORT_DATA
```

---

# 10. API Security

Himoya:

* HTTPS;
* JWT;
* Rate Limit;
* Input Validation;
* CSRF Protection.

---

# 11. Rate Limiting

DDoS va abuse oldini olish.

Misol:

```text id="8q3z5f"
User:

100 requests/minute

Limit exceeded:

Temporary block
```

---

# 12. Data Encryption

Muhim ma'lumotlar:

* password;
* payment;
* personal data.

Shifrlanadi.

---

# 13. Password Security

Saqlash:

Hech qachon:

```text
plain password
```

emas.

Ishlatiladi:

* hashing;
* salt.

---

# 14. 3D Model Protection

Mebelchilar uchun juda muhim.

Muammo:

Kimdir premium modelni olib ketishi mumkin.

---

Himoya:

* original faylni bermaslik;
* encrypted storage;
* temporary access;
* watermark;
* streaming.

---

# 15. AR Asset Security

AR model:

```text id="6m2x8p"
Request

↓

Permission Check

↓

Temporary URL

↓

Download Model
```

---

# 16. Customer Privacy

Mijoz ma'lumotlari:

* manzil;
* xona rasmi;
* o'lchamlar

himoyalanadi.

---

# 17. Employee Security

Xodim:

faqat o'ziga tegishli:

* vazifa;
* mijoz;
* buyurtma

ni ko'radi.

---

# 18. Audit Log System

Har bir muhim harakat yoziladi.

Misol:

```json id="5h9v1q"
{
"user":"Ali",
"action":"CHANGE_ORDER_STATUS",
"old":"Production",
"new":"Ready",
"time":"12:30"
}
```

---

# 19. Fraud Prevention

Marketplace uchun:

Nazorat:

* soxta kompaniya;
* soxta review;
* spam;
* noto'g'ri mahsulot.

---

# 20. Verification System

Mebelchilar:

Bosqichlar:

```text id="x8m1pv"
Registered

↓

Documents Checked

↓

Verified

↓

Trusted Partner
```

---

# 21. Payment Security

To'lovlarda:

* payment gateway;
* transaction log;
* refund tracking.

---

# 22. Backup Security

Backup:

* shifrlangan;
* alohida joyda;
* kirish nazoratida.

---

# 23. Monitoring

Aniqlanadi:

* noodatiy login;
* ko'p xatolik;
* shubhali API ishlatish.

---

# 24. Compliance

Turli davlatlarda:

Qo'llab-quvvatlash kerak:

* ma'lumot saqlash qoidalari;
* privacy talablari;
* elektron savdo qonunlari.

---

# 25. Security Development Rules

Developer uchun:

* secret kodga yozilmaydi;
* dependency yangilanadi;
* code review;
* testlar.

---

# 26. Future Security Features

Kelajak:

* AI fraud detection;
* biometric verification;
* blockchain certificate;
* digital product ownership.

---

# 27. Summary

Security System Furniture Platform uchun ishonch asosidir.

U:

* mebelchilar ma'lumotini;
* mijoz maxfiyligini;
* 3D modellarni;
* biznes jarayonlarini

himoya qiladi.

Xavfsizlik kuchli bo'lsa, platforma katta bozorlarga chiqish imkoniga ega bo'ladi.
