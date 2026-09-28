// ignore_for_file: use_build_context_synchronously, unused_local_variable, avoid_unnecessary_containers

import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/services/globle_method.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/api_constants.dart';
import '../../functions/function.dart';
import '../../models/images.dart';
import '../../provider/app_dependency_provider.dart';
import '../../provider/settings_provider.dart';
import '../../design/outline_mark.dart';
import 'image_viewer_chrome.dart';

class HeroPhotoView extends StatefulWidget {
  const HeroPhotoView(
      {required this.imageType,
      this.name,
      this.stills,
      this.posters,
      this.backdrops,
      this.initialIndex = 0,
      super.key});
  final List<Backdrops>? backdrops;
  final List<Posters>? posters;
  final List<Stills>? stills;
  final String? name;
  final String imageType;

  /// The image shown first.
  final int initialIndex;

  @override
  State<HeroPhotoView> createState() => _HeroPhotoViewState();
}

class _HeroPhotoViewState extends State<HeroPhotoView> {
  late int currentIndex = widget.initialIndex;
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);

  void onPageChanged(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  Future<void> createFolder(
      String flixquestFolderName,
      String imageTypeFolderName,
      String posterFolder,
      String stillFolder) async {
    final cinefolderName = flixquestFolderName;
    final imagefolderName = imageTypeFolderName;
    final posterFolderName = posterFolder;
    final stillFolderName = stillFolder;
    final flixquestPath = Directory('storage/emulated/0/$cinefolderName');
    final imageTypePath =
        Directory('storage/emulated/0/FlixQuest/$imagefolderName');
    final posterPath =
        Directory('storage/emulated/0/FlixQuest/$posterFolderName');
    final stillPath =
        Directory('storage/emulated/0/FlixQuest/$stillFolderName');

    if ((await flixquestPath.exists())) {
      imageTypePath.create();
      posterPath.create();
      stillPath.create();
    } else {
      flixquestPath.create();
      posterPath.create();
      imageTypePath.create();
      stillPath.create();
    }
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
      if (mounted) {
        Provider.of<SettingsProvider>(context, listen: false)
            .analytics
            .trackImageDownloaded(imageType: widget.imageType);
      }
      await createFolder('FlixQuest', 'Backdrops', 'Posters', 'Stills');
      await FlutterDownloader.enqueue(
        url: url,
        fileName: '${widget.name}_${widget.imageType}_${createUniqueId()}.jpg',
        savedDir: widget.imageType == 'backdrop'
            ? '/storage/emulated/0/FlixQuest/Backdrops/'
            : widget.imageType == 'poster'
                ? '/storage/emulated/0/FlixQuest/Posters/'
                : '/storage/emulated/0/FlixQuest/Stills/',
        showNotification: true,
        openFileFromNotification: true,
      );
    }
  }

  final ReceivePort _port = ReceivePort();

  @pragma('vm:entry-point')
  static void downloadCallback(String id, int status, int progress) {
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port')!;
    send.send([id, status, progress]);
  }

  @override
  void initState() {
    IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      String id = data[0];
      DownloadTaskStatus status = data[1];
      int progress = data[2];
      setState(() {});
    });

    FlutterDownloader.registerCallback(downloadCallback);
    super.initState();
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    _port.close();
    _pages.dispose();
    super.dispose();
  }

  String _imagePathAt(int index) {
    if (widget.imageType == 'backdrop') {
      return widget.backdrops![index].filePath!;
    }
    if (widget.imageType == 'poster') {
      return widget.posters![index].posterPath!;
    }
    return widget.stills![index].stillPath!;
  }

  int get _itemCount => widget.imageType == 'backdrop'
      ? widget.backdrops!.length
      : widget.imageType == 'poster'
          ? widget.posters!.length
          : widget.stills!.length;

  @override
  Widget build(BuildContext context) {
    final imageQuality = Provider.of<SettingsProvider>(context).imageQuality;
    final themeMode = Provider.of<SettingsProvider>(context).appTheme;
    final isProxyEnabled = Provider.of<SettingsProvider>(context).enableProxy;
    final proxyUrl = Provider.of<AppDependencyProvider>(context).tmdbProxy;
    return ImageViewerChrome(
      title: widget.name ?? '',
      downloadLabel: tr('download'),
      onDownload: () => _download(
          buildImageUrl(TMDB_BASE_IMAGE_URL, proxyUrl, isProxyEnabled,
                  context) +
              imageQuality +
              _imagePathAt(currentIndex),
          '${currentIndex + 1}',
          themeMode),
      footer: ImageViewerCounter(text: '${currentIndex + 1} / $_itemCount'),
      child: PhotoViewGallery.builder(
        pageController: _pages,
        allowImplicitScrolling: true,
        gaplessPlayback: true,
        wantKeepAlive: true,
        enableRotation: true,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: CachedNetworkImageProvider(
              buildImageUrl(
                      TMDB_BASE_IMAGE_URL, proxyUrl, isProxyEnabled, context) +
                  imageQuality +
                  _imagePathAt(index),
            ),
            initialScale: PhotoViewComputedScale.contained * 0.95,
          );
        },
        itemCount: _itemCount,
        onPageChanged: onPageChanged,
        // The mark, quietly, until the image arrives.
        loadingBuilder: (context, event) => const Center(
          child: OutlineMark(height: 48, color: Color(0x3DFFFFFF)),
        ),
      ),
    );
  }
}
