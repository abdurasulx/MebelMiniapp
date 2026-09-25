from django.contrib import admin

from .models import (
    BillOfMaterial,
    ManufacturedUnit,
    Material,
    MaterialMovement,
    MaterialRemnant,
    MaterialStock,
    ProductMovement,
    ProductStock,
    Warehouse,
)

admin.site.register(Warehouse)
admin.site.register(Material)
admin.site.register(MaterialStock)
admin.site.register(MaterialMovement)
admin.site.register(MaterialRemnant)
admin.site.register(ProductStock)
admin.site.register(ProductMovement)
admin.site.register(BillOfMaterial)
admin.site.register(ManufacturedUnit)
