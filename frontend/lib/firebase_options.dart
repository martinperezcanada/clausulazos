// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for the current platform.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDVfNS8-MTSqEdxvUpBgWQEBdsCpehlBCA',
    appId: '1:976687020841:web:cb24523c28a2addd345538',
    messagingSenderId: '976687020841',
    projectId: 'clausulazos-a527c',
    authDomain: 'clausulazos-a527c.firebaseapp.com',
    storageBucket: 'clausulazos-a527c.firebasestorage.app',
    measurementId: 'G-W11TXC985H',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDn0yEKlYH1mdHIClVCt8NXCZTB2mljSf8',
    appId: '1:976687020841:android:cfc6150c6b5a5eb4345538',
    messagingSenderId: '976687020841',
    projectId: 'clausulazos-a527c',
    storageBucket: 'clausulazos-a527c.firebasestorage.app',
  );
}
