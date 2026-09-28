// ignore_for_file: unused_local_variable, use_build_context_synchronously
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/services/globle_method.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:isolate';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../functions/function.dart';
import '../../provider/settings_provider.dart';
import 'image_viewer_chrome.dart';

class HeroPhotoView extends StatefulWidget {
  const HeroPhotoView(
      {required this.imageProvider,
      required this.currentIndex,
      required this.name,
      required this.heroId,
      super.key});
  final ImageProvider imageProvider;
  final String heroId;
  final int currentIndex;
  final String name;

  @override
  State<HeroPhotoView> createState() => _HeroPhotoViewState();
}

class _HeroPhotoViewState extends State<HeroPhotoView> {
  final ReceivePort _port = ReceivePort();

  Future<String> createFolder(
      String flixquestFolderName,
      String imageTypeFolderName,
      String posterFolder,
      String stillFolder,
      String personImageFolder) async {
    final cinefolderName = flixquestFolderName;
    final imagefolderName = imageTypeFolderName;
    final posterFolderName = posterFolder;
    final stillFolderName = stillFolder;
    final personImageFolderName = personImageFolder;
    final flixquestPath = Directory('storage/emulated/0/$cinefolderName');
    final imageTypePath =
        Directory('storage/emulated/0/FlixQuest/$imagefolderName');
    final posterPath =
        Directory('storage/emulated/0/FlixQuest/$posterFolderName');
    final stillPath =
        Directory('storage/emulated/0/FlixQuest/$stillFolderName');
    final personImagePath =
        Directory('storage/emulated/0/FlixQuest/$personImageFolderName');

    if ((await flixquestPath.exists())) {
      imageTypePath.create();
      posterPath.create();
      stillPath.create();
      personImagePath.create();
      return flixquestPath.path;
    } else {
      flixquestPath.create();
      posterPath.create();
      imageTypePath.create();
      stillPath.create();
      personImagePath.create();
      return flixquestPath.path;
    }
  }

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port')!;
    send.send([id, status, progress]);
  }

  @override
  void initState() {
    super.initState();

    IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      String id = data[0];
      DownloadTaskStatus status = data[1];
      int progress = data[2];
      setState(() {});
    });

    FlutterDownloader.registerCallback(downloadCallback);
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    _port.close();
    super.dispose();
  }

  void _download(String url, String currentIndex, String themeMode) async {
    var externalStatus = await Permission.manageExternalStorage.status;
    if (externalStatus.isPermanentlyDenied) {
      GlobalMethods.showScaffoldMessage(tr('give_file_permission'), context);
      return;
    } else if (!externalStatus.isGranted) {
      await Permission.manageExternalStorage.request().then((value) {
        if (value.isDenied) {
          GlobalMethods.showScaffoldMessage(
              tr('give_file_permission_short'), context);
          return;
        }
      });
    }

    if (externalStatus.isGranted) {
      await createFolder(
          'FlixQuest', 'Backdrops', 'Posters', 'Stills', 'Person Images');
      await FlutterDownloader.enqueue(
        url: url,
        fileName: '${widget.name}_${createUniqueId()}.jpg',
        headers: {}, // optional: header send with url (auth token etc)
        savedDir: '/storage/emulated/0/FlixQuest/Person Images/',
        showNotification:
            true, // show download progress in status bar (for Android)
        openFileFromNotification:
            true, // click on notification to open downloaded file (for Android)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    return ImageViewerChrome(
      title: widget.name.endsWith('s')
          ? tr('plular_person_image', namedArgs: {'name': widget.name})
          : tr('singular_person_image', namedArgs: {'name': widget.name}),
      downloadLabel: tr('download'),
      onDownload: () => _download(
        widget.heroId,
        '${widget.currentIndex + 1}',
        themeMode,
      ),
      child: PhotoView(
        imageProvider: widget.imageProvider,
        enableRotation: true,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        heroAttributes: PhotoViewHeroAttributes(tag: widget.heroId),
      ),
    );
  }
}
