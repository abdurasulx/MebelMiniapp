from .models import Notification, NotificationType
from .push import send_push
from .ws import push_unread_count


def notify_order_status(order):
    """Mijozga buyurtma holati o'zgarganda yuboriladi (qarang
    apps.orders.views.OrderViewSet.set_status)."""
    if not order.customer_id:
        return
    title = "Buyurtma holati yangilandi"
    body = f"Buyurtmangiz holati: {order.get_status_display()}"
    Notification.objects.create(
        recipient_id=order.customer_id,
        notif_type=NotificationType.ORDER_STATUS,
        title=title,
        body=body,
        order=order,
    )
    send_push(order.customer, title, body, data={"type": "order_status", "order_id": str(order.id)})
    push_unread_count(order.customer_id)


def notify_task_assigned(step):
    """Xodimga qo'lda vazifa tayinlanganda yuboriladi (qarang
    apps.workflow.views.WorkflowStepInstanceViewSet.perform_create)."""
    if not step.employee_id or not step.employee.user_id:
        return
    title = "Sizga yangi vazifa tayinlandi"
    Notification.objects.create(
        recipient_id=step.employee.user_id,
        notif_type=NotificationType.TASK_ASSIGNED,
        title=title,
        body=step.name,
        workflow_instance=step,
    )
    send_push(step.employee.user, title, step.name, data={"type": "task_assigned", "step_id": str(step.id)})
    push_unread_count(step.employee.user_id)


def notify_pool_open(step):
    """Xodimi biriktirilmagan ("erkin") bosqich boshlanishga tayyor bo'lganda
    (bog'liq bosqichlar tugagach yoki buyurtma yaratilganda) mos lavozimdagi
    BARCHA faol xodimlarga yuboriladi — ular ilovada bu topshiriqni ko'rib,
    zayavka yubora oladi (qarang apps.workflow.views::open/apply)."""
    if not step.role or not step.company_id:
        return
    from apps.companies.models import Employee

    candidates = list(
        Employee.objects.filter(
            company_id=step.company_id, is_active=True, positions__contains=[step.role]
        ).select_related("user")
    )
    Notification.objects.bulk_create(
        [
            Notification(
                recipient_id=emp.user_id,
                notif_type=NotificationType.TASK_POOL_OPEN,
                title="Yangi erkin topshiriq",
                body=step.name,
                workflow_instance=step,
            )
            for emp in candidates
            if emp.user_id
        ]
    )
    for emp in candidates:
        if emp.user_id:
            send_push(
                emp.user, "Yangi erkin topshiriq", step.name,
                data={"type": "task_pool_open", "step_id": str(step.id)},
            )
            push_unread_count(emp.user_id)


def notify_application_rejected(application):
    """Boshqa usta tanlanganda, tasdiqlanmagan zayavka egalariga yuboriladi."""
    if not application.employee.user_id:
        return
    title = "Zayavkangiz rad etildi"
    body = f"{application.step.name} — boshqa usta tanlandi"
    Notification.objects.create(
        recipient_id=application.employee.user_id,
        notif_type=NotificationType.TASK_APPLICATION_REJECTED,
        title=title,
        body=body,
        workflow_instance=application.step,
    )
    send_push(application.employee.user, title, body, data={"type": "task_application_rejected"})
    push_unread_count(application.employee.user_id)


def notify_attendance_rejected(employee, reason):
    """Davomat (ishga kelish/ketish) rad etilganda yoki shubhali deb
    belgilanganda xodimga yuboriladi (qarang apps.attendance.services)."""
    if not employee.user_id:
        return
    title = "Davomat tasdiqlanmadi"
    body = reason
    Notification.objects.create(
        recipient_id=employee.user_id,
        notif_type=NotificationType.ATTENDANCE_REJECTED,
        title=title,
        body=body,
    )
    send_push(employee.user, title, body, data={"type": "attendance_rejected"})
    push_unread_count(employee.user_id)


def notify_material_suggestion(user, material, remnant_width, remnant_length, cut_width, cut_length):
    """Ishlab chiqarishda VARAQ material kerakli bo'lakka mavjud qoldiqdan
    moslashtirilganda yuboriladi — kimga qaysi o'lchamdagi qoldiqdan
    foydalanilgani (isrofni kamaytirish uchun) ma'lum bo'lishi uchun
    (qarang apps.inventory.views._consume_cut_pieces/ProduceView)."""
    title = "Material qoldig'idan foydalanildi"
    body = (
        f"{material.name}: {cut_width}x{cut_length}{material.unit} bo'lak uchun omborda "
        f"{remnant_width}x{remnant_length}{material.unit} qoldiq topilib ishlatildi — "
        "isrofgarchilik kamaydi."
    )
    Notification.objects.create(
        recipient=user,
        notif_type=NotificationType.MATERIAL_SUGGESTION,
        title=title,
        body=body,
    )
    send_push(user, title, body, data={"type": "material_suggestion"})
    push_unread_count(user.id)


def notify_task_available(step):
    """Bog'liq bosqich tugab, keyingi bosqich boshlanishga tayyor bo'lganda
    biriktirilgan xodimga yuboriladi (qarang
    apps.workflow.views.WorkflowStepInstanceViewSet.complete)."""
    if not step.employee_id or not step.employee.user_id:
        return
    title = "Vazifa boshlashga tayyor"
    Notification.objects.create(
        recipient_id=step.employee.user_id,
        notif_type=NotificationType.TASK_AVAILABLE,
        title=title,
        body=step.name,
        workflow_instance=step,
    )
    send_push(step.employee.user, title, step.name, data={"type": "task_available", "step_id": str(step.id)})
    push_unread_count(step.employee.user_id)
