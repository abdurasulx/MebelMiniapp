# Backend Project Structure Specification

## 1. Overview

Furniture Platform backend katta ekotizim bo'lishi sababli oddiy CRUD loyihadan ko'ra modul arxitekturasi asosida quriladi.

Asosiy maqsad:

> MVP tez ishlab chiqilishi, keyinchalik esa ERP, Marketplace, AR va AI modullarini qo'shish oson bo'lishi.

---

# 2. Recommended Backend Stack

## Backend Framework

Asosiy variant:

* Django + Django REST Framework

Sabab:

* tez ishlab chiqish;
* kuchli admin panel;
* katta community;
* ERP uchun qulay.

---

Kelajakdagi servislar:

* FastAPI (AI servislar uchun);
* Celery (background tasks);
* WebSocket server.

---

# 3. High Level Architecture

```text id="f9x3mq"

                 Mobile App
                     |
                     |
                 REST API
                     |
                     |
              Django Backend
                     |
     --------------------------------
     |              |               |
 Users Module   Business Logic   Services
     |              |               |
 PostgreSQL     Redis          External APIs

```

---

# 4. Project Structure

Tavsiya:

```text id="k7m2px"
furniture_platform/

├── config/

│   ├── settings/

│   ├── urls.py

│   ├── celery.py


├── apps/

│

├── users/

├── companies/

├── products/

├── orders/

├── inventory/

├── production/

├── payments/

├── marketplace/

├── notifications/


├── services/

│   ├── ai/

│   ├── storage/

│   ├── payment/

│   ├── ar/


├── common/

├── media/

├── static/


├── requirements.txt

└── manage.py
```

---

# 5. Module Architecture

Har bir app mustaqil bo'ladi.

Misol:

```text id="m4v8qx"
products/

├── models.py

├── serializers.py

├── views.py

├── services.py

├── permissions.py

├── urls.py
```

---

# 6. Users Module

Vazifalar:

* authentication;
* profile;
* roles;
* permissions.

---

Funksiyalar:

* login;
* register;
* OTP;
* password recovery.

---

# 7. Companies Module

Mebel kompaniyalari.

Mas'uliyat:

* company profile;
* employees;
* permissions.

---

Misol:

```python
Company
    |
    |
CompanyMember
    |
    |
User
```

---

# 8. Products Module

Mahsulot boshqaruvi.

Vazifalar:

* katalog;
* kategoriya;
* rasm;
* 3D model.

---

API:

```text
GET /products

POST /products

PUT /products/{id}

DELETE /products/{id}
```

---

# 9. Orders Module

Buyurtmalar.

Mas'uliyat:

* order yaratish;
* status;
* history.

---

Flow:

```text id="n5x8mv"

Customer

↓

Order

↓

Company

↓

Production

↓

Delivery

```

---

# 10. Production Module

ERPning asosiy qismi.

Boshqaradi:

* ishlab chiqarish bosqichi;
* xodim;
* vaqt.

---

Misol:

```text id="q3m7xp"

Order

↓

Cutting

↓

Assembly

↓

Quality

↓

Ready

```

---

# 11. Inventory Module

Ombor.

Mas'uliyat:

* material;
* qoldiq;
* sarf.

---

# 12. Marketplace Module

Platforma savdo qismi.

Vazifalar:

* listing;
* search;
* ranking;
* featured products.

---

# 13. Notification Service

Barcha xabarlar.

Qo'llaydi:

* Push;
* Telegram;
* SMS;
* Email.

---

# 14. Service Layer

Muhim qism.

Biznes logika view ichida bo'lmaydi.

Misol:

Noto'g'ri:

```python
view():

create_order()

send_sms()

calculate_price()
```

---

To'g'ri:

```python
view():

order_service.create()
```

---

# 15. API Layer

Frontendlar uchun:

* iOS;
* Android;
* Web.

---

Struktura:

```text id="w6m9qp"

api/

├── v1/

│

├── users/

├── products/

├── orders/

```

---

# 16. Background Tasks

Celery ishlatiladi.

Misollar:

* email;
* SMS;
* 3D processing;
* AI calculation.

---

Flow:

```text id="r4m8vx"

Request

↓

Queue

↓

Worker

↓

Result

```

---

# 17. File Storage

Fayllar:

* rasmlar;
* 3D;
* video.

Saqlash:

* S3;
* MinIO.

---

# 18. Cache Layer

Redis:

Qo'llanish:

* session;
* cache;
* queue;
* real-time.

---

# 19. AI Service Integration

AI alohida servis bo'lishi mumkin.

```text id="x7m3qv"

Django

↓

FastAPI AI Service

↓

Model

↓

Prediction

```

---

# 20. Security Layer

Qo'llanadi:

* JWT;
* permissions;
* rate limit;
* audit.

---

# 21. Testing Structure

```text id="p8x5mv"

tests/

├── users

├── products

├── orders

├── payments

```

---

# 22. Deployment Structure

Boshlanish:

```text id="m3q8vx"

Nginx

↓

Gunicorn

↓

Django

↓

PostgreSQL

↓

Redis

```

---

# 23. Production Scaling

Keyinchalik:

```text id="q9m4xp"

Load Balancer

↓

Backend Servers

↓

Database Cluster

↓

Storage

```

---

# 24. Microservice Migration

Boshida kerak emas.

Keyinchalik ajratiladi:

* AI service;
* notification service;
* AR processing;
* analytics.

---

# 25. Development Rule

Muhim:

Har modul:

* mustaqil;
* test qilinadigan;
* kengayadigan

bo'lishi kerak.

---

# 26. Summary

Backend arxitektura:

MVP uchun tez.

Enterprise daraja uchun tayyor.

Asosiy tamoyil:

> Avval monolit modul tizim, keyin kerak bo'lsa mikroservis.

Bu yondashuv xarajatni kamaytiradi va rivojlanishni tezlashtiradi.
