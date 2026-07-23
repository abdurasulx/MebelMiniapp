# Technology Stack Specification

## 1. Overview

Furniture Platform texnologik steki quyidagi prinsip asosida tanlanadi:

* tez MVP chiqarish;
* kichik jamoa bilan boshqarish;
* kelajakda katta masshtabga chiqish;
* AR va AI texnologiyalarini qo'llab-quvvatlash.

Asosiy arxitektura:

```text id="a8m3qx"

Backend

+

Web Dashboard

+

iOS AR Application

+

AI Services

+

Cloud Infrastructure

```

---

# 2. Backend Technology

## Primary Language

```text id="m7x2pq"
Python 3.12+
```

Sabab:

* tez ishlab chiqish;
* AI ekotizimi bilan mos;
* katta community.

---

# 3. Backend Framework

## Django + Django REST Framework

Tanlov:

```text id="q5m8vx"
Django

+

Django REST Framework
```

---

Sabab:

* kuchli ORM;
* admin panel;
* authentication;
* tez CRUD;
* katta loyihalar uchun mos.

---

Ishlatiladi:

* API;
* ERP;
* CRM;
* Marketplace logic.

---

# 4. Async Processing

Og'ir vazifalar uchun:

```text id="p9m3qx"
Celery

+

Redis
```

---

Vazifalar:

* 3D conversion;
* notification;
* AI processing;
* background calculation.

---

# 5. Database

## Primary Database

```text id="w4m8qx"
PostgreSQL
```

---

Sabab:

* katta ma'lumot;
* relationlar;
* JSONB support;
* geo extension.

---

Qo'shimcha:

## PostGIS

Joylashuv uchun.

Ishlatiladi:

* kompaniya lokatsiyasi;
* yetkazib berish hududi;
* yaqin ustalarni topish.

---

# 6. Cache and Queue

## Redis

Ishlatiladi:

* cache;
* session;
* queue broker;
* realtime data.

---

# 7. File Storage

## Object Storage

Tanlov:

```text id="x3m7pq"
S3 Compatible Storage
```

Misollar:

* AWS S3;
* MinIO;
* Cloudflare R2.

---

Saqlanadi:

* 3D model;
* texture;
* rasm;
* video;
* hujjat.

---

# 8. Backend API Style

Asosiy:

```text id="v8m2qx"
REST API
```

---

Kelajak:

Qo'shilishi mumkin:

* GraphQL;
* WebSocket.

---

# 9. Realtime Communication

Ishlatiladi:

```text id="n5m3qx"
WebSocket
```

---

Kerak:

* order status;
* notification;
* production update.

---

# 10. Web Dashboard

## Frontend

Tanlov:

```text id="r6m2qx"
React

+

TypeScript
```

---

Sabab:

* katta dashboardlar uchun qulay;
* component architecture;
* kuchli ecosystem.

---

UI:

```text id="s7m4qx"
Tailwind CSS
```

---

Ishlatiladi:

* ERP panel;
* CRM;
* admin.

---

# 11. iOS Application

## Language

```text id="k4m8qx"
Swift
```

---

## Framework

```text id="h7m3qx"
SwiftUI

+

UIKit (kerak bo'lsa)
```

---

Sabab:

* Apple ekotizimi;
* yuqori performance;
* zamonaviy UI.

---

# 12. AR Technology

## Primary Framework

```text id="z8m2qx"
ARKit
```

---

Qo'shimcha:

```text id="c5m9qx"
RealityKit
```

---

Vazifalar:

* plane detection;
* object placement;
* LiDAR scan;
* room understanding.

---

# 13. 3D Asset Format

Asosiy formatlar:

## Storage

* FBX;
* BLEND;
* OBJ.

---

## Runtime

iOS:

```text id="d6m3qx"
USDZ
```

---

Cross platform:

```text id="e8m5qx"
GLB / glTF
```

---

# 14. AI Technology

Boshlanish:

```text id="f7m2qx"
Python AI Stack
```

---

Kutubxonalar:

* PyTorch;
* scikit-learn;
* OpenCV.

---

Qo'llanilishi:

* recommendation;
* prediction;
* image processing.

---

# 15. Computer Vision

Kerak bo'lishi mumkin:

```text id="g9m4qx"
OpenCV

+

Deep Learning Models
```

---

Vazifalar:

* object detection;
* furniture recognition;
* room analysis.

---

# 16. Search System

Boshlanish:

PostgreSQL Search.

---

Keyinchalik:

```text id="i5m8qx"
Elasticsearch

yoki

OpenSearch
```

---

Vazifa:

* mahsulot qidirish;
* filter;
* recommendation.

---

# 17. Authentication

Boshlanish:

JWT.

---

Qo'shimcha:

* Apple Sign In;
* Google Login;
* SMS verification.

---

# 18. Deployment

## Server OS

```text id="j7m3qx"
Linux Ubuntu
```

---

Web:

```text id="k8m4qx"
Nginx
```

---

Application:

```text id="l9m5qx"
Gunicorn

+

Uvicorn
```

---

# 19. Containerization

Tanlov:

```text id="m3x7pq"
Docker
```

---

Foyda:

* bir xil environment;
* deploy osonligi;
* scaling.

---

# 20. CI/CD

Kelajak:

```text id="n4m8qx"
GitHub Actions
```

---

Jarayon:

```text id="o5m9qx"

Push Code

↓

Run Tests

↓

Build

↓

Deploy

```

---

# 21. Monitoring

Kerak:

* server metrics;
* error tracking;
* logs.

---

Vositalar:

* Prometheus;
* Grafana;
* Sentry.

---

# 22. MVP Technology Decision

Birinchi versiya:

```text id="p6m2qx"

Backend:
Django + DRF


Database:
PostgreSQL


Cache:
Redis


Web:
React + TypeScript


Mobile:
Swift + ARKit


Storage:
S3 Compatible

```

---

# 23. Future Scaling

Kelajak:

```text id="q7m3qx"

Microservices

+

Kubernetes

+

GPU AI Servers

```

---

# 24. Final Decision

Furniture Platform uchun asosiy texnologik yo'nalish:

```text id="r8m4qx"

Django Backend

+

PostgreSQL

+

React Dashboard

+

Swift ARKit App

+

AI Services

```

---

# 25. Summary

Tanlangan stack:

* MVP uchun tez;
* professional daraja uchun yetarli;
* AR va AI rivoji uchun ochiq.

Asosiy ustunlik:

> Soddalik bilan boshlanadi, lekin global platformaga aylanish imkoniyatini saqlaydi.
