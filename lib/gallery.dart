import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camera_app/image_provider.dart';
import 'package:provider/provider.dart';

import 'package:camera_app/preview.dart';
import 'package:flutter/material.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({Key? key}) : super(key: key);

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late List<String> _imagePaths;
  @override
  Widget build(BuildContext context) {
    _imagePaths =
        Provider.of<ImageProviderLocal>(context, listen: true).getPath();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.0,
      ),
      body: Container(
          height: double.infinity,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          child: _imagePaths.isNotEmpty
              ? GridView.builder(
                  shrinkWrap: true,
                  physics: ClampingScrollPhysics(),
                  itemCount: _imagePaths.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 4 / 3,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PreviewPage(
                              picture: XFile(_imagePaths[index]),
                            ),
                          ),
                        );
                      },
                      child: Card(
                        child: GridTile(
                          footer: GridTileBar(
                            backgroundColor: Colors.black45,
                            title: Text(
                              'Item ${1 + index}',
                              style: TextStyle(fontSize: 16.0),
                            ),
                          ),
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Image.asset(
                              _imagePaths[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : const Center(
                  child: Text('No Images'),
                )),
    );
  }
}
