from django.urls import path
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView

from apps.assets.views import Model3DViewerView, Model3DViewSet
from apps.companies.views import (
    CompanyViewSet,
    EmployeeInvitationViewSet,
    EmployeeViewSet,
    PositionPayStandardViewSet,
    ReviewViewSet,
)
from apps.crm.views import LeadViewSet
from apps.inventory.views import (
    BillOfMaterialViewSet,
    ManufacturedUnitViewSet,
    MaterialMovementViewSet,
    MaterialRemnantViewSet,
    MaterialStockViewSet,
    MaterialViewSet,
    ProduceView,
    ProductMovementViewSet,
    ProductStockViewSet,
    PurchaseOrderViewSet,
    SellUnitsView,
    SupplierViewSet,
    WarehouseViewSet,
)
from apps.cart.views import CartItemViewSet
from apps.likes.views import LikeViewSet
from apps.orders.views import FinanceSummaryView, OrderViewSet
from apps.production.views import PayslipViewSet
from apps.products.views import (
    CategoryViewSet,
    ProductImageViewSet,
    ProductSearchByImageView,
    ProductViewSet,
    VariantViewSet,
)
from apps.projects.views import (
    DetailAssetViewSet,
    ProjectItemViewSet,
    ProjectViewerView,
    ProjectViewSet,
)
from apps.users.views import (
    AdminStatsView,
    AdminTokenObtainPairView,
    AdminUserListView,
    AdminUserToggleActiveView,
    CareerView,
    CompleteRegistrationView,
    GoogleLoginView,
    MeView,
    OTPRequestView,
    OTPVerifyView,
    TelegramBotInfoView,
    TelegramSessionCreateView,
    TelegramSessionPollView,
    TelegramWebhookView,
)
from apps.workflow.views import (
    WorkflowCapacityView,
    WorkflowStatsView,
    WorkflowStepInstanceViewSet,
    WorkflowStepViewSet,
)

router = DefaultRouter()
router.register("companies", CompanyViewSet, basename="company")
router.register("employees", EmployeeViewSet, basename="employee")
router.register("employee-invitations", EmployeeInvitationViewSet, basename="employee-invitation")
router.register("pay-standards", PositionPayStandardViewSet, basename="pay-standard")
router.register("orders", OrderViewSet, basename="order")
router.register("categories", CategoryViewSet, basename="category")
router.register("products", ProductViewSet, basename="product")
router.register("models3d", Model3DViewSet, basename="model3d")
router.register("leads", LeadViewSet, basename="lead")
router.register("payslips", PayslipViewSet, basename="payslip")
router.register("likes", LikeViewSet, basename="like")
router.register("cart-items", CartItemViewSet, basename="cart-item")
router.register("reviews", ReviewViewSet, basename="review")
router.register("workflow-instances", WorkflowStepInstanceViewSet, basename="workflow-instance")
router.register("detail-assets", DetailAssetViewSet, basename="detail-asset")
router.register("projects", ProjectViewSet, basename="project")
router.register("warehouses", WarehouseViewSet, basename="warehouse")
router.register("materials", MaterialViewSet, basename="material")
router.register("suppliers", SupplierViewSet, basename="supplier")
router.register("purchase-orders", PurchaseOrderViewSet, basename="purchase-order")

variant_list = VariantViewSet.as_view({"get": "list", "post": "create"})
variant_detail = VariantViewSet.as_view(
    {"get": "retrieve", "put": "update", "patch": "partial_update", "delete": "destroy"}
)
product_image_list = ProductImageViewSet.as_view({"get": "list", "post": "create"})
product_image_detail = ProductImageViewSet.as_view(
    {"get": "retrieve", "put": "update", "patch": "partial_update", "delete": "destroy"}
)
workflow_step_list = WorkflowStepViewSet.as_view({"get": "list", "post": "create"})
workflow_step_detail = WorkflowStepViewSet.as_view(
    {"get": "retrieve", "put": "update", "patch": "partial_update", "delete": "destroy"}
)
project_item_list = ProjectItemViewSet.as_view({"get": "list", "post": "create"})
project_item_detail = ProjectItemViewSet.as_view(
    {"get": "retrieve", "put": "update", "patch": "partial_update", "delete": "destroy"}
)
material_stock_list = MaterialStockViewSet.as_view({"get": "list"})
material_remnant_list = MaterialRemnantViewSet.as_view({"get": "list"})
material_movement_list = MaterialMovementViewSet.as_view({"get": "list", "post": "create"})
product_stock_list = ProductStockViewSet.as_view({"get": "list"})
product_movement_list = ProductMovementViewSet.as_view({"get": "list", "post": "create"})
bom_list = BillOfMaterialViewSet.as_view({"get": "list", "post": "create"})
bom_detail = BillOfMaterialViewSet.as_view(
    {"get": "retrieve", "put": "update", "patch": "partial_update", "delete": "destroy"}
)
manufactured_unit_list = ManufacturedUnitViewSet.as_view({"get": "list"})

