// Savat — localStorage'da (market portal, tez/oflayn ishlashi uchun), lekin
// foydalanuvchi tizimga kirgan bo'lsa serverga (`/cart-items/`) ham
// ko'chiriladi — bu qurilmalar orasida emas, balki qidiruv/asosiy sahifa
// reytingiga "savatda turgan aktivligi" signali sifatida ishlatiladi
// (qarang backend apps/products/views.py). Har bir lokal band muvaffaqiyatli
// serverga yozilgach `serverId`ni saqlaydi — keyingi o'zgartirish/o'chirish
// shu ID orqali serverga ham yetkaziladi.
import { api, getTokens } from "./api";

const KEY = "cart";

export function getCart() {
  try {
    return JSON.parse(localStorage.getItem(KEY)) || [];
  } catch {
    return [];
  }
}

function save(items) {
  localStorage.setItem(KEY, JSON.stringify(items));
  window.dispatchEvent(new Event("cart-changed"));
}

export function addToCart(item) {
  const items = getCart();
  const same = items.find(
    (i) =>
      i.variantId === item.variantId &&
      i.width === item.width &&
      i.height === item.height &&
      i.depth === item.depth
  );
  if (same) {
    same.qty += item.qty;
    save(items);
    if (same.serverId) {
      api(`/cart-items/${same.serverId}/`, { method: "PATCH", body: { quantity: same.qty } }).catch(() => {});
    } else {
      syncAdd(same, items);
    }
  } else {
    items.push(item);
    save(items);
    syncAdd(item, items);
  }
}

function syncAdd(item, items) {
  if (!getTokens()) return;
  api("/cart-items/", {
    method: "POST",
    body: {
      product: item.productId,
      variant: item.variantId,
      width: item.width,
      height: item.height,
      depth: item.depth,
      quantity: item.qty,
    },
  })
    .then((res) => {
      item.serverId = res.id;
      save(items);
    })
    .catch(() => {});
}

export function removeFromCart(index) {
  const items = getCart();
  const [removed] = items.splice(index, 1);
  save(items);
  if (removed?.serverId) {
    api(`/cart-items/${removed.serverId}/`, { method: "DELETE" }).catch(() => {});
  }
}

export function setQty(index, qty) {
  const items = getCart();
  items[index].qty = Math.max(1, qty);
  save(items);
  const serverId = items[index].serverId;
  if (serverId) {
    api(`/cart-items/${serverId}/`, { method: "PATCH", body: { quantity: items[index].qty } }).catch(() => {});
  }
}

export function clearCart() {
  save([]);
  if (getTokens()) {
    api("/cart-items/clear/", { method: "DELETE" }).catch(() => {});
  }
}

export const itemSubtotal = (i) => Math.round(i.m3Price * i.width * i.height * i.depth * i.qty);
export const cartTotal = (items) => items.reduce((s, i) => s + itemSubtotal(i), 0);
export const cartCount = (items) => items.reduce((s, i) => s + i.qty, 0);
