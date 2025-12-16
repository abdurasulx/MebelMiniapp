from django.shortcuts import render, get_object_or_404, redirect
from django.http import JsonResponse
from django.views.decorators.http import require_POST
from .models import Category, Product, Variant, VariantImage, Order, OrderItem, BasketItem
import json
from django.utils import timezone
from datetime import timedelta
from django.contrib.auth.decorators import login_required
from django.db import models
from .forms import ProductForm, VariantFormSet, CategoryForm
from django.contrib import messages
from django.db.models import Count
from functools import wraps
from django.urls import reverse
from decimal import Decimal
import logging

logger = logging.getLogger(__name__)

# Admin protection dekorator
def admin_required(view_func):
    @wraps(view_func)
    def wrapped_view(request, *args, **kwargs):
        if not request.user.is_authenticated or not (request.user.is_staff or request.user.is_superuser):
            messages.error(request, "Siz admin emasiz!")
            return redirect('/')
        return view_func(request, *args, **kwargs)
    return wrapped_view

# 1. Bosh sahifa
@login_required(login_url='login')
def index(request):
    # Show regular shop homepage for everyone (including authenticated users)
    if request.user.is_authenticated and request.user.is_staff:
        context = {
            'total_products': Product.objects.count(),
            'total_categories': Category.objects.count(),
            'total_variants': Variant.objects.count(),
            'today_orders': Order.objects.filter(created_at__date=timezone.now().date()).count()
        }
        return render(request, 'admin/dashboard.html', context)
    categories = Category.objects.all()
    return render(request, 'index.html', {'categories': categories})

# 2. Kategoriya
@login_required(login_url='login')
def category_view(request, cat_id):
    category = get_object_or_404(Category, id=cat_id)
    products = Product.objects.filter(category=category)
    return render(request, 'category.html', {'category': category, 'products': products})

# 3. Mahsulot
@login_required(login_url='login')
def product_view(request, prod_id):
    product = get_object_or_404(Product, id=prod_id)
    return render(request, 'product.html', {'product': product})

# 4. Variant
@login_required(login_url='login')
def variant_view(request, prod_id, var_id):
    product = get_object_or_404(Product, id=prod_id)
    variant = get_object_or_404(Variant, id=var_id, product=product)
    images = variant.images.all()
    return render(request, 'variant.html', {
        'variant': variant,
        'images': images,
        'product': product
    })

# 5. Savatchaga qo'shish
@login_required(login_url='login')
@require_POST
def add_to_cart(request):
    try:
        data = json.loads(request.body)
        variant_id = data.get('variant_id')
        width = Decimal(str(data.get('width', 1)))
        height = Decimal(str(data.get('height', 1)))
        depth = Decimal(str(data.get('depth', 1)))
        quantity = int(data.get('quantity', 1))

        if not variant_id:
            return JsonResponse({'success': False, 'error': 'Variant ID kerak'}, status=400)

        variant = get_object_or_404(Variant, id=variant_id)
        volume = width * height * depth
        
        # Narxni hisoblash (Variant base_price * volume)
        price_per_item = variant.base_price * volume

        # Savatda bor-yo'qligini tekshirish
        cart_item, created = BasketItem.objects.get_or_create(
            user=request.user,
            variant=variant,
            width=width,
            height=height,
            depth=depth,
            defaults={'price': price_per_item, 'quantity': quantity}
        )

        if not created:
            cart_item.quantity += quantity
            # Price might change if base_price changed, but let's keep it simple or update it
            # cart_item.price = price_per_item 
            cart_item.save()

        # Savatdagi umumiy son
        total_qty = BasketItem.objects.filter(user=request.user).aggregate(total=models.Sum('quantity'))['total'] or 0
        
        return JsonResponse({'success': True, 'cart_count': total_qty})
    except json.JSONDecodeError:
        return JsonResponse({'success': False, 'error': 'JSON xatosi'}, status=400)
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)}, status=500)

