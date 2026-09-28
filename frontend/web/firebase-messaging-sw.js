// Firebase Cloud Messaging service worker for Flutter Web (background messages).
// The SDK version must match the one bundled by firebase_core_web (see pubspec.lock).
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-messaging-compat.js');

// Same public web config as DefaultFirebaseOptions.web in lib/firebase_options.dart.
firebase.initializeApp({
  apiKey: 'AIzaSyDVfNS8-MTSqEdxvUpBgWQEBdsCpehlBCA',
  appId: '1:976687020841:web:cb24523c28a2addd345538',
  messagingSenderId: '976687020841',
  projectId: 'clausulazos-a527c',
  authDomain: 'clausulazos-a527c.firebaseapp.com',
  storageBucket: 'clausulazos-a527c.firebasestorage.app',
  measurementId: 'G-W11TXC985H',
});

firebase.messaging();
