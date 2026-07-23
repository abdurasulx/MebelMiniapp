# Database Architecture Specification

## 1. Overview

Furniture Platform katta ekotizim bo'lgani uchun database oddiy katalog emas.

U quyidagi tizimlarni qo'llab-quvvatlashi kerak:

* Marketplace;
* ERP;
* CRM;
* AR;
* Subscription;
* Analytics;
* AI.

Asosiy database:

> PostgreSQL

---

# 2. Database Design Principles

Asosiy tamoyillar:

## Scalability

Kelajakda:

* millionlab mahsulot;
* millionlab foydalanuvchi.

uchun tayyor bo'lishi kerak.

---

## Data Separation

Har kompaniya ma'lumoti ajratiladi.

---

## Auditability

Muhim o'zgarishlar tarixda saqlanadi.

---

# 3. High Level Database Structure

```text id="a7m3qx"

Users

 |

Companies

 |

--------------------------------

|              |               |

Products      Orders          ERP

 |

3D Models

 |

AR Scenes

```

---

# 4. User Management

## users

Foydalanuvchilar.

Fields:

```text id="m8x2pq"

id

name

phone

email

password_hash

role

created_at

```

---

Role:

* customer;
* employee;
* manager;
* owner;
* admin.

---

# 5. Company Model

## companies

Mebel kompaniyalari.

Fields:

```text id="q5m8vx"

id

name

owner_id

country

city

address

verified

rating

created_at

```

---

# 6. Company Members

## company_users

Bog'lanish:

User ↔ Company

---

Fields:

```text id="p9m3qx"

company_id

user_id

role

permission

```

---

# 7. Product Catalog

## products

Mahsulotlar.

Fields:

```text id="w4m8qx"

id

company_id

name

category_id

description

price

status

created_at

```

---

# 8. Product Categories

## categories

Misol:

* oshxona;
* yotoqxona;
* stol;
* stul.

---

Fields:

```text id="x3m7pq"

id

name

parent_id

```

---

# 9. Product Configuration

Custom mebel uchun.

## product_options

Saqlaydi:

* rang;
* material;
* o'lcham.

---

Misol:

```text id="v8m2qx"

Product:

Kitchen

Options:

Color

Size

Material

```

---

# 10. 3D Model Storage

## product_models_3d

AR uchun.

Fields:

```text id="n5m3qx"

id

product_id

file_url

format

size

version

```

---

Format:

* USDZ;
* GLB;
* OBJ.

---

# 11. AR Scene Database

## ar_scenes

Saqlaydi:

mijoz yaratgan dizayn.

---

Fields:

```text id="z7m4px"

id

user_id

room_type

scene_data

created_at

```

---

# 12. AR Objects

## ar_scene_objects

Bitta xonadagi obyektlar.

---

Fields:

```text id="r6m2qx"

scene_id

product_id

position

rotation

scale

```

---

Misol:

```json id="k4m8vx"
{
"x":1.2,

"y":0,

"z":3.5
}
```

---

# 13. Customer CRM Tables

## customers_profile

Qo'shimcha ma'lumot:

```text id="m9x3qp"

user_id

address

preferences

budget

```

---

# 14. Leads

## crm_leads

Yangi mijozlar.

Fields:

```text id="q8m5vx"

id

company_id

customer_id

source

status

created_at

```

---

# 15. Orders

## orders

Buyurtmalar.

Fields:

```text id="p4m7qx"

id

customer_id

company_id

status

total_price

created_at

```

---

# 16. Order Items

## order_items

Buyurtmadagi mahsulotlar.

---

Fields:

```text id="x6m2pq"

order_id

product_id

quantity

configuration

price

```

---

# 17. Production Management

## production_tasks

Ish bosqichlari.

Fields:

```text id="w7m3qx"

order_id

task_name

employee_id

status

deadline

```

---

# 18. Material Database

## materials

Xom ashyo.

Misollar:

* MDF;
* DSP;
* furnitura.

---

Fields:

```text id="a9m5qx"

company_id

name

unit

cost

stock

```

---

# 19. Material Usage

## material_usage

Buyurtmada ishlatilgan material.

---

Fields:

```text id="m3x8pq"

order_id

material_id

amount

cost

```

---

# 20. Employee Management

## employees

Fields:

```text id="q7m2vx"

company_id

user_id

position

salary

```

---

# 21. Finance Tables

## transactions

Moliyaviy harakatlar.

---

Fields:

```text id="v5m8qx"

company_id

type

amount

date

```

---

# 22. Subscription System

## subscriptions

Kompaniya paketi.

---

Fields:

```text id="s8m4qx"

company_id

plan

status

start_date

end_date

```

---

# 23. Payment History

## payments

Fields:

```text id="h6m3px"

user_id

amount

method

status

created_at

```

---

# 24. Notification System

## notifications

Xabarlar.

---

Fields:

```text id="c5m9qx"

user_id

title

message

read

created_at

```

---

# 25. Review System

## reviews

Marketplace ishonchi.

Fields:

```text id="d8m2qx"

customer_id

company_id

rating

comment

```

---

# 26. Analytics Tables

## events

Foydalanuvchi harakatlari.

---

Misol:

* product_view;
* ar_open;
* order_create.

---

# 27. AI Data Layer

Kelajak uchun:

## ai_features

Saqlaydi:

* model input;
* prediction;
* result.

---

# 28. Database Indexing

Muhim indexlar:

* product search;
* company location;
* order status;
* customer phone.

---

# 29. Multi Country Support

Har jadvalda kerak bo'lishi mumkin:

```text
country_id

currency

language

```

---

# 30. Database Security

Talablar:

* encrypted backup;
* access control;
* audit log.

---

# 31. Migration Strategy

Bosqichma-bosqich:

## MVP

Bitta database.

---

## Growth

Database optimization.

---

## Scale

Service bo'yicha ajratish.

---

# 32. Future Microservice Split

Kelajak:

```text id="z5m8qx"

User Service

Product Service

Order Service

Payment Service

AI Service

```

---

# 33. Final Architecture Vision

Database:

platformaning barcha bilimlarini saqlovchi markaz.

U orqali:

* biznes;
* mijoz;
* mahsulot;
* AI

birlashtiriladi.

---

# 34. Summary

To'g'ri database arxitekturasi:

* tez ishlash;
* xavfsizlik;
* kengayish;
* AI rivoji

uchun asos bo'ladi.

Furniture Platform database oddiy CRUD emas.

Bu:

> kelajakdagi mebel sanoati ma'lumot markazi.
