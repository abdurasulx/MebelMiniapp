from django.urls import path
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from apps.assets.views import Model3DViewerView, Model3DViewSet
from apps.companies.views import (
    BranchViewSet,
    CompanyViewSet,
    EmployeeInvitationViewSet,
    EmployeeViewSet,
    ReviewViewSet,
)
from apps.crm.views import LeadViewSet
from apps.likes.views import LikeViewSet
from apps.orders.views import OrderViewSet
from apps.production.views import PayslipViewSet, ProductionTaskViewSet
from apps.products.views import (
    CategoryViewSet,
    ProductImageViewSet,
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
    AdminUserListView,
    CareerView,
    MeView,
    OTPRequestView,
    OTPVerifyView,
    RegisterView,
)
from apps.workflow.views import (
    WorkflowStatsView,
    WorkflowStepInstanceViewSet,
    WorkflowStepViewSet,
)

router = DefaultRouter()
router.register("companies", CompanyViewSet, basename="company")
router.register("employees", EmployeeViewSet, basename="employee")
router.register("employee-invitations", EmployeeInvitationViewSet, basename="employee-invitation")
router.register("orders", OrderViewSet, basename="order")
router.register("categories", CategoryViewSet, basename="category")
router.register("products", ProductViewSet, basename="product")
router.register("models3d", Model3DViewSet, basename="model3d")
router.register("leads", LeadViewSet, basename="lead")
router.register("tasks", ProductionTaskViewSet, basename="task")
router.register("payslips", PayslipViewSet, basename="payslip")
router.register("likes", LikeViewSet, basename="like")
router.register("reviews", ReviewViewSet, basename="review")
router.register("branches", BranchViewSet, basename="branch")
router.register("workflow-instances", WorkflowStepInstanceViewSet, basename="workflow-instance")
router.register("detail-assets", DetailAssetViewSet, basename="detail-asset")
router.register("projects", ProjectViewSet, basename="project")

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

urlpatterns = [
    path("auth/register/", RegisterView.as_view(), name="register"),
    path("auth/token/", TokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("users/me/", MeView.as_view(), name="me"),
    path("users/me/career/", CareerView.as_view(), name="career"),
    path("auth/otp/request/", OTPRequestView.as_view(), name="otp-request"),
    path("auth/otp/verify/", OTPVerifyView.as_view(), name="otp-verify"),
    path("admin/stats/", AdminStatsView.as_view(), name="admin-stats"),
    path("admin/users/", AdminUserListView.as_view(), name="admin-users"),
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
    path("viewer/<uuid:token>/", Model3DViewerView.as_view(), name="model3d-viewer"),
    path("projects/<uuid:project_pk>/items/", project_item_list, name="project-item-list"),
    path("projects/<uuid:project_pk>/items/<uuid:pk>/", project_item_detail, name="project-item-detail"),
    path("viewer/project/<uuid:token>/", ProjectViewerView.as_view(), name="project-viewer"),
]

urlpatterns += router.urls
