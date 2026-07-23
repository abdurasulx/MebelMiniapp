# API Architecture and Integration Specification

## 1. Overview

Furniture Platform ko'p qismli ekotizim bo'ladi.

Tizim ichida:

* Web Admin;
* Mobile App;
* AR Engine;
* ERP;
* CRM;
* Marketplace;
* AI Services;
* Payment Systems

bir-biri bilan bog'lanadi.

Asosiy aloqa:

> REST API + WebSocket + Background Queue

---

# 2. API Architecture

Yuqori daraja:

```text id="a8m3qx"

Mobile App

      |

      |

API Gateway

      |

-----------------------------

|          |          |

User     Product    Order

Service  Service    Service

|

ERP / CRM / AI

```

---

# 3. API Principles

Asosiy qoidalar:

## Versioning

API versiyalar bilan ishlaydi.

Misol:

```
/api/v1/products
/api/v2/products
```

---

## Security First

Har request:

* authentication;
* permission;
* validation.

orqali o'tadi.

---

## Documentation

API:

* OpenAPI;
* Swagger.

bilan hujjatlashtiriladi.

---

# 4. Authentication API

## Register

Endpoint:

```
POST /api/v1/auth/register
```

---

Input:

```json
{
"phone":"+998901234567",

"password":"******"
}
```

---

Output:

```json
{
"user_id":123,

"token":"xxxxx"
}
```

---

# 5. Login API

```
POST /api/v1/auth/login
```

---

Natija:

* access token;
* refresh token.

---

# 6. User Profile API

```
GET /api/v1/profile
```

---

Qaytaradi:

* ism;
* rol;
* kompaniya;
* permissions.

---

# 7. Company API

## Create Company

```
POST /api/v1/companies
```

---

## Company Detail

```
GET /api/v1/companies/{id}
```

---

Ma'lumot:

* nom;
* joylashuv;
* rating;
* mahsulotlar.

---

# 8. Product API

Marketplace uchun.

---

## Product List

```
GET /api/v1/products
```

---

Filter:

```text
category

price

location

material

```

---

## Product Detail

```
GET /api/v1/products/{id}
```

---

Natija:

```json
{
"name":"Modern Kitchen",

"price":15000000,

"model_3d":"url"
}
```

---

# 9. 3D Model API

AR uchun.

---

## Download Model

```
GET /api/v1/models/{id}
```

---

Tekshiradi:

* user permission;
* subscription;
* access.

---

# 10. AR Scene API

## Create Scene

```
POST /api/v1/ar/scenes
```

---

Saqlaydi:

* xona;
* obyektlar;
* joylashuv.

---

Misol:

```json
{
"room":"kitchen",

"objects":[

{

"product_id":20,

"position":

"x:1,y:0,z:2"

}

]

}
```

---

# 11. AR Price Estimation API

AR konfiguratsiyadan narx hisoblash.

```
POST /api/v1/ar/estimate
```

---

Input:

* mahsulotlar;
* o'lcham;
* material.

---

Output:

```json
{
"estimated_price":25000000,

"confidence":0.85
}
```

---

# 12. Order API

## Create Order

```
POST /api/v1/orders
```

---

## Order Status

```
GET /api/v1/orders/{id}
```

---

Status:

```
NEW

PRODUCTION

QUALITY

DELIVERY

DONE

```

---

# 13. ERP API

Ichki boshqaruv uchun.

---

## Materials

```
GET /api/v1/erp/materials
```

---

## Production

```
GET /api/v1/erp/tasks
```

---

## Profit

```
GET /api/v1/erp/profit
```

---

# 14. CRM API

---

## Leads

```
GET /api/v1/crm/leads
```

---

## Create Lead

```
POST /api/v1/crm/leads
```

---

## Customer History

```
GET /api/v1/crm/customer/{id}
```

---

# 15. Notification API

Real-time xabarlar.

---

REST:

```
GET /api/v1/notifications
```

---

WebSocket:

```
/ws/notifications
```

---

Misol:

```text
Production finished.

Your furniture is ready.
```

---

# 16. Payment API

Integratsiya:

* bank;
* payment gateway.

---

Flow:

```text id="m7x2pq"

Create Payment

↓

Gateway

↓

Confirm

↓

Update Order

```

---

# 17. AI API

Kelajak modullari.

---

## Price Prediction

```
POST /api/v1/ai/price
```

---

## Design Recommendation

```
POST /api/v1/ai/design
```

---

## Demand Forecast

```
POST /api/v1/ai/forecast
```

---

# 18. Supplier API

Kelajak:

Material bozori.

---

Misol:

```
GET /api/v1/suppliers
```

---

# 19. External Integration

Platforma bog'lanishi mumkin:

* Instagram;
* Telegram;
* CRM tizimlari;
* accounting software.

---

# 20. Webhook System

Tashqi servislar uchun.

Misol:

Order yaratildi:

```json
{
"event":"order.created",

"order_id":500
}
```

---

# 21. API Rate Limiting

Himoya:

Misol:

```
1000 requests/minute
```

---

# 22. File Upload API

3D va rasm uchun.

Flow:

```
Upload

↓

Validation

↓

Processing

↓

Storage

↓

Available

```

---

# 23. API Monitoring

Kuzatiladi:

* response time;
* error;
* traffic.

---

# 24. Mobile Optimization

Mobil uchun:

* pagination;
* compression;
* caching.

---

# 25. Offline Sync

Xodimlar uchun.

Misol:

Internet yo'q:

* o'lchov saqlanadi.

Internet qaytganda:

* serverga yuboriladi.

---

# 26. API Future Architecture

Kelajak:

```text id="q8m4vx"

API Gateway

↓

Microservices

↓

Event Bus

↓

AI Platform

```

---

# 27. API MVP Scope

Birinchi versiya:

✅ Authentication

✅ Products

✅ Orders

✅ Company

✅ AR Models

✅ Notifications

---

# 28. Final Vision

API butun ekotizimning bog'lovchi qatlami.

U orqali:

* mijoz;
* mebelchi;
* xodim;
* AI;
* tashqi servislar

bitta tizimda ishlaydi.

---

# 29. Summary

Furniture Platform API:

oddiy CRUD API emas.

Bu:

> kelajakdagi mebel sanoati ekotizimining kommunikatsiya qatlami.
