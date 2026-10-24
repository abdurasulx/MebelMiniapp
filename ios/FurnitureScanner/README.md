# Mebel Scanner

Mustaqil iOS AR o‘lchash ilovasi. Kamera oynasida mebelning eni, bo‘yi va chuqurligi uchun ikki nuqta belgilanadi; masofa santimetrda hisoblanadi.

## Ishga tushirish

```sh
cd ios/FurnitureScanner
xcodegen generate
open FurnitureScanner.xcodeproj
```

ARKit haqiqiy qurilmada sinalishi kerak. LiDAR’li iPhone/iPad Pro qurilmalarida sirt chuqurligi aniqroq aniqlanadi.

## Keyingi qadam

API berilgach, `FurnitureMeasurement` obyektini `POST` orqali yuborish, skan fotosi va mebel identifikatorini biriktirish qo‘shiladi.
