from decimal import Decimal

from rest_framework import serializers

from apps.products.models import Variant
from apps.workflow.serializers import WorkflowStepInstanceSerializer
from apps.workflow.services import create_workflow_instances

from .models import Order, OrderItem


class OrderItemInputSerializer(serializers.Serializer):
    variant = serializers.UUIDField()
    width = serializers.DecimalField(max_digits=6, decimal_places=2, min_value=Decimal("0.1"))
    height = serializers.DecimalField(max_digits=6, decimal_places=2, min_value=Decimal("0.1"))
    depth = serializers.DecimalField(max_digits=6, decimal_places=2, min_value=Decimal("0.1"))
    quantity = serializers.IntegerField(min_value=1, default=1)


class OrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrderItem
        fields = (
            "id", "product", "variant", "product_name", "variant_name",
            "width", "height", "depth", "quantity", "unit_m3_price", "subtotal",
        )


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    company_name = serializers.CharField(source="company.name", read_only=True)
    customer_email = serializers.EmailField(source="customer.email", read_only=True)
    customer_name = serializers.CharField(source="customer.first_name", read_only=True)
    workflow_steps = serializers.SerializerMethodField()
    production_cost = serializers.SerializerMethodField()
    progress_percent = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = (
            "id", "company", "company_name", "customer", "customer_email", "customer_name",
            "status", "status_display", "phone", "address", "note",
            "total_price", "items", "workflow_steps", "production_cost", "progress_percent",
            "created_at", "updated_at",
        )
        read_only_fields = fields

    def _steps(self, obj):
        if not hasattr(obj, "_prefetched_workflow_steps"):
            obj._prefetched_workflow_steps = list(
                obj.workflow_steps.filter(is_deleted=False)
                .select_related("employee__user", "completed_by")
                .prefetch_related("depends_on", "updates")
                .order_by("order_index")
            )
        return obj._prefetched_workflow_steps

    def get_workflow_steps(self, obj):
        return WorkflowStepInstanceSerializer(
            self._steps(obj), many=True, context=self.context
        ).data

    def get_production_cost(self, obj):
        steps = self._steps(obj)
        labor_cost = sum((s.cost for s in steps), Decimal("0"))
        total_price = obj.total_price or Decimal("0")
        return {
            "labor_cost": labor_cost,
            "total_cost": labor_cost,
            "selling_price": total_price,
            "profit": total_price - labor_cost,
        }

    def get_progress_percent(self, obj):
        steps = self._steps(obj)
        if not steps:
            return None
        done = sum(1 for s in steps if s.status == "completed")
        return round(done / len(steps) * 100)


class OrderCreateSerializer(serializers.Serializer):
    """Buyurtma yaratish: variantlar bitta kompaniyaniki bo'lishi shart,
    narx serverda variantning m³ narxidan hisoblanadi (snapshot)."""

    phone = serializers.CharField(max_length=20)
    address = serializers.CharField(max_length=500)
    note = serializers.CharField(required=False, allow_blank=True, default="")
    items = OrderItemInputSerializer(many=True, allow_empty=False)

    def validate(self, data):
        variant_ids = [i["variant"] for i in data["items"]]
        variants = {
            str(v.id): v
            for v in Variant.objects.filter(
                id__in=variant_ids, is_deleted=False
            ).select_related("product__company")
        }
        if len(variants) != len(set(map(str, variant_ids))):
            raise serializers.ValidationError("Ba'zi variantlar topilmadi")

        companies = {v.product.company_id for v in variants.values()}
        if len(companies) != 1:
            raise serializers.ValidationError(
                "Bitta buyurtmada faqat bitta kompaniya mahsulotlari bo'ladi"
            )
        for v in variants.values():
            if not v.product.is_published:
                raise serializers.ValidationError(f"{v.product.name_uz} sotuvda emas")

        data["_variants"] = variants
        data["_company_id"] = companies.pop()
        return data

    def create(self, validated_data):
        variants = validated_data["_variants"]
        order = Order.objects.create(
            company_id=validated_data["_company_id"],
            customer=self.context["request"].user,
            phone=validated_data["phone"],
            address=validated_data["address"],
            note=validated_data.get("note", ""),
        )
        total = Decimal("0")
        for item in validated_data["items"]:
            v = variants[str(item["variant"])]
            volume = item["width"] * item["height"] * item["depth"]
            subtotal = (v.base_price * volume * item["quantity"]).quantize(Decimal("0.01"))
            OrderItem.objects.create(
                order=order,
                product=v.product,
                variant=v,
                product_name=v.product.name_uz,
                variant_name=v.name,
                width=item["width"],
                height=item["height"],
                depth=item["depth"],
                quantity=item["quantity"],
                unit_m3_price=v.base_price,
                subtotal=subtotal,
            )
            total += subtotal
        order.total_price = total
        order.save(update_fields=["total_price"])

        # Ishlab chiqarish jarayoni birinchi banddagi mahsulotning workflow
        # shablonidan nusxalanadi (Order Workflow — odatda buyurtma bitta mebelga tegishli).
        first_item = validated_data["items"][0]
        first_product = variants[str(first_item["variant"])].product
        create_workflow_instances(order, first_product)

        return order

    def to_representation(self, instance):
        return OrderSerializer(instance, context=self.context).data
