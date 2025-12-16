from django import forms
from .models import Product, Variant, Category, VariantImage
# forms.py
from django import forms
from .models import Product, Variant

class ProductForm(forms.ModelForm):
    class Meta:
        model = Product
        fields = ['name_uz', 'name_ru', 'category', 'image', 'video_url']
        widgets = {
            'name_uz': forms.TextInput(attrs={'class': 'w-full p-3 border rounded-lg', 'required': True}),
            'name_ru': forms.TextInput(attrs={'class': 'w-full p-3 border rounded-lg'}),
            'category': forms.Select(attrs={'class': 'w-full p-3 border rounded-lg'}),
            'image': forms.FileInput(attrs={'class': 'w-full p-3'}),
            'video_url': forms.URLInput(attrs={'class': 'w-full p-3 border rounded-lg', 'placeholder': 'https://youtube.com/...'}),
        }

# forms.py
VariantFormSet = forms.inlineformset_factory(
    Product, Variant,
    fields=('name', 'base_price', 'width', 'depth', 'height'),
    extra=1,
    can_delete=True,
    widgets={
        'name': forms.TextInput(attrs={'class': 'w-full p-3 border rounded-lg'}),
        'base_price': forms.NumberInput(attrs={'class': 'w-full p-3 border rounded-lg', 'step': '0.01'}),
        'width': forms.NumberInput(attrs={'class': 'w-full p-3 border rounded-lg', 'step': '0.01'}),
        'depth': forms.NumberInput(attrs={'class': 'w-full p-3 border rounded-lg', 'step': '0.01'}),
        'height': forms.NumberInput(attrs={'class': 'w-full p-3 border rounded-lg', 'step': '0.01'}),
    }
)

# Variant rasmlari uchun formset
VariantImageFormSet = forms.inlineformset_factory(
    Variant, VariantImage,
    fields=('image',),
    extra=1,
    can_delete=True,
    widgets={
        'image': forms.FileInput(attrs={'class': 'w-full p-3 border rounded-lg', 'accept': 'image/*'}),
    }
)
# forms.py

class CategoryForm(forms.ModelForm):
    class Meta:
        model = Category
        fields = ['name_uz', 'name_ru', 'image']
        widgets = {
            'name_uz': forms.TextInput(attrs={
                'class': 'w-full px-4 py-3 border rounded-lg '
                         'border-gray-300 dark:border-gray-600 '
                         'bg-white dark:bg-gray-700 '
                         'text-gray-900 dark:text-gray-100 '
                         'focus:ring-2 focus:ring-primary',
                'placeholder': 'Masalan: Yumshoq mebellar'
            }),
            'name_ru': forms.TextInput(attrs={
                'class': 'w-full px-4 py-3 border rounded-lg '
                         'border-gray-300 dark:border-gray-600 '
                         'bg-white dark:bg-gray-700 '
                         'text-gray-900 dark:text-gray-100',
                'placeholder': 'Например: Мягкая мебель'
            }),
            'image': forms.FileInput(attrs={
                'class': 'w-full px-4 py-3 border rounded-lg '
                         'border-gray-300 dark:border-gray-600 '
                         'bg-white dark:bg-gray-700 '
                         'text-gray-900 dark:text-gray-100 '
                         'cursor-pointer'
            }),
        }
