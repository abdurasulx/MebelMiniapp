# MVP Roadmap Module

## 1. Overview

Furniture Platform juda katta ekotizim bo'lgani sababli birinchi versiyada barcha imkoniyatlarni qurish shart emas.

MVP maqsadi:

> Eng katta qiymat beradigan funksiyalarni tez ishga tushirish, real mebelchilar bilan tekshirish va bozor talabini isbotlash.

---

# 2. MVP Strategy

Asosiy prinsip:

```text id="7f3x8m"
Solve Real Problem

↓

Get Real Users

↓

Measure Results

↓

Improve Product
```

---

# 3. MVP Target Users

Birinchi bosqich:

## Furniture Companies

20 ta pilot kompaniya.

---

## Customers

Ularning real mijozlari.

---

## Employees

Mebelchi xodimlari.

---

# 4. MVP Core Value

Birinchi versiyada asosiy savol:

> "Mebelchi bu tizim orqali ko'proq sotadimi va mijoz bilan ishlashi osonlashadimi?"

---

# 5. MVP Modules Priority

## Phase 1 (Critical)

Kerak:

* Company account;
* Product catalog;
* Order management;
* Customer tracking;
* Basic CRM;
* Basic AR preview.

---

## Phase 2

Qo'shiladi:

* Inventory;
* Production workflow;
* Employee mobile app;
* Notifications.

---

## Phase 3

Qo'shiladi:

* AI;
* advanced analytics;
* supplier marketplace;
* service marketplace.

---

# 6. Phase 1 Architecture

```text id="k5m8x2"
Customer App

+

Company Dashboard

+

Backend API

+

Database

+

AR Service
```

---

# 7. First MVP Features

## Company Registration

Mebelchi:

* kompaniya ochadi;
* profil yaratadi;
* xizmatlarini kiritadi.

---

## Product Upload

Mebelchi:

* rasm;
* narx;
* o'lcham;
* material;
* 3D model

yuklaydi.

---

## Customer Catalog

Mijoz:

* mahsulotlarni ko'radi;
* qidiradi;
* tanlaydi.

---

## AR Preview

Birinchi versiya:

* tayyor 3D model;
* xonaga joylashtirish;
* aylantirish.

---

# 8. MVP Order Flow

```mermaid id="q9v4mz"
graph LR

Customer

--> SelectFurniture

--> ARPreview

--> SendRequest

--> Company

--> Confirm

--> Production
```

---

# 9. Employee Pilot App

Birinchi versiyada:

Faqat asosiy funksiyalar:

* login;
* mijoz ro'yxati;
* tashrif;
* AR ko'rsatish;
* buyurtma yaratish.

---

# 10. MVP Database

Minimal jadvallar:

```text id="3y8w1p"
Users

Companies

Products

Orders

Customers

3DModels

Payments
```

---

# 11. MVP Backend

Kerak:

* authentication;
* API;
* admin panel;
* file upload;
* notification.

---

# 12. MVP AR Strategy

Mukammal AI kerak emas.

Boshlanish:

```text id="8x3m5v"
3D Model

↓

AR Placement

↓

Customer Decision
```

---

# 13. Pilot Launch

Pilot:

20 ta mebelchi.

Jarayon:

```text id="r7m2q9"
Select Companies

↓

Train Users

↓

Collect Feedback

↓

Improve System
```

---

# 14. Pilot Metrics

O'lchanadi:

## Business Metrics

* nechta buyurtma;
* qancha sotuv;
* qancha yangi mijoz.

---

## Product Metrics

* AR ishlatilishi;
* mahsulot ko'rilishi;
* konversiya.

---

## Company Metrics

* vaqt tejash;
* xodim samaradorligi.

---

# 15. Feedback System

Har hafta:

* kompaniya fikri;
* mijoz fikri;
* xodim muammolari.

---

# 16. MVPdan Keyingi Bosqich

Agar pilot muvaffaqiyatli bo'lsa:

```text id="n6w3q8"
20 Companies

↓

100 Companies

↓

Regional Marketplace
```

---

# 17. Geographic Expansion

Tizim boshidan:

Qo'llab-quvvatlashi kerak:

* til;
* valyuta;
* davlat;
* vaqt zonasi.

---

# 18. MVPda Qilmaslik Kerak Bo'lgan Ishlar

Birinchi versiyada:

❌ murakkab AI

❌ barcha xizmatlar marketplace

❌ to'liq ERP

❌ juda katta mikroservis arxitekturasi

---

Sabab:

Bozorni tez tekshirish muhim.

---

# 19. Technical Development Order

Tavsiya:

```text id="h8p2mx"
1. Backend Core

↓

2. Company Dashboard

↓

3. Product System

↓

4. Customer App

↓

5. AR Integration

↓

6. Employee App
```

---

# 20. Success Criteria

MVP muvaffaqiyatli hisoblanadi agar:

* 20 kompaniya faol ishlatsa;
* mijozlar AR ishlatsa;
* buyurtmalar oshsa;
* kompaniyalar pul to'lashga tayyor bo'lsa.

---

# 21. Long Term Roadmap

Keyingi bosqich:

## Version 2

* ERP;
* inventory;
* production.

---

## Version 3

* AI;
* suppliers;
* analytics.

---

## Version 4

* International marketplace.

---

# 22. Summary

MVPning asosiy vazifasi:

> Eng katta texnologiyani emas, eng katta biznes qiymatni isbotlash.

Furniture Platform uchun boshlang'ich kuch:

* 20 ta real mebelchi;
* AR tajriba;
* buyurtma tracking;
* marketplace boshlanishi.

Shu asosda katta ekotizim quriladi.
