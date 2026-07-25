from django.contrib import admin

from .models import Material, MaterialMovement, MaterialStock, ProductMovement, ProductStock, Warehouse

admin.site.register(Warehouse)
admin.site.register(Material)
admin.site.register(MaterialStock)
admin.site.register(MaterialMovement)
admin.site.register(ProductStock)
admin.site.register(ProductMovement)
