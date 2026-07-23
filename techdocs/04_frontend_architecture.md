# Frontend Architecture Specification

## 1. Overview

Furniture Platform frontend qismi kompaniyalar, administratorlar va xodimlar uchun boshqaruv interfeysi hisoblanadi.

Asosiy vazifalar:

* ERP boshqaruvi;
* CRM boshqaruvi;
* mahsulot boshqaruvi;
* 3D asset boshqaruvi;
* buyurtmalar nazorati;
* analitika.

---

# 2. Frontend Architecture Style

Tanlov:

```text id="a8m3qx"
React

+

TypeScript

+

Component Based Architecture
```

---

Sabab:

* katta dashboardlar uchun mos;
* qayta ishlatiladigan komponentlar;
* kuchli ecosystem;
* uzoq muddat qo'llab-quvvatlash.

---

# 3. Frontend Applications

Platformada bir nechta frontend bo'ladi.

```text id="m7p2qx"

Frontend Layer

|

├── Customer Web

├── Company Dashboard

├── Admin Panel

└── Internal Tools

```

---

# 4. Company Dashboard

Mebelchilar uchun asosiy panel.

Modullar:

```text id="q5m8vx"

Dashboard

Products

Orders

Production

CRM

Employees

Materials

Analytics

Settings

```

---

# 5. Customer Web

Mijoz uchun.

Funksiyalar:

* katalog;
* qidiruv;
* mahsulot ko'rish;
* kompaniya tanlash;
* buyurtma.

---

# 6. Admin Panel

Platforma operatorlari uchun.

Funksiyalar:

* kompaniya moderatsiyasi;
* user boshqaruvi;
* tariflar;
* support;
* analytics.

---

# 7. Technology Stack

## Framework

```text id="w8m3qx"
React 19+
```

---

## Language

```text id="r6m2qx"
TypeScript
```

---

## Build Tool

```text id="x3m7pq"
Vite
```

---

## Styling

```text id="y7m4qx"
Tailwind CSS
```

---

# 8. Project Structure

Tavsiya:

```text id="z8m3qx"

frontend/

├── src/

│

├── app/

│   ├── router

│   ├── store

│   └── providers


├── pages/

│

├── features/

│

├── components/

│

├── services/

│

├── hooks/

│

├── utils/

└── types/

```

---

# 9. Feature Based Structure

Har biznes moduli alohida.

Misol:

```text id="a9m4qx"

features/

├── products/

│   ├── api.ts

│   ├── components

│   └── hooks


├── orders/

└── crm/

```

---

# 10. State Management

Tanlov:

```text id="b5m8qx"
Zustand
```

---

Ishlatiladi:

* user state;
* company context;
* UI state.

---

Server data:

```text id="c6m3qx"
React Query
```

---

Vazifalar:

* caching;
* synchronization;
* API requests.

---

# 11. API Communication

Backend bilan:

```text id="d7m2qx"

Frontend

↓

API Client

↓

Django REST API

```

---

HTTP client:

```text id="e8m3qx"
Axios
```

---

# 12. Authentication Flow

```text id="f9m4qx"

Login

↓

Receive JWT

↓

Store Token

↓

Attach Request Header

↓

Access Protected Pages

```

---

# 13. Routing

Tanlov:

```text id="g5m8qx"
React Router
```

---

Misol:

```text id="h6m3qx"

/

 /dashboard

 /products

 /orders

 /crm

 /settings

```

---

# 14. UI Component System

Umumiy komponentlar:

```text id="i7m3qx"

Button

Input

Modal

Table

Card

Form

Upload

Chart

```

---

# 15. Design System

Maqsad:

barcha platformada bir xil ko'rinish.

---

Qoidalar:

* ranglar;
* spacing;
* typography;
* component behavior.

---

# 16. Product Management UI

Mebelchi uchun:

## Product Create

Maydonlar:

* nom;
* kategoriya;
* narx;
* material;
* rasm;
* 3D model.

---

## Product Edit

Qo'llaydi:

* variantlar;
* rang;
* o'lcham.

---

# 17. 3D Asset UI

Funksiyalar:

* upload;
* progress;
* processing status;
* preview.

---

Status:

```text id="j8m4qx"

UPLOADED

PROCESSING

READY

FAILED

```

---

# 18. Order Management UI

Ko'rinish:

Kanban style.

```text id="k9m5qx"

New

↓

Production

↓

Delivery

↓

Completed

```

---

# 19. CRM UI

Ko'rinish:

Pipeline.

```text id="l8m4qx"

Lead

↓

Contacted

↓

Negotiation

↓

Won

```

---

# 20. ERP UI

Bo'limlar:

* materiallar;
* ishlab chiqarish;
* xodimlar;
* xarajatlar.

---

# 21. Analytics Dashboard

Ko'rsatkichlar:

* sotuv;
* buyurtmalar;
* foyda;
* mashhur mahsulotlar.

---

Grafiklar:

* line chart;
* bar chart;
* pie chart.

---

# 22. Permission Based UI

Frontend foydalanuvchi roliga qarab o'zgaradi.

Misol:

Employee:

ko'radi:

* buyurtmalar.

Company Owner:

ko'radi:

* moliya;
* xodimlar.

---

# 23. Responsive Design

Qo'llab-quvvatlash:

* desktop;
* tablet.

---

Mobil asosiy boshqaruv uchun emas.

AR funksiyalar mobil appda bo'ladi.

---

# 24. Performance Optimization

Usullar:

* lazy loading;
* code splitting;
* image optimization;
* caching.

---

# 25. Error Handling

Frontend:

xatolarni foydalanuvchiga tushunarli ko'rsatadi.

Misol:

```text id="m9m5qx"

3D model yuklanmadi.

Qaytadan urinib ko'ring.

```

---

# 26. Testing

Ishlatiladi:

```text id="n8m3qx"

Vitest

+

React Testing Library

```

---

# 27. Deployment

Build:

```bash
npm run build
```

---

Deploy:

* Nginx;
* CDN;
* static hosting.

---

# 28. MVP Frontend Scope

Birinchi versiya:

✅ Authentication

✅ Company Dashboard

✅ Product CRUD

✅ Order Management

✅ Basic CRM

✅ 3D Upload Interface

---

# 29. Future Expansion

Qo'shiladi:

* advanced analytics;
* AI assistant;
* drag-drop design;
* collaborative planning.

---

# 30. Summary

Frontend arxitekturasi:

* React + TypeScript;
* feature based;
* scalable;
* API driven.

Maqsad:

> Mebelchini har kuni ishlatadigan qulay biznes boshqaruv panelini yaratish.