# 6. Savatcha
@login_required(login_url='login')
def cart_view(request):
    basket_items = BasketItem.objects.filter(user=request.user)
    items = []
    total = 0
    
    for item in basket_items:
        item_total = item.price * item.quantity
        total += item_total
        
        # Get image URL
        image_url = item.variant.product.image.url if item.variant.product.image else '/media/default.png'
        if item.variant.images.exists():
            image_url = item.variant.images.first().image.url

        items.append({
            'key': item.id,  # Using DB ID as key
            'variant_id': item.variant.id,
            'material': item.variant.name,
            'product_name': item.variant.product.name_uz,
            'image': image_url,
            'width': item.width,
            'height': item.height,
            'depth': item.depth,
            'price': item.price,
            'quantity': item.quantity,
            'total': item_total
        })
        
    return render(request, 'cart.html', {'items': items, 'total': total})

# 7. Savatchani yangilash
@login_required(login_url='login')
@require_POST
def update_cart(request):
    try:
        data = json.loads(request.body)
        action = data.get('action')
        key = data.get('key')  # This is basket_item.id now

        if not action or not key:
            return JsonResponse({'success': False, 'error': 'Action va key kerak'}, status=400)

        item = get_object_or_404(BasketItem, id=key, user=request.user)

        if action == 'remove':
            item.delete()
        elif action == 'quantity':
            qty = int(data.get('quantity', 0))
            if qty <= 0:
                item.delete()
            else:
                item.quantity = qty
                item.save()
        else:
            return JsonResponse({'success': False, 'error': 'Noto\'g\'ri action'}, status=400)

        return JsonResponse({'success': True})
    except json.JSONDecodeError:
        return JsonResponse({'success': False, 'error': 'JSON xatosi'}, status=400)
    except Exception as e:
        return JsonResponse({'success': False, 'error': str(e)}, status=500)


@admin_required
def orders_view(request):
    """Display all orders in custom admin"""
    orders = Order.objects.select_related('user').prefetch_related('items').order_by('-id')
    return render(request, 'admin/orders.html', {'orders': orders})


@admin_required
def order_detail(request, pk):
    """Display order details"""
    order = get_object_or_404(Order, pk=pk)
    status_choices = Order._meta.get_field('status').choices
    
    context = {
        'order': order,
        'status_choices': status_choices
    }
    return render(request, 'admin/order_detail.html', context)


@admin_required
def order_detail_json(request, pk):
    """Return order details as JSON for modal"""
    order = get_object_or_404(Order, pk=pk)
    
    # Prepare order items
    items_data = []
    for item in order.items.all():
        items_data.append({
            'product_name': item.product.name_uz,
            'variant_name': item.variant.name,
            'width': float(item.width),
            'height': float(item.height),
            'depth': float(item.depth),
            'quantity': item.quantity,
            'price': float(item.price),
            'total': float(item.price * item.quantity)
        })
    
    # Calculate user stats
    user_stats = {
        'total_orders': 0,
        'completed_orders': 0,
        'cancelled_orders': 0,
        'trust_score': 0
    }
    
    if order.user:
        user_orders = Order.objects.filter(user=order.user)
        user_stats['total_orders'] = user_orders.count()
        user_stats['completed_orders'] = user_orders.filter(status='completed').count()
        user_stats['cancelled_orders'] = user_orders.filter(status='cancelled').count()
        
        if user_stats['total_orders'] > 0:
            user_stats['trust_score'] = int((user_stats['completed_orders'] / user_stats['total_orders']) * 100)

    # Prepare response
    data = {
        'order_id': order.id,
        'created_at': order.created_at.strftime('%d.%m.%Y %H:%M'),
        'status': order.status,
        'status_display': order.get_status_display(),
        'total_price': float(order.total_price),
        'user': {
            'first_name': order.user.first_name or '-' if order.user else '-',
            'username': order.user.username if order.user else '-',
            'phone': order.user.phone or '-' if order.user else '-',
            'tg_id': order.user.tg_id or '-' if order.user else '-'
        },
        'user_stats': user_stats,
        'items': items_data,
        'status_choices': [{'value': v, 'label': l} for v, l in Order._meta.get_field('status').choices]
    }
    
    return JsonResponse(data)


@admin_required
@require_POST
def order_update_status(request, pk):
    """Update order status"""
    order = get_object_or_404(Order, pk=pk)
    new_status = request.POST.get('status')
    
    if new_status in ['pending', 'processing', 'completed', 'cancelled']:
        old_status = order.status
        order.status = new_status
        order.save()
        logger.info(f"Order #{order.id} status changed: {old_status} -> {new_status} by {request.user.username}")
        return JsonResponse({'success': True, 'message': f'Buyurtma holati yangilandi: {order.get_status_display()}', 'new_status': new_status, 'new_status_display': order.get_status_display()})
    else:
        logger.warning(f"Invalid status update attempt for Order #{order.id}: {new_status}")
        return JsonResponse({'success': False, 'error': 'Noto\'g\'ri holat!'}, status=400)


