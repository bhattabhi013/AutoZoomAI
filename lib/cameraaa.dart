import 'package:camera/camera.dart';
import 'package:camera_app/preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class CameraPage extends StatefulWidget {
  CameraPage({Key? key, required this.cameras}) : super(key: key);
  final List<CameraDescription>? cameras;
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late final objectDetector;
  late CameraController _cameraController;
  bool _isRearCameraSelected = true;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
    objectDetector.close();
  }

  @override
  void initState() {
    super.initState();
    initCamera(widget.cameras![0]);
    final options = ObjectDetectorOptions(
        classifyObjects: false,
        mode: DetectionMode.stream,
        multipleObjects: false);
    objectDetector = ObjectDetector(options: options);
  }

  Future takePicture() async {
    if (!_cameraController.value.isInitialized) {
      return null;
    }
    if (_cameraController.value.isTakingPicture) {
      return null;
    }
    try {
      await _cameraController.setFlashMode(FlashMode.off);
      XFile picture = await _cameraController.takePicture();
      final inputImage = InputImage.fromFilePath(picture.path);
      final List<DetectedObject> _objects =
          await objectDetector.processImage(inputImage);
      for (DetectedObject detectedObject in _objects) {
        final rect = detectedObject.boundingBox;
        final trackingId = detectedObject.trackingId;

        for (Label label in detectedObject.labels) {
          print('${label.text} ${label.confidence}');
        }
      }
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PreviewPage(
                    picture: picture,
                  )));
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
    } on CameraException catch (e) {
      debugPrint("camera error $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: Color.fromRGBO(255, 255, 255, 0.0),
      body: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 1,
          child: Column(
            children: [
              Stack(
                children: [
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
                      top: MediaQuery.of(context).size.height * 0.75,
                      left: MediaQuery.of(context).size.width * 0.83,
                    ),
                    child: IconButton(
                      onPressed: () {
                        // reset the zoom
                      },
                      icon: const Icon(
                        Icons.restart_alt,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 35,
                      icon: Icon(
                          _isRearCameraSelected
                              ? CupertinoIcons.switch_camera
                              : CupertinoIcons.switch_camera_solid,
                          color: Colors.black),
                      onPressed: () {
                        setState(() =>
                            _isRearCameraSelected = !_isRearCameraSelected);
                        initCamera(
                            widget.cameras![_isRearCameraSelected ? 0 : 1]);
                      },
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          // image: _imageFile != null
                          //     ? DecorationImage(
                          //         image: FileImage(_imageFile!),
                          //         fit: BoxFit.cover,
                          //       )
                          //     : null,
                        ),
                        child: Container(),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
