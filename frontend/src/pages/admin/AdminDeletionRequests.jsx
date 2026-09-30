import { useEffect, useState } from "react";
import { Check, X } from "lucide-react";
import { api } from "../../api";

const STATUS_LABEL = {
  pending: "Kutilmoqda",
  approved: "Tasdiqlandi",
  rejected: "Rad etildi",
};

export default function AdminDeletionRequests() {
  const [requests, setRequests] = useState([]);
  const [status, setStatus] = useState("pending");
  const [error, setError] = useState("");
  const [busyId, setBusyId] = useState(null);

  const load = () => {
    api(`/admin/deletion-requests/?status=${status}`)
      .then((d) => setRequests(d.results || d || []))
      .catch((e) => setError(e.message));
  };

  useEffect(load, [status]);

  const review = async (id, action) => {
    if (action === "approve" && !confirm("Ushbu hisobni o'chirish tasdiqlansinmi? Bu amalni qaytarib bo'lmaydi.")) return;
    setBusyId(id);
    setError("");
    try {
      await api(`/admin/deletion-requests/${id}/${action}/`, { method: "POST" });
      load();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusyId(null);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap gap-3">
        <select className="input max-w-[200px]" value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="pending">Kutilmoqda</option>
          <option value="approved">Tasdiqlangan</option>
          <option value="rejected">Rad etilgan</option>
          <option value="all">Hammasi</option>
        </select>
      </div>
      {error && <div className="error">{error}</div>}
      <div className="table-wrap">
        <table className="table">
          <thead>
            <tr>
              <th>Foydalanuvchi</th>
              <th>Sabab</th>
              <th>Holati</th>
              <th>So'ralgan</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {requests.map((r) => (
              <tr key={r.id}>
                <td className="font-medium">
                  {r.user_display_name}
                  <div className="text-xs" style={{ color: "var(--muted)" }}>{r.user_email}</div>
                </td>
                <td className="max-w-xs">{r.reason}</td>
                <td>
                  <span className={r.status === "pending" ? "badge badge-brand" : r.status === "approved" ? "badge badge-off" : "badge"}>
                    {STATUS_LABEL[r.status] || r.status}
                  </span>
                </td>
                <td>{new Date(r.created_at).toLocaleDateString("uz-UZ")}</td>
                <td>
                  {r.status === "pending" && (
                    <div className="flex gap-2">
                      <button
                        className="btn-danger inline-flex items-center gap-1 !px-3 !py-1.5 text-xs"
                        disabled={busyId === r.id}
                        onClick={() => review(r.id, "approve")}
                      >
                        <Check size={12} /> Tasdiqlash
                      </button>
                      <button
                        className="btn-ghost inline-flex items-center gap-1 !px-3 !py-1.5 text-xs"
                        disabled={busyId === r.id}
                        onClick={() => review(r.id, "reject")}
                      >
                        <X size={12} /> Rad etish
                      </button>
                    </div>
                  )}
                </td>
              </tr>
            ))}
            {requests.length === 0 && (
              <tr>
                <td colSpan={5} className="py-6 text-center" style={{ color: "var(--muted)" }}>
                  So'rov yo'q
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