@login_required(login_url='login')
def profile_view(request):
    """Show user profile and order history"""
    user = request.user
    orders = Order.objects.filter(user=user).order_by('-created_at')
    
    # Har bir orderga uning itemlarini qo'shish
    orders_with_items = []
    for order in orders:
        items = OrderItem.objects.filter(order=order)
        orders_with_items.append({
            'order': order,
            'items': items,
            'total_items': sum(item.quantity for item in items)
        })
    
    context = {
        'user': user,
        'orders_with_items': orders_with_items,
        'total_orders': orders.count(),
    }
    
    return render(request, 'profile.html', context)

@admin_required
def admin_stats(request):
    today = timezone.now().date()
    
    # 1. Kunlik sotuvlar (so‘nggi 14 kun)
    sales_data = []
    dates = []
    for i in range(13, -1, -1):
        date = today - timedelta(days=i)
        total = Order.objects.filter(
            created_at__date=date,
            status='completed'
        ).aggregate(total=models.Sum('total_price'))['total'] or 0
        sales_data.append(float(total))
        dates.append(date.strftime("%d.%m"))

    # 2. Eng ko‘p sotilgan mahsulotlar (so‘nggi 30 kun)
    top_products = OrderItem.objects.filter(
        order__created_at__gte=today - timedelta(days=30),
        order__status='completed'
    ).values('product__name_uz').annotate(count=models.Count('id')).order_by('-count')[:8]

    top_names = [item['product__name_uz'] for item in top_products]
    top_sales = [item['count'] for item in top_products]

    context = {
        'current_month': today.strftime("%B %Y"),
        
        'sales_dates': dates,           # ['01.04', '02.04', ...]
        'sales_amounts': sales_data,    # [1250000, 3400000, ...]
        
        'top_products_names': top_names,
        'top_products_sales': top_sales,
    }
    # print(context)
    return render(request, 'admin/stats.html', context)

@login_required
@admin_required
def admin_products(request):
    products = Product.objects.select_related('category').prefetch_related('variants').all()
    return render(request, 'admin/products.html', {'products': products})

@admin_required
def admin_product_add(request):
    if request.method == 'POST':
        form = ProductForm(request.POST, request.FILES)
        formset = VariantFormSet(request.POST)
        if form.is_valid() and formset.is_valid():
            product = form.save()
            formset.instance = product
            formset.save()
            messages.success(request, "Mahsulot muvaffaqiyatli qo'shildi!")
            return redirect('admin_products')
    else:
        form = ProductForm()
        formset = VariantFormSet(queryset=Variant.objects.none())

    return render(request, 'admin/product_form.html', {
        'form': form,
        'variant_formset': formset
    })

@admin_required
def admin_product_edit(request, pk):
    product = get_object_or_404(Product, pk=pk)

    if request.method == 'POST':
        form = ProductForm(request.POST, request.FILES, instance=product)
        variant_formset = VariantFormSet(
            request.POST,
            request.FILES,
            instance=product
        )

        if form.is_valid() and variant_formset.is_valid():
            product = form.save()

            # Variantlarni saqlash
            variants = variant_formset.save(commit=False)
            for variant in variants:
                variant.product = product
                variant.save()

            # O'chirilgan variantlarni o'chirish
            for obj in variant_formset.deleted_objects:
                obj.delete()

            # Variant rasmlarini yuklash (inline upload)
            for variant in product.variants.all():
                images_key = f'variant_{variant.pk}_images'
                images = request.FILES.getlist(images_key)
                for image in images:
                    VariantImage.objects.create(variant=variant, image=image)

            messages.success(request, f'"{product.name_uz}" muvaffaqiyatli yangilandi!')
            return redirect('admin_products')

        else:
            messages.error(request, 'Ma`lumotlarda xatolik bor. Iltimos, tekshiring.')

    else:
        # GET so'rov
        form = ProductForm(instance=product)
        variant_formset = VariantFormSet(instance=product)

    return render(request, 'admin/product_form.html', {
        'form': form,
        'variant_formset': variant_formset,
        'product': product,
    })



