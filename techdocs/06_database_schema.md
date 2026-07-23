# Database Schema Specification

## 1. Overview

Furniture Platform uchun asosiy database:

```text id="a8m3qx"
PostgreSQL
```

Database dizayni quyidagi talablar asosida quriladi:

* multi-tenant architecture;
* kompaniyalar izolyatsiyasi;
* katta katalog;
* AR asset boshqaruvi;
* ERP va CRM ma'lumotlari;
* kelajakdagi AI analizlar.

---

# 2. Database Principles

## 2.1 Data Isolation

Har kompaniya o'z ma'lumotlariga ega.

Model:

```text id="m7p2qx"

Platform

    |

Companies

    |

Employees

    |

Products / Orders / CRM

```

---

## 2.2 UUID Primary Keys

Asosiy ID:

```text id="q5m8qx"
UUID
```

Sabab:

* xavfsizlik;
* distributed system uchun tayyorlik.

---

## 2.3 Soft Delete

Muhim ma'lumotlar o'chirilmaydi.

Misol:

```text id="w8m3qx"

deleted_at

```

orqali yashiriladi.

---

# 3. Main Database Modules

```text id="r6m2qx"

users

companies

products

assets

orders

crm

erp

notifications

payments

locations

```

---

# 4. User Schema

## users_user

Foydalanuvchilar.

Fields:

```text id="x3m7pq"

id UUID PK

phone

email

password_hash

first_name

last_name

role

is_active

created_at

updated_at

```

---

# 5. User Roles

```text id="y7m4qx"

SUPER_ADMIN

COUNTRY_ADMIN

COMPANY_OWNER

EMPLOYEE

CUSTOMER

```

---

# 6. Company Schema

## companies_company

Mebel kompaniyalari.

Fields:

```text id="z8m3qx"

id UUID

name

description

phone

email

country

city

address

latitude

longitude

status

created_at

```

---

# 7. Company Employee

## companies_employee

Bog'lanish:

```text id="a9m4qx"

Company

    |

Employees

```

Fields:

```text id UUID

company_id FK

user_id FK

position

permissions

joined_at

```

---

# 8. Product Category

## products_category

Misol:

* oshxona;
* stol;
* stul;
* shkaf.

Fields:

```text id="b5m8qx"

id

name

parent_id

image

```

---

# 9. Product Schema

## products_product

Asosiy mahsulot.

Fields:

```text id="c6m3qx"

id UUID

company_id FK

category_id FK

name

description

price

currency

status

created_at

```

---

# 10. Product Variant

## products_variant

Variantlar:

* rang;
* material;
* o'lcham.

Fields:

```text id="d7m8qx"

product_id FK

color

material

width

height

depth

extra_price

```

---

# 11. 3D Asset Schema

## assets_model

3D modellar.

Fields:

```text id="e8m3qx"

id UUID

product_id FK

file_url

format

status

version

created_at

```

---

Status:

```text id="f9m4qx"

UPLOADED

PROCESSING

READY

FAILED

```

---

# 12. Asset Version

## assets_version

Model tarixlari.

Fields:

```text id

asset_id FK

version_number

file_url

created_at

```

---

# 13. AR Scene Schema

## ar_scene

Mijoz dizaynlari.

Fields:

```text id="g5m8qx"

id UUID

user_id FK

company_id FK

name

room_type

created_at

```

---

# 14. AR Object Placement

## ar_scene_object

Scene ichidagi obyektlar.

Fields:

```text id="h6m3qx"

scene_id FK

product_id FK

position_x

position_y

position_z

rotation

scale

```

---

# 15. Order Schema

## orders_order

Buyurtmalar.

Fields:

```text id="i7m3qx"

id UUID

customer_id FK

company_id FK

status

total_price

created_at

```

---

# 16. Order Item

## orders_item

Buyurtma tarkibi.

Fields:

```text id="j8m3qx"

order_id FK

product_id FK

quantity

price

```

---

# 17. Order Status

```text id="k9m5qx"

NEW

CONFIRMED

PRODUCTION

QUALITY_CHECK

DELIVERY

COMPLETED

CANCELLED

```

---

# 18. CRM Customer

## crm_customer

Mijoz tarixi.

Fields:

```text id="l8m4qx"

company_id FK

user_id FK

source

notes

created_at

```

---

# 19. CRM Lead

## crm_lead

Potensial mijoz.

Fields:

```text id="m9m5qx"

company_id FK

name

phone

status

estimated_value

```

---

# 20. ERP Production Task

## erp_task

Ishlab chiqarish vazifalari.

Fields:

```text id="n8m3qx"

company_id FK

order_id FK

employee_id FK

title

status

deadline

```

---

# 21. Material Inventory

## erp_material

Materiallar.

Fields:

```text id="o7m2qx"

company_id FK

name

quantity

unit

price

```

---

# 22. Location Schema

## locations_region

Hududlar.

Fields:

```text id="p6m3qx"

country

city

name

```

---

# 23. Company Service Area

Kompaniya ishlaydigan hudud.

## company_location

Fields:

```text id="q7m4qx"

company_id FK

region_id FK

radius

```

---

# 24. Notification Schema

## notifications_notification

Fields:

```text id="r8m3qx"

user_id FK

title

message

type

is_read

created_at

```

---

# 25. Payment Schema

## payments_transaction

Fields:

```text id="s9m4qx"

order_id FK

amount

currency

status

provider

created_at

```

---

# 26. Audit Log

## system_audit_log

Muhim harakatlar.

Fields:

```text id="t8m3qx"

user_id

action

object_type

object_id

created_at

```

---

# 27. Important Indexes

Kerak:

## Products

```text id="u7m2qx"

company_id

category_id

price

```

---

## Location

```text id="v6m3qx"

latitude

longitude

```

---

## Orders

```text id="w5m8qx"

company_id

status

created_at

```

---

# 28. Database Extensions

Qo'shiladi:

## PostGIS

Geo qidiruv uchun.

Misol:

"5 km ichidagi ustalar".

---

# 29. Migration Strategy

Har o'zgarish:

Django migration orqali.

```bash id="x4m9qx"

python manage.py makemigrations

python manage.py migrate

```

---

# 30. MVP Database Scope

Birinchi versiya:

```text id="y3m8qx"

users

companies

products

assets

orders

notifications

```

---

# 31. Future Database Expansion

Keyinchalik:

```text id="z2m7qx"

AI Analytics

Recommendation Data

Digital Twin Data

IoT Data

```

---

# 32. Summary

Database dizayni:

* scalable;
* multi-tenant;
* AR ready;
* ERP/CRM ready.

Asosiy maqsad:

> Mebel sanoatining barcha raqamli jarayonlarini yagona ma'lumotlar tizimida boshqarish.

