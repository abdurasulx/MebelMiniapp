from django.urls import path
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView

from apps.ar_collections.views import ARCollectionItemViewSet, ARCollectionViewSet
from apps.attendance.views import AttendanceRecordViewSet, WorkplaceViewSet
from apps.custom_orders.views import (
    BazisPreviewView,
    CustomOrderCreateView,
    DesignBazisImportView,
    DesignVersionViewSet,
    DesignViewSet,
    OrderItemCostViewSet,
)
from apps.assets.views import Model3DViewerView, Model3DViewSet
from apps.companies.views import (
    CompanyViewSet,
    EmployeeInvitationViewSet,
    EmployeeViewSet,
    ReviewViewSet,
    TariffPlanViewSet,
)
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
from apps.notifications.views import NotificationViewSet
from apps.orders.views import DashboardMetricsView, FinanceSummaryView, OrderViewSet
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
    FirmaTokenObtainPairView,
    GoogleLinkCallbackView,
    GoogleLinkPrepareView,
    GoogleLinkStartView,
    GoogleLinkView,
    GoogleLoginCallbackView,
    GoogleLoginStartView,
    GoogleLoginView,
    MeView,
    OTPRequestView,
    OTPVerifyView,
    PhoneVerifyConfirmView,
    PhoneVerifyRequestView,
    TelegramBotInfoView,
    TelegramLinkSessionCreateView,
    TelegramLinkSessionPollView,
    TelegramSessionCreateView,
    TelegramSessionPollView,
    TelegramWebhookView,
)
from apps.workflow.views import (
    WorkflowCapacityView,
    WorkflowStatsView,
    WorkflowStepBazisImportView,
    WorkflowStepInstanceViewSet,
    WorkflowStepViewSet,
    WorkTypeViewSet,
)

router = DefaultRouter()
router.register("companies", CompanyViewSet, basename="company")
router.register("employees", EmployeeViewSet, basename="employee")
router.register("employee-invitations", EmployeeInvitationViewSet, basename="employee-invitation")
router.register("tariff-plans", TariffPlanViewSet, basename="tariff-plan")
router.register("orders", OrderViewSet, basename="order")
router.register("categories", CategoryViewSet, basename="category")
router.register("products", ProductViewSet, basename="product")
router.register("models3d", Model3DViewSet, basename="model3d")
router.register("payslips", PayslipViewSet, basename="payslip")
router.register("likes", LikeViewSet, basename="like")
router.register("notifications", NotificationViewSet, basename="notification")
router.register("ar-collections", ARCollectionViewSet, basename="ar-collection")
router.register("cart-items", CartItemViewSet, basename="cart-item")
router.register("reviews", ReviewViewSet, basename="review")
router.register("workflow-instances", WorkflowStepInstanceViewSet, basename="workflow-instance")
router.register("work-types", WorkTypeViewSet, basename="work-type")
router.register("detail-assets", DetailAssetViewSet, basename="detail-asset")
router.register("projects", ProjectViewSet, basename="project")
router.register("warehouses", WarehouseViewSet, basename="warehouse")
router.register("materials", MaterialViewSet, basename="material")
router.register("suppliers", SupplierViewSet, basename="supplier")
router.register("purchase-orders", PurchaseOrderViewSet, basename="purchase-order")
router.register("attendance/workplaces", WorkplaceViewSet, basename="workplace")
router.register("attendance/records", AttendanceRecordViewSet, basename="attendance-record")
router.register("designs", DesignViewSet, basename="design")
router.register("design-versions", DesignVersionViewSet, basename="design-version")
router.register("order-item-cost", OrderItemCostViewSet, basename="order-item-cost")

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
material_remnant_receive = MaterialRemnantViewSet.as_view({"post": "receive"})
material_movement_list = MaterialMovementViewSet.as_view({"get": "list", "post": "create"})
product_stock_list = ProductStockViewSet.as_view({"get": "list"})
product_movement_list = ProductMovementViewSet.as_view({"get": "list", "post": "create"})
bom_list = BillOfMaterialViewSet.as_view({"get": "list", "post": "create"})
bom_detail = BillOfMaterialViewSet.as_view(
    {"get": "retrieve", "put": "update", "patch": "partial_update", "delete": "destroy"}
)
manufactured_unit_list = ManufacturedUnitViewSet.as_view({"get": "list"})
ar_collection_item_list = ARCollectionItemViewSet.as_view({"get": "list", "post": "create"})
ar_collection_item_detail = ARCollectionItemViewSet.as_view({"delete": "destroy"})

