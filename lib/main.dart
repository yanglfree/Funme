import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/funme_app.dart';
import 'core/audio/sound_service.dart';
import 'core/audio/volume_keys.dart';
import 'core/storage/app_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStore.load();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(const FunmeApp());
  VolumeKeys.instance.install();
  // Audio warms up after the first frame so a slow audio backend never
  // delays launch.
  await SoundService.instance.init();
}
