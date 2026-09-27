import 'package:better_player_plus/better_player_plus.dart';
import 'package:easy_localization/easy_localization.dart';

/// The phone controls' words in the app's language.
BetterPlayerControlsStrings playerControlsStrings() =>
    BetterPlayerControlsStrings(
      back: tr('player_back'),
      play: tr('player_play'),
      pause: tr('player_pause'),
      replay: tr('player_replay'),
      // The controls fill in {seconds} themselves.
      seekBack: tr('player_seek_back'),
      seekForward: tr('player_seek_forward'),
      speed: tr('player_speed'),
      playbackSpeed: tr('player_playback_speed'),
      normalSpeed: tr('player_speed_normal'),
      lock: tr('player_lock'),
      unlock: tr('player_unlock'),
      screenLocked: tr('player_screen_locked'),
      tapToUnlock: tr('player_tap_to_unlock'),
      episodes: tr('episodes'),
      moreLikeThis: tr('more_like_this'),
      nextEpisode: tr('next_episode'),
      audioAndSubtitles: tr('player_audio_subtitles'),
      audio: tr('player_audio'),
      subtitles: tr('player_subtitles'),
      off: tr('player_off'),
      quality: tr('player_quality'),
      more: tr('player_more'),
      close: tr('close'),
      download: tr('download_action'),
      fullscreen: tr('player_fullscreen'),
      exitFullscreen: tr('player_exit_fullscreen'),
      pictureInPicture: tr('player_pip'),
      cropAndFit: tr('player_crop'),
      fit: tr('player_fit'),
      fitDescription: tr('player_fit_description'),
      cropToFill: tr('player_crop_fill'),
      cropToFillDescription: tr('player_crop_fill_description'),
      stretch: tr('player_stretch'),
      stretchDescription: tr('player_stretch_description'),
      live: tr('player_live'),
      playbackFailed: tr('player_playback_failed'),
    );
