import { BadgeCheck } from "lucide-react";
import { useLocale } from "../locale";

/** Tasdiqlangan firma galochkasi — firma nomi yonida, faqat `verified` bo'lsa. */
export default function VerifiedCheck({ verified, size = 16 }) {
  const { t } = useLocale();
  if (!verified) return null;
  const label = t("company_verified");
  return (
    <span
      className="inline-flex shrink-0 align-middle"
      style={{ color: "var(--info, #2563eb)" }}
      title={label}
      role="img"
      aria-label={label}
    >
      <BadgeCheck size={size} />
    </span>
  );
}
