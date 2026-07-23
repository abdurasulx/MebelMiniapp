# Mobile iOS Architecture Specification

## 1. Overview

Furniture Platform iOS ilovasi platformaning eng muhim qismlaridan biri hisoblanadi.

Sabab:

* professional AR tajriba;
* LiDAR orqali xona tahlili;
* real o'lcham bilan ishlash;
* mijoz uyida dizayn yaratish.

iOS ilova ikki asosiy rejimda ishlaydi:

```text id="a8m3qx"

Customer AR Mode

+

Professional Employee AR Mode

```

---

# 2. Technology Stack

## Language

```text id="m7p2qx"
Swift
```

---

## UI Framework

Asosiy:

```text id="q5m8vx"
SwiftUI
```

---

Qo'shimcha:

```text id="w8m3qx"
UIKit
```

zarur bo'lgan joylarda.

---

# 3. AR Framework

Asosiy:

```text id="r6m2qx"
ARKit
```

---

3D rendering:

```text id="x3m7pq"
RealityKit
```

---

3D format:

```text id="y7m4qx"
USDZ
```

---

# 4. Application Types

## 4.1 Customer Application

Mijoz uchun.

Vazifalar:

* katalog;
* mahsulot tanlash;
* AR preview;
* buyurtma.

---

## 4.2 Professional Employee Application

Mebelchi xodimi uchun.

Vazifalar:

* xona skanerlash;
* o'lchash;
* dizayn yaratish;
* mijozga taklif yuborish.

---

# 5. iOS App Architecture

Tanlov:

```text id="z8m3qx"

MVVM Architecture

```

---

Struktura:

```text id="a9m4qx"

App

|

├── Views

├── ViewModels

├── Models

├── Services

├── AR

├── Networking

└── Storage

```

---

# 6. Networking Layer

Backend bilan aloqa:

```text id="b5m8qx"

Swift App

↓

API Client

↓

REST API

↓

Django Backend

```

---

Ishlatiladi:

* URLSession;
* async/await.

---

# 7. Authentication Flow

Jarayon:

```text id="c6m3qx"

Login

↓

JWT Token

↓

Secure Storage

↓

API Requests

```

---

Token saqlash:

```text id="d7m2qx"
Keychain
```

---

# 8. AR Core System

AR tizimi quyidagi qismlardan iborat:

```text id="e8m3qx"

Camera

↓

ARKit Session

↓

World Tracking

↓

Plane Detection

↓

Object Placement

↓

RealityKit Rendering

```

---

# 9. Room Understanding

Professional rejimda:

tizim tushunadi:

* pol;
* devor;
* shift;
* bo'sh joy.

---

Texnologiyalar:

* ARWorldTracking;
* Scene Reconstruction;
* LiDAR Depth.

---

# 10. LiDAR Room Scan

Faqat qo'llab-quvvatlangan qurilmalarda.

Jarayon:

```text id="f9m4qx"

Start Scan

↓

Move Device Around Room

↓

Collect Depth Data

↓

Generate Mesh

↓

Analyze Space

↓

Save Scene

```

---

# 11. Wall Detection

Tizim:

devorlarni aniqlaydi.

Kerak:

* shkaf;
* oshxona mebeli;
* devorga o'rnatiladigan jihozlar.

---

Natija:

```json id="g5m8qx"
{
"type":"wall",

"position":"",

"size":""

}
```

---

# 12. Furniture Placement System

Har mebel modeli metadata bilan keladi.

Misol:

```json id="h6m3qx"
{
"placement":"floor",

"rotation":true,

"wall_required":false
}
```

---

Qoidalar:

## Floor Furniture

Misol:

* stol;
* stul;
* divan.

---

## Wall Furniture

Misol:

* oshxona shkafi;
* TV panel.

---

# 13. Existing Object Detection

Kelajak funksiyasi.

Maqsad:

xonadagi mavjud narsalarni aniqlash.

Misol:

* eski shkaf;
* stol;
* texnika.

---

Ishlash:

```text id="i7m3qx"

Camera

↓

Vision Model

↓

Object Detection

↓

User Confirmation

```

---

# 14. Replacement Workflow

Siz aytgan holat:

Eski oshxona jihozlarini almashtirish.

Jarayon:

```text id="j8m4qx"

Scan Existing Furniture

↓

Detect Object

↓

Show Replacement Option

↓

Ask Permission

↓

Remove From Visualization

↓

Place New Furniture

```

---

Muhim:

Real dunyodagi obyekt o'zgarmaydi.

Faqat AR ko'rinishida almashtiriladi.

---

# 15. Measurement System

O'lchash:

* xona;
* devor;
* masofa.

---

Natija:

```json id="k9m5qx"
{
"width":3200,

"height":2800,

"depth":4500

}
```

---

# 16. AR Scene Saving

Saqlanadi:

* joylashuv;
* model;
* rotation;
* scale.

---

Backendga yuboriladi:

```text id="l8m4qx"

AR Scene

↓

Project

↓

Customer

↓

Order

```

---

# 17. Offline Mode

Muhim:

Ba'zi joylarda internet bo'lmasligi mumkin.

Saqlanadi:

* scan data;
* draft design.

Keyin sync qilinadi.

---

# 18. Performance Requirements

Maqsad:

* stabil FPS;
* tez yuklanish;
* kam battery sarfi.

---

Optimallashtirish:

* LOD models;
* texture compression;
* background loading.

---

# 19. Device Support

Minimal:

ARKit qo'llaydigan iPhone.

---

Professional:

```text id="m9m5qx"

iPhone Pro

+

iPad Pro

+

LiDAR

```

---

# 20. Security

Himoya:

* user authentication;
* encrypted local storage;
* protected 3D assets.

---

# 21. MVP iOS Scope

Birinchi versiya:

✅ Login

✅ Product catalog

✅ Download USDZ

✅ Basic AR placement

✅ Save AR scene

---

Professional pilot:

✅ LiDAR scan

✅ Measurement

✅ Room planning

---

# 22. Future Features

Keyinchalik:

* AI interior designer;
* voice assistant;
* automatic room planning;
* full digital twin.

---

# 23. Final Architecture

```text id="n8m3qx"

iOS App

|

SwiftUI

|

ARKit + RealityKit

|

LiDAR / Camera

|

Furniture Digital Twin

|

Backend Platform

```

---

# 24. Summary

iOS ilova oddiy katalog emas.

U:

> mijoz uyi va mebel ishlab chiqaruvchi o'rtasidagi raqamli ko'prik.

Professional AR orqali platformaning asosiy texnologik ustunligi yaratiladi.
