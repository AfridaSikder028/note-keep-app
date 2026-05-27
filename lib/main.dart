import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'core/services/notification_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/cloudinary_service.dart';
import 'app.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load .env file
  await dotenv.load(fileName: ".env");
  print('✅ .env loaded');
  
  // Initialize Cloudinary
  await CloudinaryService().init();
  print('✅ Cloudinary initialized');
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('✅ Firebase initialized');

  // Initialize Firestore Service
  await FirestoreService.instance.init();
  print('✅ Firestore Service initialized');

  // Initialize Notification Service (skip for web)
  if (!kIsWeb) {
    await NotificationService.instance.init();
  }

  // Run the app
  runApp(const NoteKeepApp());
  
  // Auto sync after app starts
  Future.delayed(const Duration(milliseconds: 500), () async {
    await SyncService.instance.syncOnAppOpen();
    print('✅ Auto sync completed');
  });
}