from .models import Notification, NotificationType


def notify_order_status(order):
    """Mijozga buyurtma holati o'zgarganda yuboriladi (qarang
    apps.orders.views.OrderViewSet.set_status)."""
    if not order.customer_id:
        return
    Notification.objects.create(
        recipient_id=order.customer_id,
        notif_type=NotificationType.ORDER_STATUS,
        title="Buyurtma holati yangilandi",
        body=f"Buyurtmangiz holati: {order.get_status_display()}",
        order=order,
    )


def notify_task_assigned(step):
    """Xodimga qo'lda vazifa tayinlanganda yuboriladi (qarang
    apps.workflow.views.WorkflowStepInstanceViewSet.perform_create)."""
    if not step.employee_id or not step.employee.user_id:
        return
    Notification.objects.create(
        recipient_id=step.employee.user_id,
        notif_type=NotificationType.TASK_ASSIGNED,
        title="Sizga yangi vazifa tayinlandi",
        body=step.name,
        workflow_instance=step,
    )


def notify_task_available(step):
    """Bog'liq bosqich tugab, keyingi bosqich boshlanishga tayyor bo'lganda
    biriktirilgan xodimga yuboriladi (qarang
    apps.workflow.views.WorkflowStepInstanceViewSet.complete)."""
    if not step.employee_id or not step.employee.user_id:
        return
    Notification.objects.create(
        recipient_id=step.employee.user_id,
        notif_type=NotificationType.TASK_AVAILABLE,
        title="Vazifa boshlashga tayyor",
        body=step.name,
        workflow_instance=step,
    )
