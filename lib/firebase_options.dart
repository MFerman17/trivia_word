// Archivo de configuración manual para Firebase
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
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia: // 👈 Añadido para que el switch sea exhaustivo
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA8to2P-ZO2mtz2NH_Tk0zlCai6mA4ac4',
    appId: '1:506207443915:web:eeeadb7bed076770b9344e',
    messagingSenderId: '506207443915',
    projectId: 'trivia-word-f612c',
    authDomain: 'trivia-word-f612c.firebaseapp.com',
    storageBucket: 'trivia-word-f612c.firebasestorage.app',
    measurementId: 'G-7QWHKCBGE9',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA8to2P-ZO2mtz2NH_Tk0zlCai6mA4ac4',
    appId: '1:506207443915:web:eeeadb7bed076770b9344e',
    messagingSenderId: '506207443915',
    projectId: 'trivia-word-f612c',
    authDomain: 'trivia-word-f612c.firebaseapp.com',
    storageBucket: 'trivia-word-f612c.firebasestorage.app',
    measurementId: 'G-7QWHKCBGE9',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA8to2P-ZO2mtz2NH_Tk0zlCai6mA4ac4',
    appId: '1:506207443915:web:eeeadb7bed076770b9344e',
    messagingSenderId: '506207443915',
    projectId: 'trivia-word-f612c',
    authDomain: 'trivia-word-f612c.firebaseapp.com',
    storageBucket: 'trivia-word-f612c.firebasestorage.app',
    measurementId: 'G-7QWHKCBGE9',
  );
}