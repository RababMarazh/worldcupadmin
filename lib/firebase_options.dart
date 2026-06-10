import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// Replace the values below with your Firebase web app configuration.
const FirebaseOptions firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyBF17NqIUP9XYmveda0pESqYqfDt1iPHCo',
  authDomain: 'world-cup-eb2e7.firebaseapp.com',
  projectId: 'world-cup-eb2e7',
  storageBucket: 'world-cup-eb2e7.appspot.com',
  messagingSenderId: '433447116436',
  appId: '1:433447116436:web:c79e542b70fcf4083b1e81',
  measurementId: 'G-2GCZ48Y9K3',
);

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return firebaseOptions;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are only supported for Web.\n'
      'Use a native Firebase configuration for Android/iOS or run flutterfire configure.',
    );
  }
}