@admin_required
def admin_product_delete(request, pk):
    product = get_object_or_404(Product, pk=pk)
    if request.method == 'GET':
        product.delete()
        messages.success(request, 'Mahsulot o‘chirildi')
    return redirect('admin_products')

@login_required
@admin_required
def admin_categories(request):
    categories = Category.objects.annotate(
    product_count=Count('products')
    ).order_by('-id')
    return render(request, 'admin/categories.html', {'categories': categories})

@login_required
@admin_required
@admin_required
def admin_category_add(request):
    if request.method == 'POST':
        form = CategoryForm(request.POST, request.FILES)
        if form.is_valid():
            form.save()
            messages.success(request, 'Kategoriya qo‘shildi!')
            return redirect('admin_categories')
    else:
        form = CategoryForm()
    return render(request, 'admin/category_form.html', {'form': form})

@login_required
@admin_required
@admin_required
def admin_category_edit(request, pk):
    category = get_object_or_404(Category, pk=pk)
    if request.method == 'POST':
        form = CategoryForm(request.POST, request.FILES, instance=category)
        if form.is_valid():
            form.save()
            messages.success(request, 'Kategoriya yangilandi!')
            return redirect('admin_categories')
    else:
        form = CategoryForm(instance=category)
    return render(request, 'admin/category_form.html', {'form': form})

@login_required
@admin_required
@admin_required
def admin_category_delete(request, pk):
    category = get_object_or_404(Category, pk=pk)
    if request.method == 'GET':
        category.delete()
        messages.success(request, 'Kategoriya o\'chirildi')
        return redirect('admin_categories')
    print("Kategoriya o'chirilmadi")
    return redirect('admin_categories')


# ==================== LOGIN & REGISTRATION ====================

from django.contrib.auth import authenticate, login as auth_login, logout as auth_logout
from django.contrib.auth.models import User
from urllib.parse import urlparse

def is_safe_url(url):
    """URL xavfsiz ekanligini tekshirish"""
    parsed = urlparse(url)
    return parsed.scheme == "" and parsed.netloc == ""


def telegram_login(request):
    """
    Login qismi:
    GET parametri orqali tg_id keladi.
    Agar foydalanuvchi topilsa, login boladi va next sahifaga otadi.
    Agar foydalanuvchi topilmasa, register sahifasiga yonaltiriladi.
    """
    if request.method == "GET":
        tg_id = request.GET.get("tg_id")
        next_url = request.GET.get("next", "")
        print(tg_id)
        
        if not tg_id:
            messages.error(request, "Telegram ID majburi!")
            return redirect("register")
        
        try:
            tg_id = int(tg_id)
        except (ValueError, TypeError):
            messages.error(request, "Telegram ID notogri!")
            return redirect("register")
        
        try:
            user = User.objects.get(tg_id=tg_id)
            user.backend = "django.contrib.auth.backends.ModelBackend"
            auth_login(request, user)
            messages.success(request, f"Xush kelibsiz, {user.username}!")
            
            # Restore user's theme preference from session or default
            if hasattr(request, 'session') and request.session.get('theme'):
                request.session['theme'] = request.session.get('theme', 'light')
            
            if next_url and is_safe_url(next_url):
                return redirect(next_url)
            else:
                return redirect("index")
        except User.DoesNotExist:
            messages.info(request, "Siz royxatdan otishingiz kerak.")
            # we must reverse this url register
            
            redirect_url = reverse('register')
            if next_url and is_safe_url(next_url):
                return redirect(f"{redirect_url}?tg_id={tg_id}&next={next_url}")
            return redirect(f"{redirect_url}?tg_id={tg_id}&next={next_url}")
    
    return redirect("index")


