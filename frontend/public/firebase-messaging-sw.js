// Firebase Cloud Messaging — fon (background) push xabarnomalari uchun
// service worker. Ilova ochiq bo'lmaganda ham OS xabarnoma tokchasiga
// chiqarish va bosilganda tegishli sahifani ochish shu yerda amalga oshadi
// (ilova ochiq bo'lganida esa `src/push.js`dagi `onMessage` ishlaydi).
//
// Config qiymatlari build vaqtida emas, ro'yxatdan o'tkazish (`register`)
// paytida URL query orqali beriladi (qarang `src/push.js`), chunki bu fayl
// `public/`dan xom holda serve qilinadi — Vite uni ishlab chiqmaydi.
importScripts("https://www.gstatic.com/firebasejs/12.3.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/12.3.0/firebase-messaging-compat.js");

const params = new URLSearchParams(self.location.search);
firebase.initializeApp({
  apiKey: params.get("apiKey"),
  authDomain: params.get("authDomain"),
  projectId: params.get("projectId"),
  messagingSenderId: params.get("messagingSenderId"),
  appId: params.get("appId"),
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const data = payload.data || {};
  const title = payload.notification?.title || data.title || "Yangi bildirishnoma";
  const body = payload.notification?.body || data.body || "";
  self.registration.showNotification(title, {
    body,
    icon: "/favicon.svg",
    data,
  });
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const data = event.notification.data || {};
  let url = "/";
  if (data.type === "order_status" && data.order_id) {
    url = `/orders?highlight=${data.order_id}`;
  }
  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((list) => {
      for (const c of list) {
        if ("focus" in c) {
          c.navigate(url);
          return c.focus();
        }
      }
      if (clients.openWindow) return clients.openWindow(url);
    })
  );
});
