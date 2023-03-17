import 'package:camera/camera.dart';
import 'package:camera_app/autozoom.dart';

import 'package:camera_app/test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera_app/image_provider.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();

  runApp(
    ChangeNotifierProvider(
      create: (context) => ImageProviderLocal(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Camera Demo',
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}
