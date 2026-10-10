import { BRAND_NAME } from "../portal";

/** "VIDA" qalin, qolgan qismi ("Market"/"ERP"/"Admin") yengil va xira. */
export default function BrandLogo({ className = "" }) {
  const [first, ...rest] = BRAND_NAME.split(" ");
  return (
    <span className={`brand-logo ${className}`}>
      <b>{first}</b>
      {rest.length > 0 && <span> {rest.join(" ").toLowerCase()}</span>}
    </span>
  );
}
