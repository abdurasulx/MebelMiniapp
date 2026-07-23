// Savat — localStorage'da (market portal). Buyurtma berilganda API'ga yuboriladi.
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
  if (same) same.qty += item.qty;
  else items.push(item);
  save(items);
}

export function removeFromCart(index) {
  const items = getCart();
  items.splice(index, 1);
  save(items);
}

export function setQty(index, qty) {
  const items = getCart();
  items[index].qty = Math.max(1, qty);
  save(items);
}

export function clearCart() {
  save([]);
}

export const itemSubtotal = (i) => Math.round(i.m3Price * i.width * i.height * i.depth * i.qty);
export const cartTotal = (items) => items.reduce((s, i) => s + itemSubtotal(i), 0);
export const cartCount = (items) => items.reduce((s, i) => s + i.qty, 0);
