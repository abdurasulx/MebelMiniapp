import { initializeApp } from "firebase/app";
import { getMessaging, getToken, isSupported, onMessage } from "firebase/messaging";
import { api } from "./api";

// Web push (FCM) — Flutter/Android'dagi `push_service.dart` bilan bir xil
// oqim: qurilma FCM tokenini backend'ga (`/notifications/register_device/`)
// ro'yxatdan o'tkazadi, backend esa buyurtma holati o'zgarganda shu
// token'ga push yuboradi (qarang backend/apps/notifications/push.py).
//
// Firebase konsolida hali "Web app" ro'yxatdan o'tkazilmagan bo'lsa
// (VITE_FIREBASE_* qiymatlari bo'sh) — bu modul jim o'zini o'chiradi, xato
// chiqarmaydi (qolgan ilova ishlashda davom etadi).
const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};
const VAPID_KEY = import.meta.env.VITE_FIREBASE_VAPID_KEY;

function isConfigured() {
  return Boolean(firebaseConfig.apiKey && firebaseConfig.appId && VAPID_KEY);
}

function deviceId() {
  let id = localStorage.getItem("web_device_id");
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem("web_device_id", id);
  }
  return id;
}

/** Login bo'lgach chaqiriladi. `onOrderNotification(orderId)` — ilova ochiq
 * paytida (foreground) buyurtma-holati push kelsa chaqiriladi (masalan
 * bildirishnoma-qo'ng'irog'ini yangilash uchun); fon holatida bosilganda esa
 * to'g'ridan-to'g'ri `firebase-messaging-sw.js` `/orders?highlight=...`ni
 * ochadi. */
export async function initPush(onOrderNotification) {
  if (!isConfigured()) return;
  if (!("serviceWorker" in navigator) || typeof Notification === "undefined") return;
  if (!(await isSupported().catch(() => false))) return;

  try {
    const qs = new URLSearchParams(firebaseConfig).toString();
    const registration = await navigator.serviceWorker.register(
      `/firebase-messaging-sw.js?${qs}`
    );

    const permission = await Notification.requestPermission();
    if (permission !== "granted") return;

    const app = initializeApp(firebaseConfig);
    const messaging = getMessaging(app);
    const token = await getToken(messaging, {
      vapidKey: VAPID_KEY,
      serviceWorkerRegistration: registration,
    });
    if (token) {
      await api("/notifications/register_device/", {
        method: "POST",
        body: { device_id: deviceId(), token, platform: "web" },
      });
    }

    onMessage(messaging, (payload) => {
      const data = payload.data || {};
      if (data.type === "order_status" && onOrderNotification) {
        onOrderNotification(data.order_id);
      }
    });
  } catch (e) {
    console.warn("Web push ishga tushmadi", e);
  }
}
