import { Scissors, Layers, Hammer, Palette, Search, Wrench, Truck, ClipboardList } from "lucide-react";

// Ishlab chiqarish bosqichlari (backend ProductionTask.Stage bilan bir xil)
export const TASK_STAGE = {
  cutting: { label: "Kesish", icon: Scissors },
  edge_processing: { label: "Qirra ishlov", icon: Layers },
  assembly: { label: "Yig'ish", icon: Hammer },
  painting: { label: "Bo'yash", icon: Palette },
  quality_control: { label: "Sifat nazorati", icon: Search },
  installation: { label: "O'rnatish", icon: Wrench },
  delivery: { label: "Yetkazib berish", icon: Truck },
  other: { label: "Boshqa", icon: ClipboardList },
};

export const TASK_STATUS = {
  todo: { label: "Navbatda", color: "#8a8f98" },
  in_progress: { label: "Bajarilmoqda", color: "#f39c12" },
  done: { label: "Bajarildi", color: "#27ae60" },
};

export const TASK_FLOW = ["todo", "in_progress", "done"];
