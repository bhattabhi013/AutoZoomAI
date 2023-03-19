import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:camera_app/gallery.dart';
import 'package:camera_app/image_provider.dart';
import 'package:camera_app/painters/object_detector_painter.dart';
import 'package:camera_app/preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class CameraPage extends StatefulWidget {
  CameraPage({Key? key, required this.cameras}) : super(key: key);
  final List<CameraDescription>? cameras;
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  List<File> images = [];
  File? _imageFile;
  List<String> _imagePaths = [];
  late CameraController _cameraController;
  bool _isRearCameraSelected = true;
  late ObjectDetector _objectDetector;
  bool _canProcess = false;
  bool _isBusy = false;
  late bool _isStream;
  CustomPaint? _customPaint;
  bool _isDetecting = false;
  double _zoom = 1.0;
  late double _maxZoom;
  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
    _objectDetector.close();
  }

  @override
  void initState() {
    super.initState();
    initCamera(widget.cameras![0]);
    getImages(); // to get the captured images from the local dir
    _initializeDetector(); // initialize the ml kit model
  }

  void _initializeDetector() async {
    final options = ObjectDetectorOptions(
      classifyObjects: false,
      multipleObjects: false,
      mode: DetectionMode
          .stream, // stream for continuous video and single for single shot/gallery pics
    );
    _objectDetector = ObjectDetector(options: options);
    _canProcess = true;
    _isStream = false;
  }

  Future takePicture() async {
    if (!_cameraController.value.isInitialized) {
      return null;
    }
    if (_cameraController.value.isTakingPicture) {
      return null;
    }
    try {
      final rawImage = await _cameraController.takePicture();
      File imageFile = File(rawImage.path);
      try {
        final Directory? directory = await getExternalStorageDirectory();
        String fileFormat = imageFile.path.split('.').last;
        int currentUnix = DateTime.now().millisecondsSinceEpoch;

        final path = '${directory!.path}/$currentUnix.$fileFormat';
        await rawImage.saveTo(path);

        getImages();
      } catch (e) {
        debugPrint(e.toString());
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewPage(
            picture: rawImage,
          ),
        ),
      );
    } on CameraException catch (e) {
      debugPrint('Error occured while taking picture: $e');
      return null;
    }
  }

  Future initCamera(CameraDescription cameraDescription) async {
    _cameraController =
        CameraController(cameraDescription, ResolutionPreset.high);
    try {
      await _cameraController.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      });
      _maxZoom = await _cameraController.getMaxZoomLevel();
    } on CameraException catch (e) {
      debugPrint("camera error $e");
    }
  }

  void getImages() async {
    final directory = await getExternalStorageDirectory();
    List<FileSystemEntity> fileList = await directory!.list().toList();
    images.clear();
    List<Map<int, dynamic>> fileNames = [];

    for (var file in fileList.reversed.toList()) {
      if (file.path.contains('.jpg')) {
        if (!_imagePaths.contains(file.path)) {
          _imagePaths.add(file.path);
        }
      }
      images.add(File(file.path));

      String name = file.path.split('/').last.split('.').first;
      fileNames.add({0: int.parse(name), 1: file.path.split('/').last});
    }

    if (fileNames.isEmpty) {
      setState(() {
        _imagePaths.clear();
        images.clear();
        _imageFile = null;
      });
    }

    if (fileNames.isNotEmpty) {
      final recentFile =
          fileNames.reduce((curr, next) => curr[0] > next[0] ? curr : next);
      String recentFileName = recentFile[1];
      _imageFile = File('${directory.path}/$recentFileName');
      Provider.of<ImageProviderLocal>(context, listen: false)
          .setPath(_imagePaths);
      setState(() {
        images;
        _imageFile;
      });
    }
  }

  void resetZoom() {
    _cameraController.setZoomLevel(1.0);
    setState(() {
      _zoom = 1.0;
    });
  }

  void showSnackBar(text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        clipBehavior: Clip.hardEdge,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        content: Center(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future _processCameraImage(CameraImage image) async {
    if (!_isStream) {
      await _cameraController.stopImageStream();
    } else {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize =
          Size(image.width.toDouble(), image.height.toDouble());

      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
              InputImageFormat.nv21;

      final planeData = image.planes.map(
        (Plane plane) {
          return InputImagePlaneMetadata(
            bytesPerRow: plane.bytesPerRow,
            height: plane.height,
            width: plane.width,
          );
        },
      ).toList();

      final inputImageData = InputImageData(
        size: imageSize,
        imageRotation: InputImageRotation.rotation0deg,
        inputImageFormat: inputImageFormat,
        planeData: planeData,
      );

      final inputImage =
          InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);

      processImage(inputImage);
    }
  }

  Future _stopLiveFeed() async {
    await _cameraController.stopImageStream();
    await _cameraController.dispose();
  }

  Future<void> processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    final objects = await _objectDetector.processImage(inputImage);
    if (objects.isNotEmpty) {
      final boundingBox = objects[0].boundingBox;
      zoomFunction(boundingBox);
      setState(() {
        _isStream = false;
      });
    }
    // if (inputImage.inputImageData?.size != null &&
    //     inputImage.inputImageData?.imageRotation != null) {
    //   final painter = ObjectDetectorPainter(
    //       objects,
    //       inputImage.inputImageData!.imageRotation,
    //       inputImage.inputImageData!.size);
    //   _customPaint = CustomPaint(painter: painter);
    // }
    _isBusy = false;
  }

  void zoomFunction(Rect boundingBox) async {
    if (!_isDetecting) return;
    // double objectHeight = boundingBox.height;
    // double objectWidth = boundingBox.width;
    // double screenHeight = MediaQuery.of(context).size.height;
    // double screenWidth = MediaQuery.of(context).size.width;
    double minZoom = await _cameraController.getMinZoomLevel();
    double maxZoom = await _cameraController.getMaxZoomLevel();
    double currentZoom = _zoom;

    double newZoom = 1.2 * currentZoom + minZoom;

    if (currentZoom != newZoom) {
      if (newZoom > maxZoom) {
        showSnackBar("Max zoom reached");
        newZoom = 1.0;
      } else {
        await _cameraController.setZoomLevel(newZoom);
      }
      setState(() {
        _zoom = newZoom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
      child: Stack(children: [
        (_cameraController.value.isInitialized)
            ? CameraPreview(_cameraController)
            : Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
        Container(
          margin: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.70,
            left: MediaQuery.of(context).size.width * 0.05,
          ),
          child: IconButton(
            onPressed: () async {
              setState(() {
                _isDetecting = !_isDetecting;
                _isStream = !_isStream;
              });
              if (_isStream) {
                _cameraController.startImageStream(_processCameraImage);
              }
              showSnackBar(
                  _isDetecting ? "Detecting Objects" : "Detection paused");
            },
            icon: Icon(
              Icons.location_searching,
              color: _isDetecting ? Colors.green : Colors.white,
              size: 35,
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.70,
            left: MediaQuery.of(context).size.width * 0.83,
          ),
          child: IconButton(
            onPressed: () => resetZoom(),
            icon: const Icon(
              Icons.restart_alt,
              size: 35,
              color: Colors.white,
            ),
          ),
        ),
        Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.18,
              decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  color: Colors.black),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                        child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 30,
                      icon: Icon(
                          _isRearCameraSelected
                              ? CupertinoIcons.switch_camera
                              : CupertinoIcons.switch_camera_solid,
                          color: Colors.white),
                      onPressed: () {
                        setState(() =>
                            _isRearCameraSelected = !_isRearCameraSelected);
                        initCamera(
                            widget.cameras![_isRearCameraSelected ? 0 : 1]);
                      },
                    )),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          takePicture();
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: const [
                            Icon(
                              Icons.circle,
                              color: Color.fromARGB(44, 193, 187, 206),
                              size: 90,
                            ),
                            Icon(
                              Icons.circle,
                              color: Color.fromARGB(255, 251, 250, 250),
                              size: 70,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GalleryPage(),
                            ),
                          );
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            image: _imageFile != null
                                ? DecorationImage(
                                    image: FileImage(_imageFile!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: Container(),
                        ),
                      ),
                    ),
                  ]),
            )),
      ]),
    ));
  }
}
