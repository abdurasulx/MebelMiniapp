import { Clock, CheckCircle2, PenTool, Hammer, Package, Truck, PartyPopper, X } from "lucide-react";

// Buyurtma statuslari (backend Order.Status bilan bir xil)
export const ORDER_STATUS = {
  new: { label: "Kutilmoqda", icon: Clock, color: "#3498db" },
  accepted: { label: "Qabul qilindi", icon: CheckCircle2, color: "#27ae60" },
  // Faqat CUSTOM_PROJECT buyurtmalar uchun (qarang Order.order_type).
  designing: { label: "Loyihalashtirilmoqda", icon: PenTool, color: "#9b59b6" },
  in_production: { label: "Ishlab chiqarilmoqda", icon: Hammer, color: "#e67e22" },
  ready: { label: "Tayyor", icon: Package, color: "#8e44ad" },
  delivering: { label: "Yetkazilmoqda", icon: Truck, color: "#16a085" },
  completed: { label: "Yakunlandi", icon: PartyPopper, color: "#27ae60" },
  cancelled: { label: "Bekor qilindi", icon: X, color: "#e74c3c" },
};

// kompaniya tomonidagi keyingi mumkin qadamlar (backend TRANSITIONS bilan bir xil).
// `designing` faqat CUSTOM_PROJECT uchun ma'noli — chaqiruvchi (FirmaOrderDetail)
// buni `order.order_type`ga qarab filtrlaydi, backend ham qat'iy tekshiradi.
export const NEXT_STATUS = {
  new: ["accepted", "cancelled"],
  accepted: ["designing", "in_production", "cancelled"],
  designing: ["in_production", "cancelled"],
  in_production: ["ready"],
  ready: ["delivering", "completed"],
  delivering: ["completed"],
};

export const FLOW = ["new", "accepted", "in_production", "ready", "delivering", "completed"];

export function StatusBadge({ status }) {
  const s = ORDER_STATUS[status] || { label: status, color: "var(--muted)" };
  const Icon = s.icon;
  return (
    <span
      className="inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-medium"
      style={{ background: `color-mix(in srgb, ${s.color} 14%, transparent)`, color: s.color }}
    >
      {Icon && <Icon size={12} />} {s.label}
    </span>
  );
}
