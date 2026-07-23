import { Hammer, ShoppingCart, Wrench, Palette, Package, Truck, ClipboardList } from "lucide-react";

// Mebel firmasi xodim kasblari (backend: Employee.Position bilan bir xil)
export const POSITIONS = {
  usta: { label: "Usta", icon: Hammer, desc: "Ishlab chiqarish" },
  sotuvchi: { label: "Sotuvchi", icon: ShoppingCart, desc: "Savdo va mijozlar" },
  ornatuvchi: { label: "O'rnatuvchi", icon: Wrench, desc: "Montaj va o'rnatish" },
  dizayner: { label: "Dizayner", icon: Palette, desc: "Loyiha va dizayn" },
  omborchi: { label: "Omborchi", icon: Package, desc: "Ombor va materiallar" },
  haydovchi: { label: "Yetkazib beruvchi", icon: Truck, desc: "Yetkazib berish" },
  menejer: { label: "Menejer", icon: ClipboardList, desc: "Boshqaruv" },
};

const KEY = "active_position";

export const getActivePosition = () => localStorage.getItem(KEY);
export const setActivePosition = (p) =>
  p ? localStorage.setItem(KEY, p) : localStorage.removeItem(KEY);
