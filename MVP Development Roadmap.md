# MVP Development Roadmap Specification

## 1. Overview

Ushbu hujjat Furniture Platform MVP versiyasini ishlab chiqish tartibini belgilaydi.

Maqsad:

* eng muhim biznes qiymatni tez chiqarish;
* keraksiz murakkablikdan qochish;
* arxitekturani kelajakdagi kengayishga tayyor qilish.

---

# 2. Development Strategy

Birinchi versiya:

```text
Modular Monolith

+

API First

+

iOS AR Ready Architecture
```

---

MVP maqsadi:

> Mebelchi kompaniya o'z mahsulotlarini joylay olishi, mijoz ko'rishi, AR orqali tasavvur qilishi va buyurtma berishi.

---

# 3. Development Phases

Umumiy bosqichlar:

```text
Phase 1
Foundation

↓

Phase 2
Marketplace Core

↓

Phase 3
AR System

↓

Phase 4
Business Management

↓

Phase 5
AI Expansion
```

---

# Phase 1 — Foundation

## Maqsad

Platformaning texnik poydevorini yaratish.

---

## Tasks

### Backend

* Django project yaratish;
* PostgreSQL ulash;
* Redis sozlash;
* environment konfiguratsiya.

---

### Authentication

Yaratiladi:

* User model;
* JWT;
* Role system.

---

### Frontend

Yaratiladi:

* React project;
* routing;
* authentication flow.

---

### Mobile

Yaratiladi:

* Swift project;
* ARKit test project.

---

Natija:

Ishlaydigan platforma skeleton.

---

# Phase 2 — Company & Marketplace Core

## Maqsad

Mebelchi va mahsulot tizimini ishga tushirish.

---

## Backend

Modullar:

```text
companies

products

categories

assets

```

---

Funksiyalar:

* kompaniya ro'yxatdan o'tishi;
* katalog yaratish;
* mahsulot qo'shish;
* rasm yuklash.

---

## Frontend

Company Dashboard:

* product list;
* create product;
* edit product.

---

## Customer

Ko'rishi:

* kompaniyalar;
* mahsulotlar;
* narxlar.

---

Natija:

Marketplace ishlaydi.

---

# Phase 3 — 3D Asset System

## Maqsad

Mebelni AR uchun tayyorlash.

---

## Backend

Asset module:

* upload;
* storage;
* processing status.

---

Flow:

```text
Upload Model

↓

Processing

↓

Convert

↓

Ready

```

---

Format:

Input:

* FBX;
* OBJ;
* BLEND.

Output:

* USDZ;
* GLB.

---

Natija:

Mahsulot AR uchun tayyor.

---

# Phase 4 — iOS AR System

## Maqsad

Asosiy texnologik ustunlik.

---

## Customer AR

Funksiyalar:

* mahsulot tanlash;
* xonaga joylashtirish;
* scale;
* rotation.

---

## Employee AR

Funksiyalar:

* LiDAR scan;
* xona o'lchash;
* devor aniqlash.

---

Jarayon:

```text
Scan Room

↓

Analyze Space

↓

Select Furniture

↓

Place Object

↓

Save Design

```

---

Natija:

Professional AR demo.

---

# Phase 5 — Order System

## Maqsad

AR dan real sotuvga o'tish.

---

Funksiyalar:

* cart;
* order;
* status;
* tracking.

---

Flow:

```text
Customer

↓

AR Design

↓

Send Request

↓

Company

↓

Production

↓

Delivery

```

---

# Phase 6 — CRM Module

## Maqsad

Mebelchi mijozlarini boshqarishi.

---

Funksiyalar:

* leads;
* customers;
* history;
* communication.

---

Pipeline:

```text
New Lead

↓

Contact

↓

Negotiation

↓

Order

```

---

# Phase 7 — ERP Basic Module

## Maqsad

Ishlab chiqarishni boshqarish.

---

Funksiyalar:

* production task;
* employee task;
* material.

---

---

# Phase 8 — Geo System

## Maqsad

Yaqin xizmat ko'rsatuvchini topish.

---

Funksiyalar:

* company location;
* service area;
* radius search.

---

Misol:

```text
Customer location

↓

Find furniture companies nearby

```

---

# Phase 9 — Notification System

Funksiyalar:

* push notification;
* order update;
* employee notification.

---

Kanallar:

* mobile push;
* email;
* SMS.

---

# Phase 10 — AI Layer

MVPdan keyingi bosqich.

---

AI imkoniyatlar:

## Design Assistant

Mijozga:

* xona dizayni;
* rang;
* joylashuv.

taklif qiladi.

---

## Recommendation

Misol:

"Bu divanga mos stol."

---

## Computer Vision

Kelajak:

* xona analiz;
* eski mebel aniqlash.

---

# MVP Priority Order

Kodlash tartibi:

```text
1. Backend Setup

2. Authentication

3. Company System

4. Product Catalog

5. Asset Upload

6. Customer App

7. Basic AR

8. Orders

9. CRM

10. ERP
```

---

# What NOT To Build First

Birinchi versiyada qilinmaydi:

* murakkab AI;
* microservices;
* katta analytics;
* to'liq ERP;
* barcha platformalar uchun AR.

---

Sabab:

Asosiy qiymatni tez tekshirish kerak.

---

# MVP Success Criteria

Platforma muvaffaqiyatli hisoblanadi agar:

## Mebelchi:

* ro'yxatdan o'tsa;
* mahsulot qo'shsa;
* 3D model joylasa.

---

## Customer:

* mahsulot ko'rsa;
* AR orqali ko'rsa;
* buyurtma yuborsa.

---

## Employee:

* mijoz joyiga borib;
* AR scan qilsa;
* loyiha yaratsa.

---

# Scaling Plan

MVPdan keyin:

```text
More Companies

↓

More Users

↓

More Servers

↓

Microservices

↓

AI Infrastructure

```

---

# Final Architecture Goal

Yakuniy maqsad:

```text
Furniture Operating System

Marketplace

+

AR Design

+

CRM

+

ERP

+

AI Assistant
```

---

# Conclusion

MVP strategiyasi:

* avval bozor qiymatini isbotlash;
* keyin murakkab funksiyalar qo'shish;
* arxitekturani buzmasdan kengaytirish.

Asosiy prinsip:

> Tez boshlash, lekin katta platforma kabi qurish.
