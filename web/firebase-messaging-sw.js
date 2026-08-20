importScripts(
  'https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyC8dHGS3InufaTrJCftdCAK3uSxVUvRHD0',
  authDomain: 'lecapase-booking-3af33.firebaseapp.com',
  projectId: 'lecapase-booking-3af33',
  storageBucket: 'lecapase-booking-3af33.firebasestorage.app',
  messagingSenderId: '907918136688',
  appId: '1:907918136688:web:f7e7fe5277fbfc3c596bb5',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((message) => {
  const notification = message.notification || {};

  const title = notification.title || 'Le Capase Booking';

  const options = {
    body: notification.body || 'Hai ricevuto una nuova prenotazione.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: message.data?.bookingId || 'le-capase-booking',
    data: {
      url: '/',
    },
  };

  self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  event.waitUntil(
    clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          return client.focus();
        }
      }

      if (clients.openWindow) {
        return clients.openWindow('/');
      }

      return null;
    }),
  );
});