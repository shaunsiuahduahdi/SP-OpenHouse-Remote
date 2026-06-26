import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('This platform is not supported');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDwPyNYx0jSQL9zvB5nGuSPEUBEJPD9sAc',
    appId: '1:715953828725:web:c1f8dd9905e66a7eb0d93c',
    messagingSenderId: '715953828725',
    projectId: 'system-reboot-sp',
    storageBucket: 'system-reboot-sp.firebasestorage.app',
    authDomain: 'system-reboot-sp.firebaseapp.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDwPyNYx0jSQL9zvB5nGuSPEUBEJPD9sAc',
    appId: '1:715953828725:web:c1f8dd9905e66a7eb0d93c',
    messagingSenderId: '715953828725',
    projectId: 'system-reboot-sp',
    storageBucket: 'system-reboot-sp.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDwPyNYx0jSQL9zvB5nGuSPEUBEJPD9sAc',
    appId: '1:715953828725:web:c1f8dd9905e66a7eb0d93c',
    messagingSenderId: '715953828725',
    projectId: 'system-reboot-sp',
    storageBucket: 'system-reboot-sp.firebasestorage.app',
    iosBundleId: 'com.example.systemRebootQmanager',
  );
}