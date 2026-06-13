import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAUNd2eAuV3Qs46G1-QvKj2vbmSbBVAT7A',
    authDomain: 'daycraft-9e9ee.firebaseapp.com',
    projectId: 'daycraft-9e9ee',
    storageBucket: 'daycraft-9e9ee.firebasestorage.app',
    messagingSenderId: '46831407982',
    appId: '1:46831407982:web:3b1a2877cc4ddccd51a77f',
    measurementId: 'G-3432HLGPLS',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCDV01NA4ZxoTiD42wfuwEbd90Rr6PSbpI',
    authDomain: 'daycraft-9e9ee.firebaseapp.com',
    projectId: 'daycraft-9e9ee',
    storageBucket: 'daycraft-9e9ee.firebasestorage.app',
    messagingSenderId: '46831407982',
    appId: '1:46831407982:android:4d44276bb6f189ed51a77f',
  );
}
