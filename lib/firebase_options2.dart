import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS: return ios;
      default: return web;
    }
  }

  // ── PASTE YOUR VALUES FROM FIREBASE CONSOLE ──

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDkVmwJITjDRJ2IoV-NlXJRlthHukQaq-E',
    appId: '1:528661131656:web:b8dfd23856b2acb59dca3d',
    messagingSenderId: '528661131656',
    projectId: 'osu-name',       // e.g. 'osu-pose'
    authDomain: 'osu-name.firebaseapp.com',
    storageBucket: 'osu-name.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDkVmwJITjDRJ2IoV-NlXJRlthHukQaq-E',
    appId: '1:528661131656:web:b8dfd23856b2acb59dca3d',
    messagingSenderId: '528661131656',
    projectId: 'osu-name',
    storageBucket: 'osu-name.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDkVmwJITjDRJ2IoV-NlXJRlthHukQaq-E',
    appId: '1:528661131656:web:b8dfd23856b2acb59dca3d',
    messagingSenderId: '528661131656',
    projectId: 'osu-name',
    storageBucket: 'osu-name.firebasestorage.app',
    iosBundleId: 'com.example.osupose',
  );
}