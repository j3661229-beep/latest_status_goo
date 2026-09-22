// File generated for Firebase initialization
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDJXnq7cT3wnitNAEvGWv3EL8J8qDOYNWk',
    appId: '1:337906515707:android:f5018bad412c14daf7ba5e',
    messagingSenderId: '337906515707',
    projectId: 'agrimart-fl-v1',
    storageBucket: 'agrimart-fl-v1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDJXnq7cT3wnitNAEvGWv3EL8J8qDOYNWk',
    appId: '1:337906515707:ios:f5018bad412c14daf7ba5e',
    messagingSenderId: '337906515707',
    projectId: 'agrimart-fl-v1',
    storageBucket: 'agrimart-fl-v1.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDJXnq7cT3wnitNAEvGWv3EL8J8qDOYNWk',
    appId: '1:337906515707:web:f5018bad412c14daf7ba5e',
    messagingSenderId: '337906515707',
    projectId: 'agrimart-fl-v1',
    storageBucket: 'agrimart-fl-v1.firebasestorage.app',
  );
}
