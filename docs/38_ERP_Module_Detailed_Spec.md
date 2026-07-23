# ERP Module Detailed Specification

## 1. Overview

Furniture Platform ERP moduli tizimning asosiy biznes yadrosi hisoblanadi.

Maqsad:

> Mebel ishlab chiqaruvchining barcha ichki jarayonlarini raqamlashtirish va real foydani ko'rsatish.

ERP orqali kompaniya:

* buyurtmalarni;
* xom ashyoni;
* ishlab chiqarishni;
* xodimlarni;
* xarajatlarni;
* foydani

bitta tizimdan boshqaradi.

---

# 2. ERP Architecture

```text id="e7m2qx"

Customer Order

        |

        |

ERP System

        |

----------------------------

|            |             |

Production  Inventory   Finance

|            |             |

Employees   Materials   Profit

```

---

# 3. ERP Main Modules

ERP quyidagi bo'limlardan tashkil topadi:

1. Order Management
2. Production Management
3. Inventory Management
4. Material Management
5. Employee Management
6. Cost Calculation
7. Financial Analytics

---

# 4. Order Management

## Maqsad

Mijoz buyurtmasidan ishlab chiqarishgacha bo'lgan jarayonni boshqarish.

---

Buyurtma kelishi:

```text id="f8m3px"

Customer Request

↓

Measurement

↓

Design Approval

↓

Production

↓

Delivery

```

---

# 5. Order Status System

Statuslar:

```text id="p4m8vx"

New

↓

Confirmed

↓

Design Approved

↓

Production

↓

Quality Check

↓

Ready

↓

Delivered

```

---

# 6. Custom Furniture Configuration

Mebel ko'pincha standart emas.

Shuning uchun:

Buyurtma ichida:

* o'lcham;
* rang;
* material;
* aksessuar;
* konfiguratsiya

saqlanadi.

---

Misol:

```json id="x5m2qp"
{
"type":"Kitchen",

"width":"420cm",

"material":"MDF",

"color":"White",

"estimated_price":15000000
}
```

---

# 7. Production Management

Ishlab chiqarish bosqichlari.

---

Misol:

```text id="q8m4vx"

Cutting

↓

Edge Processing

↓

Assembly

↓

Painting

↓

Quality Control

```

---

# 8. Production Task System

Har bir ish vazifaga bo'linadi.

Misol:

```text id="m3x7pq"

Task:

Kitchen Cabinet Assembly

Employee:

Ali

Deadline:

15 July

Status:

In Progress

```

---

# 9. Employee Productivity

ERP hisoblaydi:

* bajarilgan ishlar;
* vaqt;
* samaradorlik.

---

Misol:

```text id="z5m8qx"

Employee:

Ali

Completed:

42 tasks

Average time:

3 hours

```

---

# 10. Material Management

Xom ashyo nazorati.

Misollar:

* MDF;
* DSP;
* furnitura;
* bo'yoq;
* shisha.

---

# 11. Inventory System

Ombor:

Ko'rsatadi:

```text id="v4m9px"

MDF:

120 sheets

Screws:

4500 pcs

Paint:

30 liters

```

---

# 12. Automatic Material Calculation

Buyurtma asosida:

Tizim hisoblaydi:

qancha material kerak.

---

Misol:

```text id="n7m2qx"

Kitchen 4m

Need:

MDF:

8 sheets

Handle:

12 pcs

```

---

# 13. Low Stock Warning

Avtomatik ogohlantirish:

```text id="w3m8qx"

Warning:

MDF stock below minimum.

Recommended:

Order 50 sheets.

```

---

# 14. Supplier Management

Yetkazib beruvchilar:

Saqlanadi:

* nomi;
* narxlar;
* tarix;
* yetkazish vaqti.

---

# 15. Cost Calculation

Eng muhim modul.

Hisoblaydi:

```text id="k6m2px"

Material Cost

+

Labor Cost

+

Transport

+

Other Expenses

=

Total Cost

```

---

# 16. Real Profit Calculation

Ko'p ustalar bilmaydigan joy.

ERP ko'rsatadi:

```text id="r8m3vx"

Selling Price:

20 000 000

Cost:

12 000 000

Profit:

8 000 000

Margin:

40%

```

---

# 17. Employee Management

Xodimlar:

* roli;
* ish vaqti;
* vazifalari;
* samaradorligi.

---

# 18. Attendance System

Kelajakda:

* mobil check-in;
* GPS;
* ish boshlash.

---

# 19. Quality Control

Har ishlab chiqarishdan keyin:

Tekshiriladi:

* o'lcham;
* sifat;
* nuqson.

---

Misol:

```text id="u8m5qx"

Quality:

Passed

Inspector:

Manager

```

---

# 20. Delivery Management

Buyurtma tugagach:

Yetkazish.

Nazorat:

* manzil;
* vaqt;
* xodim.

---

# 21. Customer Communication

ERP mijoz bilan bog'lanadi.

Misol:

```text id="a3m7px"

Your furniture:

Assembly stage completed.

Estimated delivery:

Friday.

```

---

# 22. Dashboard Analytics

Kompaniya ko'radi:

* bugungi buyurtma;
* foyda;
* xarajat;
* ishlab chiqarish holati.

---

# 23. AI Integration Point

Kelajakda AI:

* xarajat tahlili;
* talab prognozi;
* material tavsiyasi.

---

# 24. ERP + AR Integration

Eng kuchli kombinatsiya:

```text id="s7m2qx"

AR Design

↓

Configuration

↓

ERP Order

↓

Production

```

---

# 25. ERP MVP Scope

Birinchi versiya:

Kerak:

✅ Orders

✅ Products

✅ Materials

✅ Production Status

✅ Profit Calculation

---

Keyinchalik:

* supplier;
* AI;
* automation.

---

# 26. ERP Competitive Advantage

Oddiy marketplace:

faqat sotadi.

Oddiy ERP:

faqat ichki boshqaradi.

Furniture Platform:

```text id="h4m8vx"

Find Customer

↓

Sell

↓

Produce

↓

Track

↓

Analyze Profit

```

---

# 27. Final Vision

ERP moduli:

mebelchining kundalik ish tizimiga aylanadi.

Natija:

* kam xato;
* ko'p foyda;
* tez ishlab chiqarish;
* mijoz ishonchi.

---

# 28. Summary

ERP Furniture Platformning yuragi hisoblanadi.

AR mijozni olib keladi.

Marketplace savdo beradi.

ERP esa biznesni ushlab turadi.

Uchalasining birlashuvi platformaning asosiy kuchidir.