urlpatterns = [
    path("auth/token/", AdminTokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("users/me/", MeView.as_view(), name="me"),
    path("users/me/career/", CareerView.as_view(), name="career"),
    path("users/me/complete-registration/", CompleteRegistrationView.as_view(), name="complete-registration"),
    path("auth/otp/request/", OTPRequestView.as_view(), name="otp-request"),
    path("auth/otp/verify/", OTPVerifyView.as_view(), name="otp-verify"),
    path("auth/google/", GoogleLoginView.as_view(), name="google-login"),
    path("auth/telegram/webhook/", TelegramWebhookView.as_view(), name="telegram-webhook"),
    path("auth/telegram/session/", TelegramSessionCreateView.as_view(), name="telegram-session-create"),
    path(
        "auth/telegram/session/<uuid:session_id>/",
        TelegramSessionPollView.as_view(),
        name="telegram-session-poll",
    ),
    path("auth/telegram/bot-info/", TelegramBotInfoView.as_view(), name="telegram-bot-info"),
    path("admin/stats/", AdminStatsView.as_view(), name="admin-stats"),
    path("admin/users/", AdminUserListView.as_view(), name="admin-users"),
    path(
        "admin/users/<uuid:pk>/toggle-active/",
        AdminUserToggleActiveView.as_view(),
        name="admin-user-toggle-active",
    ),
    path("products/search-by-image/", ProductSearchByImageView.as_view(), name="product-search-by-image"),
    path("products/<uuid:product_pk>/variants/", variant_list, name="variant-list"),
    path("products/<uuid:product_pk>/variants/<uuid:pk>/", variant_detail, name="variant-detail"),
    path("products/<uuid:product_pk>/images/", product_image_list, name="product-image-list"),
    path("products/<uuid:product_pk>/images/<uuid:pk>/", product_image_detail, name="product-image-detail"),
    path("products/<uuid:product_pk>/workflow-steps/", workflow_step_list, name="workflow-step-list"),
    path(
        "products/<uuid:product_pk>/workflow-steps/<uuid:pk>/",
        workflow_step_detail,
        name="workflow-step-detail",
    ),
    path("workflow-stats/", WorkflowStatsView.as_view(), name="workflow-stats"),
    path("workflow-capacity/", WorkflowCapacityView.as_view(), name="workflow-capacity"),
    path("finance/summary/", FinanceSummaryView.as_view(), name="finance-summary"),
    path("viewer/<uuid:token>/", Model3DViewerView.as_view(), name="model3d-viewer"),
    path("projects/<uuid:project_pk>/items/", project_item_list, name="project-item-list"),
    path("projects/<uuid:project_pk>/items/<uuid:pk>/", project_item_detail, name="project-item-detail"),
    path("viewer/project/<uuid:token>/", ProjectViewerView.as_view(), name="project-viewer"),
    path("warehouses/<uuid:warehouse_pk>/material-stocks/", material_stock_list, name="material-stock-list"),
    path("warehouses/<uuid:warehouse_pk>/material-remnants/", material_remnant_list, name="material-remnant-list"),
    path("warehouses/<uuid:warehouse_pk>/material-movements/", material_movement_list, name="material-movement-list"),
    path("warehouses/<uuid:warehouse_pk>/product-stocks/", product_stock_list, name="product-stock-list"),
    path("warehouses/<uuid:warehouse_pk>/product-movements/", product_movement_list, name="product-movement-list"),
    path("warehouses/<uuid:warehouse_pk>/produce/", ProduceView.as_view(), name="warehouse-produce"),
    path("products/<uuid:product_pk>/bill-of-materials/", bom_list, name="bom-list"),
    path("products/<uuid:product_pk>/bill-of-materials/<uuid:pk>/", bom_detail, name="bom-detail"),
    path("products/<uuid:product_pk>/manufactured-units/", manufactured_unit_list, name="manufactured-unit-list"),
    path("products/<uuid:product_pk>/sell-units/", SellUnitsView.as_view(), name="product-sell-units"),
]

urlpatterns += router.urls
