import 'dart:async';
import 'dart:ui';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../functions/language_names.dart';
import '../../../functions/player_subtitle_configuration.dart';
import '../../../functions/subtitle_options.dart';
import '../../../functions/subtitle_style.dart';
import '../../../provider/settings_provider.dart';
import 'player_sheet_ui.dart';

/// A right-side subtitle panel (similar to YouTube) that displays while the
/// video continues to stream and play smoothly on the left.
/// Includes smooth slide-in and slide-out transitions between submenus.
class PlayerSubtitleSidePanel extends StatefulWidget {
  const PlayerSubtitleSidePanel({
    required this.controller,
    this.options,
    required this.settings,
    required this.onClose,
    required this.onSearchOnline,
    required this.onUpload,
    required this.onAutoTranslate,
    this.initialPageIndex = 0,
    super.key,
  });

  final BetterPlayerController controller;
  final List<SubtitleOption>? options;
  final SettingsProvider settings;
  final VoidCallback onClose;
  final VoidCallback onSearchOnline;
  final VoidCallback onUpload;
  final void Function(String targetLang) onAutoTranslate;
  final int initialPageIndex;

  @override
  State<PlayerSubtitleSidePanel> createState() => _PlayerSubtitleSidePanelState();
}

class _PlayerSubtitleSidePanelState extends State<PlayerSubtitleSidePanel> {
  late final PageController _pageController;
  int _currentPage = 0;
  StreamSubscription? _controllerSubscription;

  // Timing state
  static const _step = Duration(milliseconds: 500);
  static const _limit = Duration(seconds: 10);
  late Duration _offset;

