// ignore_for_file: avoid_unnecessary_containers
import 'dart:async';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flixquest/services/globle_method.dart';
import '../functions/function.dart';
import '../models/tv_stream_metadata.dart';
import '../screens/tv/tv_video_loader.dart';
import '../constants/app_constants.dart';
import '/models/tv.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class WatchNowButton extends StatefulWidget {
  const WatchNowButton(
      {super.key,
      required this.episode,
      required this.seriesName,
      required this.tvId,
      required this.posterPath});

  final String seriesName, posterPath;
  final int tvId;
  final EpisodeList episode;

  @override
  State<WatchNowButton> createState() => _WatchNowButtonState();
}

class _WatchNowButtonState extends State<WatchNowButton> {
  TVDetails? tvDetails;

  Color _borderColor = Colors.red; // Initial border color
  Timer? _timer;
  Random random = Random();

  @override
  void initState() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        // Generate random RGB values between 0 and 255
        int red = random.nextInt(256);
        int green = random.nextInt(256);
        int blue = random.nextInt(256);

        _borderColor = Color.fromRGBO(red, green, blue, 1.0);
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    _timer!.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(seconds: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          // Add an outer box shadow here
          BoxShadow(
            color: _borderColor,
            spreadRadius: 2.5,
            blurRadius: 4.25,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () async {
          if (mounted) {
            if (mounted) {
              await checkConnection().then((value) {
                if (!context.mounted) {
                  return;
                }
                value
                    ? Navigator.push(context,
                        MaterialPageRoute(builder: ((context) {
                        return TVVideoLoader(
                            download: false,
                            metadata: TVStreamMetadata(
                                elapsed: null,
                                episodeId: widget.episode.episodeId,
                                episodeName: widget.episode.name,
                                episodeNumber: widget.episode.episodeNumber!,
                                posterPath: widget.posterPath,
                                backdropPath: widget.episode.stillPath,
                                seasonNumber: widget.episode.seasonNumber!,
                                seriesName: widget.seriesName,
                                tvId: widget.tvId,
                                airDate: widget.episode.airDate));
                      })))
                    : context.mounted
                        ? GlobalMethods.showCustomScaffoldMessage(
                            SnackBar(
                              content: Text(
                                tr('check_connection'),
                                maxLines: 3,
                                style: kTextSmallBodyStyle,
                              ),
                              duration: const Duration(seconds: 3),
                            ),
                            context)
                        : {};
              });
            }
          }
        },
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(
                PhosphorIcons.playCircle(PhosphorIconsStyle.fill),
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              const SizedBox(width: 6),
              Text(tr('watch_now'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ))
            ])),
      ),
    );
  }
}
