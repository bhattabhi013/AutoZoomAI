import 'package:camera/camera.dart';
import 'package:camera_app/screens/autozoom.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera_app/provider/image_provider.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();

  runApp(
    ChangeNotifierProvider(
      create: (context) => ImageProviderLocal(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'AutoZoom AI',
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}
