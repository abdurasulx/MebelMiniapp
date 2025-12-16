from .models import BasketItem
from django.db.models import Sum

def cart_count(request):
    count = 0
    if request.user.is_authenticated:
        count = BasketItem.objects.filter(user=request.user).aggregate(total=Sum('quantity'))['total'] or 0
    return {'cart_count': count}
