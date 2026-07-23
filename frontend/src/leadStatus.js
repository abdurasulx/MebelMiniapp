import { Sparkles, Phone, Ruler, FileText, PartyPopper, X, MessageSquare, Car, NotebookPen } from "lucide-react";

// Lead pipeline statuslari (backend Lead.Status bilan bir xil)
export const LEAD_STATUS = {
  new: { label: "Yangi", icon: Sparkles, color: "#3498db" },
  contacted: { label: "Bog'lanildi", icon: Phone, color: "#f39c12" },
  measurement: { label: "O'lchov rejalashtirildi", icon: Ruler, color: "#8e44ad" },
  offer_sent: { label: "Taklif yuborildi", icon: FileText, color: "#16a085" },
  won: { label: "Yutildi", icon: PartyPopper, color: "#27ae60" },
  lost: { label: "Yo'qotildi", icon: X, color: "#e74c3c" },
};

export const PIPELINE = ["new", "contacted", "measurement", "offer_sent", "won"];

export const LEAD_SOURCE = {
  website: "Sayt",
  instagram: "Instagram",
  telegram: "Telegram",
  referral: "Tavsiya",
  ad: "Reklama",
  other: "Boshqa",
};

export const NOTE_KIND = {
  call: { label: "Qo'ng'iroq", icon: Phone },
  message: { label: "Xabar", icon: MessageSquare },
  visit: { label: "Tashrif", icon: Car },
  note: { label: "Izoh", icon: NotebookPen },
};
