from django.db import models
from django.contrib.auth.models import User


User.add_to_class(
    'tg_id',
    models.BigIntegerField(
        unique=True,
        null=True,
        blank=True,
        verbose_name="Telegram ID"
    )
)

# Telefon ham kerak boʻlsa (ixtiyoriy)
User.add_to_class(
    'phone',
    models.CharField(max_length=20, blank=True, null=True, verbose_name="Telefon")
)

class Category(models.Model):
    name_uz = models.CharField(max_length=100)
    name_ru = models.CharField(max_length=100, blank=True)
    image = models.ImageField(upload_to='categories/')

    def __str__(self):
        return self.name_uz

class Product(models.Model):
    category = models.ForeignKey(Category, on_delete=models.CASCADE, related_name='products')
    name_uz = models.CharField(max_length=200)
    name_ru = models.CharField(max_length=200, blank=True)
    image = models.ImageField(upload_to='products/')
    video_url = models.URLField(max_length=500, blank=True, null=True, help_text="YouTube yoki video URL")

    def __str__(self):
        return self.name_uz

class Variant(models.Model):
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='variants')
    name = models.CharField(max_length=100)  # Variant nomi (masalan: "Yong'oq", "DCP", "Tolda")
    base_price = models.DecimalField(max_digits=10, decimal_places=2)  # 1 m³ uchun narx
    width = models.DecimalField(max_digits=6, decimal_places=2, default=1.0)  # metr
    height = models.DecimalField(max_digits=6, decimal_places=2, default=1.0)
    depth = models.DecimalField(max_digits=6, decimal_places=2, default=1.0)

    def __str__(self):
        return f"{self.product} - {self.name}"

class VariantImage(models.Model):
    variant = models.ForeignKey(Variant, on_delete=models.CASCADE, related_name='images')
    image = models.ImageField(upload_to='variants/')
    
    def __str__(self):
        return f"Image for {self.variant}"

class OrderItem(models.Model):
    variant = models.ForeignKey(Variant, on_delete=models.CASCADE)
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    width = models.DecimalField(max_digits=6, decimal_places=2)
    height = models.DecimalField(max_digits=6, decimal_places=2)
    depth = models.DecimalField(max_digits=6, decimal_places=2)
    quantity = models.PositiveIntegerField()
    price = models.DecimalField(max_digits=10, decimal_places=2)

    def __str__(self):
        return f"OrderItem: {self.variant} x {self.quantity}"

class Order(models.Model):
    # we must change status to shoice. there is must be 4 status: pending, processing, completed, cancelled
    user = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    items = models.ManyToManyField(OrderItem)
    total_price = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, default='pending', choices=(
        ('pending', 'Yangi'),
        ('processing', 'Tayyorlanmoqda'),
        ('completed', 'Yuborilgan'),
        ('cancelled', 'Bekor qilindi')
    ))

    def __str__(self):
        return f"Order #{self.id} - {self.created_at.strftime('%Y-%m-%d %H:%M:%S')}"
class BasketItem(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='basket_items')
    variant = models.ForeignKey(Variant, on_delete=models.CASCADE)
    width = models.DecimalField(max_digits=6, decimal_places=2, default=1.0)
    height = models.DecimalField(max_digits=6, decimal_places=2, default=1.0)
    depth = models.DecimalField(max_digits=6, decimal_places=2, default=1.0)
    price = models.DecimalField(max_digits=12, decimal_places=2)  # Narx (dimensionga qarab)
    quantity = models.PositiveIntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} - {self.variant.name} ({self.quantity})"

    @property
    def total_price(self):
        return self.price * self.quantity
