# API Specification

## 1. Overview

Furniture Platform barcha clientlar bilan API orqali ishlaydi:

* iOS Application;
* Web Dashboard;
* Customer Web;
* External integrations.

Asosiy standart:

```text
REST API

+

JSON

+

JWT Authentication
```

---

# 2. API Base Structure

Base URL:

```text
https://api.domain.com/api/v1/
```

---

Struktura:

```text
/api/v1/

├── auth

├── users

├── companies

├── products

├── assets

├── ar

├── orders

├── crm

├── erp

├── notifications

└── payments

```

---

# 3. API Response Standard

Barcha response bir xil formatda.

Success:

```json
{
"success": true,

"data": {}

}
```

---

Error:

```json
{
"success": false,

"error": {

"code":"ERROR_CODE",

"message":"Description"

}

}
```

---

# 4. Authentication API

## Register

Endpoint:

```http
POST /auth/register
```

---

Request:

```json
{
"phone":"+998901234567",

"password":"password",

"name":"Ali"
}
```

---

Response:

```json
{
"user_id":"uuid",

"token":"jwt"
}
```

---

# Login

```http
POST /auth/login
```

---

Request:

```json
{
"phone":"+998901234567",

"password":"password"
}
```

---

Response:

```json
{
"access_token":"",

"refresh_token":""
}
```

---

# 5. User API

## Current User

```http
GET /users/me
```

---

Response:

```json
{
"id":"uuid",

"name":"Ali",

"role":"CUSTOMER"
}
```

---

# 6. Company API

## Company List

```http
GET /companies
```

---

Filter:

```text
country

city

category

distance

```

---

## Company Detail

```http
GET /companies/{id}
```

---

Response:

```json
{
"name":"Modern Furniture",

"rating":4.8,

"products_count":120
}
```

---

# 7. Product API

## Product List

```http
GET /products
```

---

Query:

```text
category

price_min

price_max

company

location

```

---

## Product Detail

```http
GET /products/{id}
```

---

Response:

```json
{
"name":"Kitchen Set",

"price":15000000,

"model_url":""

}
```

---

# 8. Product Management API

Company owner uchun.

---

## Create Product

```http
POST /products
```

---

Request:

```json
{
"name":"Table",

"category_id":"uuid",

"price":5000000
}
```

---

## Update Product

```http
PUT /products/{id}
```

---

## Delete Product

```http
DELETE /products/{id}
```

---

# 9. 3D Asset API

## Upload Model

```http
POST /assets/upload
```

---

Request:

```text
multipart/form-data

file=model.usdz

product_id=uuid
```

---

Response:

```json
{
"asset_id":"uuid",

"status":"PROCESSING"
}
```

---

# Model Status

```http
GET /assets/{id}/status
```

---

Response:

```json
{
"status":"READY",

"url":"storage/model.usdz"
}
```

---

# 10. AR API

## Create AR Scene

```http
POST /ar/scenes
```

---

Request:

```json
{
"room_type":"kitchen",

"name":"My Kitchen"
}
```

---

Response:

```json
{
"scene_id":"uuid"
}
```

---

# Add Furniture To Scene

```http
POST /ar/scenes/{id}/objects
```

---

Request:

```json
{
"product_id":"uuid",

"position":{

"x":1,

"y":0,

"z":2

},

"rotation":90

}
```

---

# Get Scene

```http
GET /ar/scenes/{id}
```

---

# 11. Order API

## Create Order

```http
POST /orders
```

---

Request:

```json
{
"company_id":"uuid",

"items":[

{

"product_id":"uuid",

"quantity":1

}

]

}
```

---

Response:

```json
{
"order_id":"uuid",

"status":"NEW"
}
```

---

# Order Status

```http
GET /orders/{id}
```

---

Response:

```json
{
"status":"PRODUCTION",

"estimated_date":"2026-08-01"
}
```

---

# 12. Order Tracking API

Customer uchun.

```http
GET /orders/{id}/tracking
```

---

Natija:

```json
{
"current_stage":"Production",

"progress":60
}
```

---

# 13. CRM API

## Create Lead

```http
POST /crm/leads
```

---

Request:

```json
{
"name":"Customer",

"phone":"+99890",

"source":"AR_APP"
}
```

---

## Lead List

```http
GET /crm/leads
```

---

# 14. ERP API

## Production Tasks

```http
GET /erp/tasks
```

---

Response:

```json
[
{

"title":"Cut MDF",

"status":"WORKING"

}

]
```

---

## Materials

```http
GET /erp/materials
```

---

# 15. Employee API

## Employee Tasks

```http
GET /employees/tasks
```

---

## Complete Task

```http
PUT /employees/tasks/{id}
```

---

# 16. Notification API

## List

```http
GET /notifications
```

---

## Mark Read

```http
PUT /notifications/{id}/read
```

---

# 17. Payment API

## Create Payment

```http
POST /payments
```

---

Request:

```json
{
"order_id":"uuid",

"amount":1000000
}
```

---

# 18. Location API

## Nearby Companies

```http
GET /companies/nearby
```

---

Request:

```text
lat

lng

radius
```

---

Response:

```json
[
{
"name":"Furniture House",

"distance":"2.5km"
}
]
```

---

# 19. Search API

## Global Search

```http
GET /search
```

---

Search:

* products;
* companies;
* categories.

---

# 20. WebSocket API

Realtime:

```text
/ws/notifications/
```

---

Events:

```text
ORDER_UPDATED

MESSAGE_RECEIVED

PRODUCTION_CHANGED

```

---

# 21. API Security

Har request:

```text
Request

↓

JWT Validation

↓

Permission Check

↓

Business Rules

↓

Database

```

---

# 22. Rate Limiting

Public API:

```text
100 request/minute
```

---

Authenticated:

```text
1000 request/minute
```

---

# 23. API Documentation

Avtomatik:

```text
OpenAPI

Swagger UI
```

---

# 24. MVP API Scope

Birinchi versiya:

```text
/auth

/users

/companies

/products

/assets

/orders

/notifications

```

---

# 25. Future APIs

Qo'shiladi:

```text
AI

Analytics

Recommendation

External ERP

Marketplace Integration

```

---

# 26. Summary

API arxitektura:

* REST;
* JWT;
* versioned;
* mobile va web uchun yagona.

Asosiy maqsad:

> Barcha platforma komponentlarini yagona ishonchli aloqa qatlami orqali bog'lash.
