# Backend Architecture Specification

## 1. Overview

Furniture Platform backend tizimning asosiy biznes mantiq qatlami hisoblanadi.

Backend quyidagi vazifalarni bajaradi:

* foydalanuvchilarni boshqarish;
* kompaniyalarni boshqarish;
* mahsulot katalogi;
* buyurtmalar;
* CRM;
* ERP;
* AR asset boshqaruvi;
* AI servislar bilan aloqa.

---

# 2. Backend Architecture Style

Birinchi versiya:

```text id="a8m3qx"
Modular Monolith Architecture
```

---

Sabab:

* tez ishlab chiqish;
* kam xarajat;
* bitta jamoa bilan boshqarish;
* kelajakda microservicega o'tish imkoniyati.

---

# 3. Backend Stack

## Language

```text id="m7p2qx"
Python 3.12+
```

---

## Framework

```text id="q5m8vx"
Django

+

Django REST Framework
```

---

## Database

```text id="w8m3qx"
PostgreSQL
```

---

## Async

```text id="r6m2qx"
Celery

+

Redis
```

---

# 4. Project Structure

Asosiy struktura:

```text id="x3m7pq"

backend/

├── config/

│   ├── settings/

│   ├── urls.py

│   └── celery.py


├── apps/

│

├── users/

├── companies/

├── products/

├── assets/

├── orders/

├── crm/

├── erp/

├── inventory/

├── notifications/

└── payments/


├── common/

├── services/

├── permissions/

└── utils/

```

---

# 5. Django Apps Responsibility

## users

Foydalanuvchilar.

Mas'uliyat:

* registration;
* authentication;
* profile;
* roles.

---

## companies

Mebel kompaniyalari.

Mas'uliyat:

* company profile;
* branches;
* employees;
* subscription.

---

## products

Mahsulot katalogi.

Mas'uliyat:

* categories;
* products;
* variants;
* prices;
* availability.

---

## assets

3D va media boshqaruvi.

Mas'uliyat:

* upload;
* processing;
* versions;
* access.

---

## orders

Buyurtmalar.

Mas'uliyat:

* cart;
* order;
* status;
* production flow.

---

## crm

Mijoz bilan ishlash.

Mas'uliyat:

* leads;
* customers;
* communication history.

---

## erp

Ishlab chiqarish.

Mas'uliyat:

* tasks;
* materials;
* production stages.

---

# 6. Layered Architecture

Har app ichida:

```text id="y7m4qx"

app/

├── models.py

├── serializers.py

├── views.py

├── urls.py

├── services.py

├── selectors.py

├── permissions.py

└── tasks.py

```

---

# 7. Model Layer

Faqat:

* database structure;
* relations;
* constraints.

uchun ishlatiladi.

---

Misol:

```python id="u8m3qx"
class Product(models.Model):

    company = models.ForeignKey(
        Company,
        on_delete=models.CASCADE
    )

    name = models.CharField(
        max_length=255
    )

    price = models.DecimalField(
        max_digits=12,
        decimal_places=2
    )
```

---

# 8. Service Layer

Biznes logika shu yerda bo'ladi.

Misol:

```text id="v9m4qx"

OrderService

↓

check product

↓

calculate price

↓

create order

```

---

Nima uchun:

Views ichida katta logika bo'lmasligi kerak.

---

# 9. API Layer

DRF orqali.

Mas'uliyat:

* request qabul qilish;
* validation;
* response.

---

Misol:

```text id="w5m8qx"

POST /api/v1/orders/

```

---

# 10. Selector Layer

Murakkab querylar uchun.

Misol:

```text id="x6m3qx"

ProductSelector

↓

available products

↓

nearby companies

```

---

Foyda:

* querylarni markazlashtirish;
* optimizatsiya.

---

# 11. Permission Architecture

Rol asosida.

Rollar:

```text id="z7m2qx"

SUPER_ADMIN

COUNTRY_ADMIN

COMPANY_OWNER

EMPLOYEE

CUSTOMER

```

---

Misol:

Company Owner:

* o'z kompaniyasini ko'radi.

Customer:

* faqat ochiq katalogni ko'radi.

---

# 12. Multi Tenant Logic

Muhim arxitektura.

Har request:

```text id="a9m4qx"

User

↓

Company Context

↓

Allowed Data

```

---

Misol:

Mebelchi A:

ko'radi:

```
Company A products
```

Ko'rmaydi:

```
Company B products
```

---

# 13. API Versioning

Struktura:

```text id="b5m8qx"

api/

└── v1/

    ├── users

    ├── products

    └── orders

```

---

Kelajak:

```text id="c6m3qx"

api/v2/

```

---

# 14. Background Tasks

Celery ishlari:

## 3D Processing

```text id="d7m2qx"

Upload

↓

Celery Task

↓

Convert Model

↓

Update Status

```

---

## Notifications

* SMS;
* Push;
* Email.

---

# 15. Event System

Kelajak uchun.

Misol:

Order yaratildi:

```text id="e8m3qx"

OrderCreated Event

↓

CRM Update

↓

Notification

↓

Analytics

```

---

# 16. Error Handling

Standart format:

```json id="f9m4qx"
{
"error":

{

"code":"INVALID_ORDER",

"message":"Order cannot be created"

}

}
```

---

# 17. Logging

Har muhim harakat yoziladi.

Misol:

```text id="g5m8qx"

User 100 created Order 500

```

---

# 18. Testing Structure

Har modul:

```text id="h6m3qx"

tests/

├── unit/

├── integration/

└── api/

```

---

# 19. Security Rules

Backend:

hech qachon:

* frontendga ishonmaydi;
* permissionni clientda tekshirmaydi.

---

Har request:

server tomonidan tekshiriladi.

---

# 20. MVP Backend Priority

Birinchi ishlab chiqiladi:

```text id="i7m3qx"

users

↓

companies

↓

products

↓

assets

↓

orders

↓

notifications

```

---

# 21. Future Backend Expansion

Ajratilishi mumkin:

```text id="j8m4qx"

Auth Service

Product Service

Order Service

AI Service

Asset Service

Payment Service

```

---

# 22. Final Backend Goal

Backend:

oddiy API emas.

U:

```text id="k9m5qx"

Furniture Business Operating Core

```

bo'ladi.

---

# 23. Summary

Backend qarorlari:

✅ Modular Monolith

✅ Django REST Framework

✅ Service Layer

✅ PostgreSQL

✅ Redis/Celery

✅ API First

✅ Multi Tenant Ready

Bu struktura MVPni tez chiqarish va kelajakda global platformaga aylantirish uchun tayyor.