def register(request):
    """Registratsiya qismi"""
    tg_id = request.GET.get("tg_id", "")
    next_url = request.GET.get("next", "")
    
    if request.method == "POST":
        first_name = request.POST.get("first_name")
        phone = request.POST.get("phone", "")
        tg_id = request.POST.get("tg_id")
        
        if not first_name or not phone or not tg_id:
            messages.error(request, "Ism, telefon va Telegram ID majburi!")
            return render(request, "register.html", {
                "tg_id": tg_id,
                "next": next_url,
                "first_name": first_name,
                "phone": phone
            })
        
        if User.objects.filter(tg_id=tg_id).exists():
            messages.error(request, "Bu Telegram ID allaqachon royxatdan otgan!")
            return render(request, "register.html", {
                "tg_id": tg_id,
                "next": next_url,
                "first_name": first_name,
                "phone": phone
            })
        
        if User.objects.filter(phone=phone).exists():
            messages.error(request, "Bu telefon raqami allaqachon royxatdan otgan!")
            return render(request, "register.html", {
                "tg_id": tg_id,
                "next": next_url,
                "first_name": first_name,
                "phone": phone
            })
        
        try:
            tg_id_int = int(tg_id)
        except (ValueError, TypeError):
            messages.error(request, "Telegram ID notogri!")
            return render(request, "register.html", {
                "tg_id": tg_id,
                "next": next_url,
                "first_name": first_name,
                "phone": phone
            })
        
        # Generate unique username from phone
        username = "user_" + phone.replace("+", "").replace(" ", "").replace("-", "")[-9:]
        
        user = User.objects.create_user(
            username=username,
            first_name=first_name,
            tg_id=tg_id_int,
            phone=phone
        )
        
        user.backend = "django.contrib.auth.backends.ModelBackend"
        auth_login(request, user)
        messages.success(request, "Muvaffaqiyatli royxatdan ottingiz!")
        
        if next_url and is_safe_url(next_url):
            return redirect(next_url)
        else:
            return redirect("index")
    
    return render(request, "register.html", {
        "tg_id": tg_id,
        "next": next_url
    })


@admin_required
def add_variant_image(request, variant_id):
    """Add images to a variant"""
    variant = get_object_or_404(Variant, pk=variant_id)
    
    if request.method == 'POST':
        image = request.FILES.get('image')
        if image:
            VariantImage.objects.create(variant=variant, image=image)
            messages.success(request, 'Rasm qo\'shildi!')
        else:
            messages.error(request, 'Rasm tanlanmadi!')
        return redirect('admin_product_edit', pk=variant.product.pk)
    
    return render(request, 'admin/variant_image_form.html', {
        'variant': variant
    })

@admin_required
def delete_variant_image(request, image_id):
    """Delete a variant image"""
    image = get_object_or_404(VariantImage, pk=image_id)
    product_id = image.variant.product.pk
    image.delete()
    messages.success(request, 'Rasm o\'chirildi!')
    return redirect('admin_product_edit', pk=product_id)


@login_required(login_url='login')
@require_POST
def place_order(request):
    """Create order from cart items"""
    try:
        data = json.loads(request.body)
        selected_keys = data.get('selected_items', [])
        
        if not selected_keys:
            return JsonResponse({'success': False, 'error': 'Hech narsa tanlanmagan'}, status=400)
        
        # Get selected basket items
        basket_items = BasketItem.objects.filter(
            user=request.user,
            id__in=selected_keys
        )
        
        if not basket_items.exists():
            return JsonResponse({'success': False, 'error': 'Savatda mahsulot yo\'q'}, status=400)
        
        # Calculate total
        total_price = sum(item.price * item.quantity for item in basket_items)
        
        # Create order
        order = Order.objects.create(
            user=request.user,
            total_price=total_price,
            status='pending'
        )
        
        # Create order items
        for basket_item in basket_items:
            order_item = OrderItem.objects.create(
                variant=basket_item.variant,
                product=basket_item.variant.product,
                width=basket_item.width,
                height=basket_item.height,
                depth=basket_item.depth,
                quantity=basket_item.quantity,
                price=basket_item.price
            )
            order.items.add(order_item)
        
        # Clear cart
        basket_items.delete()
        
        return JsonResponse({
            'success': True,
            'order_id': order.id,
            'message': 'Buyurtmangiz qabul qilindi!',
            'total': float(total_price)
        })
        
    except json.JSONDecodeError:
        return JsonResponse({'success': False, 'error': 'JSON xatosi'}, status=400)
    except Exception as e:
        print(f"Order error: {e}")
        import traceback
        traceback.print_exc()
        return JsonResponse({'success': False, 'error': str(e)}, status=500)


def logout_view(request):
    """Logout"""
    auth_logout(request)
    messages.success(request, "Siz chiqib keldingiz.")
    return redirect("index")
