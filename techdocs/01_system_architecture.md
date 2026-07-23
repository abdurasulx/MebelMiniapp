# Mobile Application Architecture (Updated)

## 4.1 Client Layer

Furniture Platform foydalanuvchi turiga qarab turli mobil tajriba beradi.

Platformada ikki xil mobil yo'nalish mavjud:

1. Customer Application
2. Employee Professional Application

---

# Customer Application

## Maqsad

Oddiy foydalanuvchiga:

* mebel qidirish;
* mahsulot ko'rish;
* AR orqali sinash;
* buyurtma berish

imkoniyatini berish.

---

## Platform Support

### iOS

To'liq AR tajriba.

Qo'llab-quvvatlaydi:

* ARKit;
* LiDAR qurilmalar;
* xona aniqlash;
* aniq joylashtirish;
* professional preview.

---

### Android

Marketplace va yengil AR tajriba.

Qo'llab-quvvatlaydi:

* mahsulot katalogi;
* narx ko'rish;
* buyurtma;
* oddiy kamera AR.

---

## Android Limitations

Android qurilmalari juda ko'p bo'lgani uchun:

* sensorlar farq qiladi;
* kamera sifati farq qiladi;
* depth sensing imkoniyati bir xil emas.

Shuning uchun professional:

* xona o'lchash;
* devor aniqlash;
* murakkab joylashtirish

funksiyalari faqat qo'llab-quvvatlangan iOS qurilmalarida ishlaydi.

---

# Employee Professional Application

## Maqsad

Mebel kompaniyasi xodimlari uchun professional sotuv va o'lchash vositasi.

---

## Platform

```text
iOS / iPadOS
+
LiDAR supported devices
```

---

## Sabab

Professional xizmat uchun kerak:

* yuqori aniqlik;
* stabil AR;
* standart sensor muhiti.

---

## Employee Features

Xodim qila oladi:

* mijoz uyiga tashrif;
* xona skanerlash;
* devorlarni aniqlash;
* bo'sh joyni o'lchash;
* mebel joylashtirish;
* AR loyiha yaratish;
* mijozga taklif yuborish.

---

# AR Capability Levels

## Level 1 — Basic AR

Customer Android/iOS:

* mahsulotni xonaga qo'yish;
* rang va ko'rinishni tekshirish.

---

## Level 2 — Advanced AR

Customer iOS:

* yaxshiroq tracking;
* xona tushunchasi;
* aniqroq joylashtirish.

---

## Level 3 — Professional AR

Employee iPad/iPhone Pro:

* LiDAR scan;
* room mesh;
* o'lchash;
* dizayn tayyorlash;
* ERP buyurtmasiga ulash.

---

# Architecture Decision

Furniture Platform uchun asosiy AR strategiya:

```text
Professional Quality

        ↓

iOS LiDAR

        ↓

Employee Tool

        ↓

Premium Customer Experience
```

---

# Business Reason

Platform oddiy AR katalog bo'lishni maqsad qilmaydi.

Asosiy qiymat:

> Mebelchi xodimi mijoz uyiga borib, real o'lcham va joylashuv asosida ishonchli dizayn yaratishi.

Shuning uchun professional AR uchun iOS asosiy platforma sifatida tanlanadi.

---

# Updated Mobile Architecture

```text
Customer

├── iOS App
│
│   ├── Full AR
│   ├── Room Preview
│   └── Ordering
│
└── Android App
    ├── Marketplace
    ├── Product View
    └── Basic AR


Employee

└── iOS/iPadOS App
    ├── LiDAR Scan
    ├── Measurement
    ├── Professional AR
    └── CRM Integration
```
