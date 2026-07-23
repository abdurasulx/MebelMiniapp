# Authentication & Authorization Specification

## 1. Overview

Furniture Platform ko'p turdagi foydalanuvchilar bilan ishlaydi.

Shuning uchun authentication va authorization tizimi asosiy xavfsizlik qatlami hisoblanadi.

Tizim quyidagilarni boshqaradi:

* kim ekanligini aniqlash;
* qaysi kompaniyaga tegishli ekanligi;
* qanday huquqlarga ega ekanligi;
* qaysi ma'lumotlarni ko'rishi mumkinligi.

---

# 2. Authentication vs Authorization

## Authentication

Savol:

> Siz kimsiz?

Misol:

* telefon;
* email;
* Apple ID.

---

## Authorization

Savol:

> Siz nima qilishga haqlisiz?

Misol:

* mahsulot qo'shish;
* buyurtma ko'rish;
* narxlarni o'zgartirish.

---

# 3. Authentication Architecture

Tanlov:

```text id="a8m3qx"
JWT Authentication
```

---

Flow:

```text id="m7p2qx"

User

↓

Login

↓

Backend Verification

↓

Generate JWT

↓

Client Storage

↓

API Requests

```

---

# 4. Token Structure

JWT ikki qismdan iborat:

## Access Token

Vazifa:

* API so'rovlar uchun.

Muddat:

```text id="q5m8vx"
15-60 minutes
```

---

## Refresh Token

Vazifa:

* yangi access token olish.

Muddat:

```text id="w8m3qx"
Days / Weeks
```

---

# 5. Client Storage

## Web

Token:

* secure cookie;
* httpOnly.

---

## iOS

Token:

```text id="r6m2qx"
Apple Keychain
```

---

## Android

Token:

* secure storage.

---

# 6. User Registration

## Customer Registration

Foydalanuvchi:

* telefon;
* ism;
* password.

---

Jarayon:

```text id="x3m7pq"

Register

↓

Create User

↓

Assign CUSTOMER role

↓

Login

```

---

# 7. Company Registration

Mebelchi uchun:

```text id="y7m4qx"

Create Account

↓

Create Company

↓

Verify Company

↓

COMPANY_OWNER role

```

---

# 8. User Roles

Asosiy rollar:

```text id="z8m3qx"

SUPER_ADMIN

COUNTRY_ADMIN

COMPANY_OWNER

EMPLOYEE

CUSTOMER

```

---

# 9. Role Description

## SUPER_ADMIN

Platforma egasi.

Huquqlar:

* barcha kompaniyalar;
* tariflar;
* tizim sozlamalari.

---

## COUNTRY_ADMIN

Hudud administratori.

Huquqlar:

* o'z hududidagi kompaniyalar.

---

## COMPANY_OWNER

Mebel biznes egasi.

Huquqlar:

* kompaniya boshqaruvi;
* xodimlar;
* mahsulotlar;
* buyurtmalar;
* CRM.

---

## EMPLOYEE

Oddiy xodim.

Huquqlar:

* topshiriqlar;
* mijoz tashrifi;
* AR scan.

---

## CUSTOMER

Mijoz.

Huquqlar:

* katalog;
* AR preview;
* buyurtma.

---

# 10. Permission Architecture

Har request:

```text id="a9m4qx"

Request

↓

Authentication

↓

Identify User

↓

Check Role

↓

Check Permission

↓

Execute

```

---

# 11. Permission Examples

## Product Create

Ruxsat:

```text id="b5m8qx"

COMPANY_OWNER

```

---

## Product View

Ruxsat:

```text id="c6m3qx"

CUSTOMER

COMPANY_OWNER

EMPLOYEE

```

---

## Employee Management

Ruxsat:

```text id="d7m2qx"

COMPANY_OWNER

```

---

# 12. Company Data Isolation

Eng muhim qoida.

Har kompaniya faqat o'z ma'lumotlarini ko'radi.

---

Misol:

Company A:

```text id="e8m3qx"

Products A

Orders A

Employees A

CRM A

```

---

Company B:

ko'rmaydi.

---

# 13. Tenant Resolution

Har request:

```text id="f9m4qx"

JWT

↓

User ID

↓

Company ID

↓

Data Filter

```

---

Misol:

Django query:

```python
Product.objects.filter(
    company=request.company
)
```

---

# 14. Employee Permission System

Kelajakda granular permission.

Misol:

```text id="g5m8qx"

Employee

|

├── Can View Orders

├── Can Edit Orders

├── Can Scan Room

└── Can Create Customer

```

---

# 15. AR Permission

AR loyihalar himoyalanadi.

Qoidalar:

Customer:

* o'z loyihalari.

Employee:

* biriktirilgan mijozlar.

Company Owner:

* barcha kompaniya loyihalari.

---

# 16. Device Authorization

Professional AR uchun.

Tekshiriladi:

* user;
* company;
* device;
* subscription.

---

Misol:

```text id="h6m3qx"

Employee Login

↓

Check Company

↓

Check AR Access

↓

Allow LiDAR Scan

```

---

# 17. Subscription Based Access

Kelajak SaaS modeli.

Misol:

Free:

* katalog.

Premium:

* AR;
* CRM;
* ERP.

Enterprise:

* AI;
* analytics.

---

# 18. Account Security

Himoya:

* password hashing;
* rate limiting;
* brute force protection;
* session control.

---

# 19. Password Policy

Talab:

* minimum uzunlik;
* kuchli password;
* xavfsiz saqlash.

---

Password:

hech qachon:

```text id="i7m3qx"
plain text
```

ko'rinishida saqlanmaydi.

---

# 20. Audit System

Muhim harakatlar yoziladi.

Misol:

```text id="j8m4qx"

User A changed Product price

Time:

2026-01-01

```

---

# 21. API Security Headers

Qo'llanadi:

* HTTPS;
* CORS;
* CSRF protection;
* secure headers.

---

# 22. Social Login Future

Qo'shilishi mumkin:

* Apple Sign In;
* Google Login;
* Telegram Login.

---

# 23. MVP Authentication Scope

Birinchi versiya:

```text id="k9m5qx"

Phone Login

JWT

Roles

Company Isolation

Basic Permissions

```

---

# 24. Final Authorization Model

```text id="l8m4qx"

Platform

    |

Company

    |

Role

    |

Permission

    |

Resource

```

---

# 25. Summary

Authentication tizimi:

* JWT asosida;
* xavfsiz;
* multi-tenant;
* SaaS modelga tayyor.

Asosiy maqsad:

> Har bir foydalanuvchi faqat o'ziga tegishli imkoniyat va ma'lumotlarga ega bo'lishi.
