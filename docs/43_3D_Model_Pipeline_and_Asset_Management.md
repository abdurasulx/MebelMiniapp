# 3D Model Pipeline and Asset Management Specification

## 1. Overview

Furniture Platformning asosiy texnologik aktivlaridan biri — 3D model tizimi.

AR tajriba sifati to'g'ridan-to'g'ri:

* model sifati;
* optimizatsiya;
* materiallar;
* o'lcham aniqligi

ga bog'liq.

Maqsad:

> Har bir mebel mahsulotini real hayotdagi o'lcham va ko'rinishiga maksimal yaqin raqamli obyektga aylantirish.

---

# 2. 3D Asset Lifecycle

To'liq jarayon:

```text id="a8m3qx"

Furniture Product

↓

3D Creation

↓

Validation

↓

Optimization

↓

AR Conversion

↓

Publishing

↓

Update Management

```

---

# 3. 3D Model Sources

Model uch xil usulda kelishi mumkin.

---

## Method 1 — Manufacturer Upload

Mebelchi o'z modelini yuklaydi.

Formatlar:

* Blender;
* CAD;
* OBJ;
* FBX.

---

## Method 2 — Platform Creation

Agar model bo'lmasa:

Platforma tayyorlaydi.

Xizmat:

* 3D modeling;
* texture;
* AR preparation.

---

## Method 3 — Scanner Based Creation

Kelajak:

Telefon yoki professional scanner orqali.

---

# 4. Supported Formats

Ichki formatlar:

## Master Format

Saqlash uchun:

* FBX;
* BLEND;
* OBJ.

---

## AR Format

iOS:

* USDZ.

Cross platform:

* GLB / glTF.

---

# 5. 3D Upload Flow

```text id="m7x2pq"

Company Upload

↓

File Check

↓

Virus Scan

↓

Format Validation

↓

Optimization Queue

↓

Published

```

---

# 6. Model Validation

Tizim tekshiradi:

## Geometry

* polygon soni;
* xatolar;
* yopiq mesh.

---

## Scale

Muhim:

Model real o'lchamda bo'lishi kerak.

Misol:

Real:

200 cm shkaf.

Model:

200 cm.

---

# 7. Automatic Optimization

Muammo:

3D model juda katta bo'lishi mumkin.

---

Yechim:

Optimization pipeline:

```text id="q5m8vx"

High Poly

↓

Reduce Polygon

↓

Compress Texture

↓

Generate LOD

↓

AR Ready

```

---

# 8. Level of Detail System (LOD)

Turli masofa uchun:

## LOD 0

Yuqori sifat.

Yaqindan ko'rish.

---

## LOD 1

O'rta sifat.

---

## LOD 2

Uzoq masofa.

---

# 9. Texture Management

Materiallar:

* yog'och;
* MDF;
* metall;
* mato.

---

Saqlanadi:

* texture;
* roughness;
* normal map.

---

# 10. Real Material System

Har mahsulot:

metadata bilan keladi.

Misol:

```json id="w8m3qx"
{

"material":"MDF",

"color":"white",

"finish":"matte"

}

```

---

# 11. Product Variants

Bitta model ichida:

Variantlar:

* rang;
* tutqich;
* oyoq;
* material.

---

Misol:

```text id="x3m7pq"

Kitchen Model

|

├ White

├ Black

└ Wood

```

---

# 12. AR Placement Metadata

Har modelga:

joylashuv qoidasi biriktiriladi.

---

Misol:

```json id="v9m2qx"
{

"placement":"floor",

"rotation":true,

"wall_mount":false

}

```

---

# 13. Furniture Measurement Data

Saqlanadi:

* width;
* height;
* depth.

---

Misol:

```json id="n5m8qx"
{

"width":2400,

"height":800,

"depth":600

}

```

Birlik:

millimeter.

---

# 14. AR Collision Data

Mebel atrofidagi zona.

Kerak:

* to'qnashuv;
* joy tekshirish.

---

Misol:

Divan:

```text id="r6m3qx"

Width:

220cm

Required space:

300cm

```

---

# 15. Asset Storage Architecture

Saqlash:

```text id="p8m4vx"

Object Storage

|

├ Original Model

├ Optimized Model

├ Textures

├ Preview Images

└ Metadata

```

---

# 16. CDN Delivery

AR model tez yuklanishi uchun:

CDN ishlatiladi.

---

Natija:

* tez ochilish;
* kam server yuklama.

---

# 17. Version Management

Model o'zgarsa:

eski versiya saqlanadi.

---

Misol:

```text id="z7m2qx"

Kitchen v1

↓

Kitchen v2

↓

Kitchen v3

```

---

# 18. Model Approval Workflow

Mebelchi yuklagandan keyin:

```text id="s5m8qx"

Uploaded

↓

Checking

↓

Approved

↓

Published

```

---

# 19. Quality Score

Har modelga baho.

Misol:

```text id="k4m8qx"

AR Quality:

95%

Texture:

90%

Scale:

100%

```

---

# 20. AI Assisted 3D Processing

Kelajak:

AI yordam beradi:

* texture yaratish;
* model tozalash;
* avtomatik optimizatsiya.

---

# 21. 3D Search Engine

Kelajak:

Qidirish:

* shakl;
* rang;
* stil.

---

Misol:

"Minimalist oq stol"

AI topadi.

---

# 22. 3D Marketplace Protection

Muhim.

Model o'g'irlanishini oldini olish:

* encrypted delivery;
* watermark;
* token access.

---

# 23. Analytics

Kuzatiladi:

* nechta ko'rildi;
* AR ishlatildi;
* sotuvga ta'siri.

---

# 24. 3D MVP Scope

Birinchi versiya:

✅ Upload

✅ Storage

✅ USDZ conversion

✅ AR preview

✅ Product linking

---

Keyingi:

* AI generation;
* scanning;
* automatic optimization.

---

# 25. Business Value

3D pipeline beradi:

Mebelchiga:

* premium ko'rinish;
* ko'proq sotuv;
* ishonch.

Platformaga:

* kuchli asset bazasi;
* raqobat ustunligi.

---

# 26. Long Term Vision

Kelajakda:

Har bir mebel:

```text id="h7m3qx"

Physical Product

=

Digital Twin

```

bo'ladi.

---

# 27. Summary

3D Model Pipeline Furniture Platformning AR yuragi hisoblanadi.

Sifatli 3D tizim:

* mijoz tajribasini;
* sotuvni;
* marketplace qiymatini

oshiradi.

Asosiy maqsad:

> Har bir mebelni internetdagi oddiy rasm emas, raqamli egizak sifatida yaratish.