  // Auto-translate search state
  String _languageFilter = '';

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPageIndex;
    _pageController = PageController(initialPage: widget.initialPageIndex);
    _offset = widget.controller.subtitleOffset;
    widget.controller.subtitleOffsetListenable.addListener(_onOffsetChanged);
    _controllerSubscription = widget.controller.controllerEventStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controllerSubscription?.cancel();
    widget.controller.subtitleOffsetListenable.removeListener(_onOffsetChanged);
    _pageController.dispose();
    super.dispose();
  }

  List<SubtitleOption> get _currentOptions {
    if (widget.options != null && widget.options!.isNotEmpty) {
      return widget.options!;
    }
    final subtitles = List<BetterPlayerSubtitlesSource>.of(
      widget.controller.betterPlayerSubtitlesSourceList,
    );
    final offIndex = subtitles.indexWhere(
      (source) => source.type == BetterPlayerSubtitlesSourceType.none,
    );
    if (offIndex < 0) {
      subtitles.insert(
        0,
        BetterPlayerSubtitlesSource(type: BetterPlayerSubtitlesSourceType.none),
      );
    } else if (offIndex > 0) {
      subtitles.insert(0, subtitles.removeAt(offIndex));
    }
    return buildSubtitleOptions(subtitles);
  }

  void _onOffsetChanged() {
    if (mounted) {
      setState(() {
        _offset = widget.controller.subtitleOffset;
      });
    }
  }

  void _goToPage(int page) {
    if (_currentPage == page) return;
    setState(() => _currentPage = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _setTimingOffset(Duration offset) {
    final milliseconds = offset.inMilliseconds.clamp(
      -_limit.inMilliseconds,
      _limit.inMilliseconds,
    );
    final target = Duration(milliseconds: milliseconds);
    widget.controller.setSubtitleOffset(target);
    setState(() => _offset = target);
  }

  void _updateOutlineSettings() {
    final settings = widget.settings;
    final newConfig = buildPlayerSubtitleConfiguration(
      backgroundColor: settings.subtitleBackgroundColor,
      foregroundColor: settings.subtitleForegroundColor,
      fontSize: settings.subtitleFontSize,
      textStyle: settings.subtitleTextStyle,
      outlineEnabled: settings.subtitleOutlineEnabled,
      outlineColor: settings.subtitleOutlineColor,
      outlineSize: settings.subtitleOutlineSize.toDouble(),
    );
    widget.controller.setBetterPlayerSubtitlesConfiguration(newConfig);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = BetterPlayerPanelColors.of(context);

    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentPage > 0) {
          _goToPage(0);
        }
      },
      child: Material(
        color: colors.panel,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.white12, width: 1),
            ),
          ),
          child: SafeArea(
            left: false,
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildMainPage(context, colors),
                _buildTimingPage(context, colors),
                _buildOutlinePage(context, colors),
                _buildAutoTranslatePage(context, colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE 0: MAIN SUBTITLE MENU
  // ---------------------------------------------------------------------------
  Widget _buildMainPage(BuildContext context, BetterPlayerPanelColors colors) {
    final currentSource = widget.controller.betterPlayerSubtitlesSource;
    final timingOffsetStr = _subtitleOffsetValue(_offset);
    final outlineStatus = widget.settings.subtitleOutlineEnabled
        ? '${widget.settings.subtitleOutlineSize}px'
        : tr('player_off');
    final options = _currentOptions;

    return Column(
      children: [
        _buildHeader(
          colors: colors,
          title: tr('player_subtitles'),
          subtitle: tr('choose_subtitle_language'),
          leading: Icon(PhosphorIcons.closedCaptioning(), color: colors.foreground, size: 22),
          onClose: widget.onClose,
        ),
        const Divider(height: 1, thickness: 1),
        // Quick Tool shortcuts
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildToolChip(
                  colors: colors,
                  icon: PhosphorIcons.timer(),
                  label: tr('subtitle_timing'),
                  badge: timingOffsetStr != '0.0s' ? timingOffsetStr : null,
                  onTap: () => _goToPage(1),
                ),
                const SizedBox(width: 8),
                _buildToolChip(
                  colors: colors,
                  icon: PhosphorIcons.paintBrush(),
                  label: tr('subtitle_outline'),
                  badge: outlineStatus,
                  onTap: () => _goToPage(2),
                ),
                const SizedBox(width: 8),
                _buildToolChip(
                  colors: colors,
                  icon: PhosphorIcons.translate(),
                  label: tr('auto_translate'),
                  onTap: () => _goToPage(3),
                ),
                const SizedBox(width: 8),
                _buildToolChip(
                  colors: colors,
                  icon: PhosphorIcons.magnifyingGlass(),
                  label: tr('search_subtitles'),
                  onTap: widget.onSearchOnline,
                ),
                const SizedBox(width: 8),
                _buildToolChip(
                  colors: colors,
                  icon: PhosphorIcons.uploadSimple(),
                  label: tr('upload_subtitles'),
                  onTap: widget.onUpload,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: ListView.builder(
            itemCount: options.length,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = currentSource?.type == BetterPlayerSubtitlesSourceType.none
                  ? option.isOff
                  : (!option.isOff &&
                      (currentSource == option.source ||
                          (currentSource?.name == option.source.name &&
                              currentSource?.name != null)));

              final rawName = option.name?.trim();
              final label = option.isOff
                  ? (tr('player_off') != 'player_off' ? tr('player_off') : (rawName ?? 'Off'))
                  : (rawName?.isNotEmpty == true
                      ? (languageDisplayName(rawName).isNotEmpty
                          ? languageDisplayName(rawName)
                          : rawName!)
                      : tr('player_default'));
              final titleText = option.number != null && option.number! > 1
                  ? '$label #${option.number}'
                  : label;
              final subtitleText = option.isOff || option.provider.isEmpty ? null : option.provider;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected ? colors.selectedFill : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
                      : Border.all(color: Colors.white10),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -1),
                    title: Text(
                      titleText,
                      style: TextStyle(
                        fontFamily: isSelected ? 'FigtreeBold' : 'FigtreeSB',
                        fontSize: 14,
                        color: isSelected ? colors.foreground : colors.muted,
                      ),
                    ),
                    subtitle: subtitleText != null
                        ? Text(
                            subtitleText,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.muted,
                            ),
                          )
                        : null,
                    trailing: isSelected
                        ? Icon(
                            PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      widget.controller.setupSubtitleSource(option.source);
                      setState(() {});
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE 1: SUBTITLE TIMING SUBMENU (REAL-TIME)
  // ---------------------------------------------------------------------------
  Widget _buildTimingPage(BuildContext context, BetterPlayerPanelColors colors) {
    final offset = _offset;
    final isSynced = offset == Duration.zero;
    final status = isSynced
        ? tr('subtitle_timing_synced')
        : tr(offset.isNegative ? 'subtitle_earlier' : 'subtitle_later');

    return Column(
      children: [
        _buildHeader(
          colors: colors,
          title: tr('subtitle_timing'),
          subtitle: tr('subtitle_timing_help'),
          onBack: () => _goToPage(0),
          onClose: widget.onClose,
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              children: [
                // Real-time offset numerical display
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  child: Text(
                    _subtitleOffsetValue(offset),
                    key: ValueKey(offset.inMilliseconds),
                    style: TextStyle(
                      color: colors.foreground,
                      fontFamily: 'FigtreeBold',
                      fontSize: 42,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    color: isSynced ? colors.muted : Theme.of(context).colorScheme.primary,
                    fontFamily: 'FigtreeSB',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                // Slider and +/- controls
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: '${tr('subtitle_earlier')} 0.5s',
                      onPressed: offset <= -_limit ? null : () => _setTimingOffset(offset - _step),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.raised,
                        foregroundColor: colors.foreground,
                        fixedSize: const Size(44, 44),
                      ),
                      icon: Icon(PhosphorIcons.minus(), size: 20),
                    ),
                    Expanded(
                      child: Slider(
                        value: offset.inMilliseconds
                            .clamp(-_limit.inMilliseconds, _limit.inMilliseconds)
                            .toDouble(),
                        min: -_limit.inMilliseconds.toDouble(),
                        max: _limit.inMilliseconds.toDouble(),
                        divisions: 80,
                        onChanged: (val) => _setTimingOffset(Duration(milliseconds: val.round())),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: '${tr('subtitle_later')} 0.5s',
                      onPressed: offset >= _limit ? null : () => _setTimingOffset(offset + _step),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.raised,
                        foregroundColor: colors.foreground,
                        fixedSize: const Size(44, 44),
                      ),
                      icon: Icon(PhosphorIcons.plus(), size: 20),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 54),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('−10s', style: TextStyle(color: colors.muted, fontSize: 12)),
                      Text('0s', style: TextStyle(color: colors.muted, fontSize: 12)),
                      Text('+10s', style: TextStyle(color: colors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: isSynced ? null : () => _setTimingOffset(Duration.zero),
                  icon: Icon(PhosphorIcons.arrowCounterClockwise(), size: 18),
                  label: Text(tr('subtitle_timing_reset')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(160, 42),
                    side: BorderSide(color: colors.hairline),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.raised.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.info(), size: 18, color: colors.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr('subtitle_offset_live_hint'),
                          style: TextStyle(color: colors.muted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE 2: SUBTITLE OUTLINE & STYLE SUBMENU
  // ---------------------------------------------------------------------------
  Widget _buildOutlinePage(BuildContext context, BetterPlayerPanelColors colors) {
    final settings = widget.settings;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentColor = parseStoredSubtitleColor(
      settings.subtitleOutlineColor,
      fallback: Colors.black,
    );

    const availableColors = <Color>[
      Colors.black,
      Colors.white,
      Colors.amber,
      Colors.yellow,
      Colors.redAccent,
      Colors.blueAccent,
      Colors.cyanAccent,
      Colors.greenAccent,
      Colors.purpleAccent,
    ];

    return Column(
      children: [
        _buildHeader(
          colors: colors,
          title: tr('subtitle_outline'),
          subtitle: tr('subtitle_outline_subtitle'),
          onBack: () => _goToPage(0),
          onClose: widget.onClose,
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // Switch: Enable Outline
              Material(
                color: colors.raised,
                borderRadius: BorderRadius.circular(12),
                child: SwitchListTile(
                  title: Text(
                    tr('subtitle_outline_enable'),
                    style: TextStyle(
                      fontFamily: 'FigtreeBold',
                      fontSize: 15,
                      color: colors.foreground,
                    ),
                  ),
                  value: settings.subtitleOutlineEnabled,
                  onChanged: (val) {
                    settings.subtitleOutlineEnabled = val;
                    _updateOutlineSettings();
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Outline Color
              if (settings.subtitleOutlineEnabled) ...[
                Text(
                  tr('outline_color'),
                  style: TextStyle(
                    fontFamily: 'FigtreeBold',
                    fontSize: 14,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: availableColors.map((color) {
                    final isSelected = currentColor.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        settings.subtitleOutlineColor = serializeSubtitleColor(color);
                        _updateOutlineSettings();
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? primaryColor : Colors.white24,
                            width: isSelected ? 3 : 1.5,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: isSelected
                            ? Icon(
                                PhosphorIcons.check(),
                                size: 18,
                                color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                // Outline Size Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tr('outline_width'),
                      style: TextStyle(
                        fontFamily: 'FigtreeBold',
                        fontSize: 14,
                        color: colors.muted,
                      ),
                    ),
                    Text(
                      '${settings.subtitleOutlineSize}px',
                      style: TextStyle(
                        fontFamily: 'FigtreeBold',
                        fontSize: 14,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: settings.subtitleOutlineSize.toDouble().clamp(1.0, 10.0),
                  min: 1.0,
                  max: 10.0,
                  divisions: 9,
                  onChanged: (val) {
                    settings.subtitleOutlineSize = val.round();
                    _updateOutlineSettings();
                  },
                ),
                const SizedBox(height: 20),
                // Live Preview Card
                Text(
                  tr('preview'),
                  style: TextStyle(
                    fontFamily: 'FigtreeBold',
                    fontSize: 13,
                    color: colors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 90,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.hairline),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (settings.subtitleOutlineEnabled)
                        Text(
                          tr('sample_player_text'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'FigtreeBold',
                            fontSize: 16,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = settings.subtitleOutlineSize.toDouble()
                              ..color = parseStoredSubtitleColor(
                                settings.subtitleOutlineColor,
                                fallback: Colors.black,
                              ),
                          ),
                        ),
                      Text(
                        tr('sample_player_text'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'FigtreeBold',
                          fontSize: 16,
                          color: parseStoredSubtitleColor(
                            settings.subtitleForegroundColor,
                            fallback: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // PAGE 3: AUTO-TRANSLATE SUBMENU
  // ---------------------------------------------------------------------------
  Widget _buildAutoTranslatePage(BuildContext context, BetterPlayerPanelColors colors) {
    final query = _languageFilter.toLowerCase().trim();
    final languages = appLanguages.where((lang) {
      if (query.isEmpty) return true;
      final native = tr(lang.translationKey).toLowerCase();
      final code = lang.code.toLowerCase();
      return native.contains(query) || code.contains(query);
    }).toList();

    if (query.isEmpty) {
      languages.sort((a, b) {
        if (a.code == 'id') return -1;
        if (b.code == 'id') return 1;
        if (a.code == 'en') return -1;
        if (b.code == 'en') return 1;
        return tr(a.translationKey).compareTo(tr(b.translationKey));
      });
    }

    return Column(
      children: [
        _buildHeader(
          colors: colors,
          title: tr('auto_translate'),
          subtitle: tr('choose_subtitle_language'),
          onBack: () => _goToPage(0),
          onClose: widget.onClose,
        ),
        const Divider(height: 1, thickness: 1),
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: '${tr('search')}...',
              prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 18),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: Icon(PhosphorIcons.x(), size: 16),
                      onPressed: () => setState(() => _languageFilter = ''),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _languageFilter = val),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: languages.length,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemBuilder: (context, index) {
              final lang = languages[index];
              return ListTile(
                dense: true,
                visualDensity: const VisualDensity(vertical: -1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                title: Text(
                  tr(lang.translationKey),
                  style: TextStyle(
                    fontFamily: 'FigtreeSB',
                    fontSize: 14,
                    color: colors.foreground,
                  ),
                ),
                trailing: Text(
                  lang.code.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'FigtreeBold',
                    fontSize: 12,
                    color: colors.muted,
                  ),
                ),
                onTap: () {
                  widget.onAutoTranslate(lang.code);
                  _goToPage(0);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------
  Widget _buildHeader({
    required BetterPlayerPanelColors colors,
    required String title,
    String? subtitle,
    Widget? leading,
    VoidCallback? onBack,
    required VoidCallback onClose,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: Icon(PhosphorIcons.caretLeft(), size: 22, color: colors.foreground),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
            )
          else if (leading != null)
            Padding(padding: const EdgeInsets.only(left: 6, right: 6), child: leading),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'FigtreeBold',
                    fontSize: 17,
                    color: colors.foreground,
                  ),
                ),
                if (subtitle?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(PhosphorIcons.x(), size: 20, color: colors.foreground),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildToolChip({
    required BetterPlayerPanelColors colors,
    required IconData icon,
    required String label,
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: colors.raised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'FigtreeSB',
                fontSize: 12.5,
                color: colors.foreground,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontFamily: 'FigtreeBold',
                    fontSize: 10.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _subtitleOffsetValue(Duration offset) {
    if (offset == Duration.zero) return '0.0s';
    final seconds = offset.inMilliseconds / 1000;
    final sign = seconds > 0 ? '+' : '−';
    return '$sign${seconds.abs().toStringAsFixed(1)}s';
  }
}