urlpatterns = [
    path("auth/token/", AdminTokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("auth/token/firma/", FirmaTokenObtainPairView.as_view(), name="firma_token_obtain_pair"),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("users/me/", MeView.as_view(), name="me"),
    path("users/me/career/", CareerView.as_view(), name="career"),
    path("users/me/complete-registration/", CompleteRegistrationView.as_view(), name="complete-registration"),
    path("users/me/phone/request-otp/", PhoneVerifyRequestView.as_view(), name="phone-verify-request"),
    path("users/me/phone/verify-otp/", PhoneVerifyConfirmView.as_view(), name="phone-verify-confirm"),
    path("auth/otp/request/", OTPRequestView.as_view(), name="otp-request"),
    path("auth/otp/verify/", OTPVerifyView.as_view(), name="otp-verify"),
    path("auth/google/", GoogleLoginView.as_view(), name="google-login"),
    path("auth/google/start/", GoogleLoginStartView.as_view(), name="google-login-start"),
    path("auth/google/callback/", GoogleLoginCallbackView.as_view(), name="google-login-callback"),
    path("auth/telegram/webhook/", TelegramWebhookView.as_view(), name="telegram-webhook"),
    path("auth/telegram/session/", TelegramSessionCreateView.as_view(), name="telegram-session-create"),
    path(
        "auth/telegram/session/<uuid:session_id>/",
        TelegramSessionPollView.as_view(),
        name="telegram-session-poll",
    ),
    path("auth/telegram/bot-info/", TelegramBotInfoView.as_view(), name="telegram-bot-info"),
    path("users/me/google/link/", GoogleLinkView.as_view(), name="google-link"),
    path("users/me/google/link/prepare/", GoogleLinkPrepareView.as_view(), name="google-link-prepare"),
    path("auth/google/link/start/", GoogleLinkStartView.as_view(), name="google-link-start"),
    path("auth/google/link/callback/", GoogleLinkCallbackView.as_view(), name="google-link-callback"),
    path(
        "users/me/telegram/link/session/",
        TelegramLinkSessionCreateView.as_view(),
        name="telegram-link-session-create",
    ),
    path(
        "users/me/telegram/link/session/<uuid:session_id>/",
        TelegramLinkSessionPollView.as_view(),
        name="telegram-link-session-poll",
    ),
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
        "products/<uuid:product_pk>/workflow-steps/import-bazis/",
        WorkflowStepBazisImportView.as_view(),
        name="workflow-step-import-bazis",
    ),
    path(
        "products/<uuid:product_pk>/workflow-steps/<uuid:pk>/",
        workflow_step_detail,
        name="workflow-step-detail",
    ),
    path("workflow-stats/", WorkflowStatsView.as_view(), name="workflow-stats"),
    path("workflow-capacity/", WorkflowCapacityView.as_view(), name="workflow-capacity"),
    path("finance/summary/", FinanceSummaryView.as_view(), name="finance-summary"),
    path("dashboard/metrics/", DashboardMetricsView.as_view(), name="dashboard-metrics"),
    path("viewer/<uuid:token>/", Model3DViewerView.as_view(), name="model3d-viewer"),
    path("projects/<uuid:project_pk>/items/", project_item_list, name="project-item-list"),
    path("projects/<uuid:project_pk>/items/<uuid:pk>/", project_item_detail, name="project-item-detail"),
    path("viewer/project/<uuid:token>/", ProjectViewerView.as_view(), name="project-viewer"),
    path("warehouses/<uuid:warehouse_pk>/material-stocks/", material_stock_list, name="material-stock-list"),
    path("warehouses/<uuid:warehouse_pk>/material-remnants/", material_remnant_list, name="material-remnant-list"),
    path(
        "warehouses/<uuid:warehouse_pk>/material-remnants/receive/",
        material_remnant_receive,
        name="material-remnant-receive",
    ),
    path("warehouses/<uuid:warehouse_pk>/material-movements/", material_movement_list, name="material-movement-list"),
    path("warehouses/<uuid:warehouse_pk>/product-stocks/", product_stock_list, name="product-stock-list"),
    path("warehouses/<uuid:warehouse_pk>/product-movements/", product_movement_list, name="product-movement-list"),
    path("warehouses/<uuid:warehouse_pk>/produce/", ProduceView.as_view(), name="warehouse-produce"),
    path("products/<uuid:product_pk>/bill-of-materials/", bom_list, name="bom-list"),
    path("products/<uuid:product_pk>/bill-of-materials/<uuid:pk>/", bom_detail, name="bom-detail"),
    path("products/<uuid:product_pk>/manufactured-units/", manufactured_unit_list, name="manufactured-unit-list"),
    path("products/<uuid:product_pk>/sell-units/", SellUnitsView.as_view(), name="product-sell-units"),
    path(
        "ar-collections/<uuid:collection_pk>/items/",
        ar_collection_item_list,
        name="ar-collection-item-list",
    ),
    path(
        "ar-collections/<uuid:collection_pk>/items/<uuid:pk>/",
        ar_collection_item_detail,
        name="ar-collection-item-detail",
    ),
    path("custom-orders/create/", CustomOrderCreateView.as_view(), name="custom-order-create"),
    path("custom-orders/parse-bazis/", BazisPreviewView.as_view(), name="custom-order-parse-bazis"),
    path(
        "custom-orders/<uuid:order_id>/import-bazis/",
        DesignBazisImportView.as_view(),
        name="custom-order-import-bazis",
    ),
]

urlpatterns += router.urls
