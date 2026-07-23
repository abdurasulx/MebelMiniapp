# Design Tokens — Furniture Platform

Ranglar eski mebelweb loyihasining `base.html` dagi tasdiqlangan palitrasidan olingan.
Frontend (React) va mobil ilova shu tokenlardan foydalanadi.

## Light theme (default)

| Token | Qiymat | Izoh |
|---|---|---|
| `--primary` | `#ECC299` | Iliq qum/beige — header, asosiy aksent |
| `--secondary` | `#3498db` | Ko'k — linklar, tugmalar |
| `--bg` | `#ffffff` | Fon |
| `--text` | `#2c3e50` | Asosiy matn |
| `--shadow` | `0 2px 10px rgba(0,0,0,0.08)` | Karta/header soyasi |

## Dark theme (`.dark-mode`)

| Token | Qiymat | Izoh |
|---|---|---|
| `--primary` | `#4C2C24` | To'q jigarrang (yog'och) |
| `--secondary` | `#50a3d3` | Ochroq ko'k |
| `--bg` | `#0d0d15` | Fon |
| `--text` | `#eaeaea` | Matn |
| `--shadow` | `0 2px 15px rgba(0,0,0,0.6)` | Soyalar |

## Qo'shimcha (eski loyihadan)

- Header matni: `#fff`
- Muted matn: `#999`
- Hover overlay: `rgba(255,255,255,0.15)`

## CSS snippet

```css
:root {
  --primary: #ECC299;
  --secondary: #3498db;
  --bg: #ffffff;
  --text: #2c3e50;
  --shadow: 0 2px 10px rgba(0, 0, 0, 0.08);
}

.dark-mode {
  --primary: #4C2C24;
  --secondary: #50a3d3;
  --bg: #0d0d15;
  --text: #eaeaea;
  --shadow: 0 2px 15px rgba(0, 0, 0, 0.6);
}
```
