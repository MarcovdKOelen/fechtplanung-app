// GENERATED FILE (manual) - Firebase options for Trainingsplanung Fechten MvK
// Android package: de.deinname.fechtplanung

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Web not configured in this project
      throw UnsupportedError('DefaultFirebaseOptions are not configured for web.');
    }
    switch (defaultTargetPlatform) {
  case TargetPlatform.android:
    return android;
  case TargetPlatform.iOS:
  case TargetPlatform.macOS:
  case TargetPlatform.windows:
  case TargetPlatform.linux:
  case TargetPlatform.fuchsia:
    throw UnsupportedError(
      'DefaultFirebaseOptions are not configured for this platform.',
    );
}


  // Values taken from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyB8BUWz6JrgTSDKEEGKfbSyllOA_1uecPo",
    appId: "1:630196522503:android:59e992b16dd15f0b54a4a2",
    messagingSenderId: "630196522503",
    projectId: "trainingsplan-fechten",
    storageBucket: "trainingsplan-fechten.firebasestorage.app",
  );
}
