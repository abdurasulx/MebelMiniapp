from decimal import Decimal

from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from .models import ManufacturedUnit, ProductMovement, ProductStock


def check_order_stock_availability(order):
    """Buyurtmadagi har bir band (custom o'lchamlilardan tashqari) uchun
    omborda yetarli tayyor dona (ManufacturedUnit, status=IN_STOCK) bor-
    yo'qligini tekshiradi — yozmasdan, faqat hisoblab qaytaradi.

    MUHIM: buyurtma berilishining o'zi ombor qoldig'ini kamaytirmaydi —
    bu funksiya faqat "firma tasdiqlasa yetarlimi" degan savolga javob
    beradi (docs "Market buyurtmasi va ombor prinsipi" §0).
    """
    result = []
    for item in order.items.filter(is_deleted=False):
        if item.is_custom_size:
            continue
        available = ManufacturedUnit.objects.filter(
            product=item.product, variant=item.variant,
            status=ManufacturedUnit.Status.IN_STOCK, is_deleted=False,
        ).count()
        result.append({
            "item_id": str(item.id),
            "product_name": item.product_name,
            "requested": item.quantity,
            "available": available,
            "sufficient": available >= item.quantity,
        })
    return result


def fulfill_order_from_stock(order, user):
    """Buyurtmani mavjud tayyor ombordan "sotildi/berildi" deb yopadi —
    faqat firma (yoki admin) buni ANIQ tasdiqlagan paytda chaqiriladi
    (qarang apps/orders/views.py OrderViewSet.confirm_sold_from_stock).
    Yetarli dona bo'lmasa hech narsa o'zgarmaydi, ValidationError
    ko'tariladi — bunday holda firma buyurtmani odatdagi ishlab
    chiqarish oqimiga (set_status → in_production) yuborishi kerak.

    `SellUnitsView.post()` bilan bir xil naqsh (FIFO, ManufacturedUnit +
    ProductStock + ProductMovement birgalikda yangilanadi), farqi — bu
    yerda alohida dona tanlanmaydi, butun buyurtma bo'yicha avtomatik
    ishlaydi va har bir harakat `source_order`ga bog'lanadi (audit).
    """
    availability = check_order_stock_availability(order)
    insufficient = [row for row in availability if not row["sufficient"]]
    if insufficient:
        names = ", ".join(row["product_name"] for row in insufficient)
        raise ValidationError(
            f"Omborda yetarli tayyor mahsulot yo'q: {names}. "
            "Buyurtmani ishlab chiqarishga yuboring."
        )

    sold_units = []
    now = timezone.now()
    with transaction.atomic():
        for item in order.items.filter(is_deleted=False):
            if item.is_custom_size or item.quantity == 0:
                continue
            units = list(
                ManufacturedUnit.objects.select_for_update()
                .filter(
                    product=item.product, variant=item.variant,
                    status=ManufacturedUnit.Status.IN_STOCK, is_deleted=False,
                )
                .order_by("created_at")[: item.quantity]
            )
            if len(units) < item.quantity:
                # Bir vaqtda ikkita so'rov poyga holatiga tushib qolsa —
                # select_for_update baribir ushlaydi, lekin ehtiyot chorasi
                # sifatida yana tekshiramiz.
                raise ValidationError(
                    f"Omborda yetarli tayyor mahsulot yo'q: {item.product_name}"
                )
            unit_price = (item.subtotal / item.quantity) if item.quantity else Decimal("0")
            for unit in units:
                unit.status = ManufacturedUnit.Status.SOLD
                unit.sale_price = unit_price
                unit.sold_at = now
                unit.order = order
                unit.save(update_fields=["status", "sale_price", "sold_at", "order"])
            sold_units.extend(units)

            by_warehouse = {}
            for unit in units:
                if unit.warehouse_id:
                    by_warehouse.setdefault(unit.warehouse_id, []).append(unit)
            for warehouse_id, unit_list in by_warehouse.items():
                stock = ProductStock.objects.select_for_update().filter(
                    warehouse_id=warehouse_id, product=item.product, variant=item.variant
                ).first()
                if stock:
                    stock.quantity = max(Decimal("0"), stock.quantity - len(unit_list))
                    stock.save(update_fields=["quantity"])
                ProductMovement.objects.create(
                    warehouse_id=warehouse_id, product=item.product, variant=item.variant,
                    movement_type=ProductMovement.Type.OUT, quantity=len(unit_list),
                    note=f"Market buyurtmasi #{str(order.id)[:8]} orqali sotildi",
                    created_by=user, source_order=order,
                )
    return sold_units
