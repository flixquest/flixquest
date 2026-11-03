import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../catalog/media_item.dart';
import '../../core/di/injector.dart';
import '../../data/models/flix_ai.dart';
import '../../data/repositories/flix_ai_repository.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../design/flix_ai_mark.dart';
import '../../presentation/flix_ai/flix_ai_controller.dart';
import '../../provider/settings_provider.dart';
import '../../screens/user/login_screen.dart';
import '../../services/plus_navigation.dart';
import '../playback.dart';
import '../widgets/media_art.dart';
import '../widgets/page_kit.dart';
import '../widgets/pill_button.dart';
import '../widgets/title_sheet.dart' show mediaFacts, showTitleSheet;

/// The chat's reading column on tablets and TVs.
const _columnWidth = 820.0;

class FlixAiScreen extends StatefulWidget {
  const FlixAiScreen({this.controller, this.onOpenTitle, super.key});
  final FlixAiController? controller;
  final void Function(BuildContext context, MediaItem item)? onOpenTitle;

  @override
  State<FlixAiScreen> createState() => _FlixAiScreenState();
}

class _FlixAiScreenState extends State<FlixAiScreen>
    with WidgetsBindingObserver {
  final _message = TextEditingController();
  final _scroll = ScrollController();
  late final FlixAiController _chat;
  String? _lastOwner;
  bool _typed = false;

  /// Whether the reader is at the newest message, so a shrinking chat (the
  /// keyboard opening, or the composer growing) keeps it in view.
  bool _atLatest = true;
  double? _viewportHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final injected = widget.controller;
    if (injected != null) {
      _chat = injected;
    } else {
      final injector = context.read<AppInjector>();
      _chat = FlixAiController(FlixAiRepository(injector.laravelDio),
          owner: injector.session.ownerId,
          language: () => context.read<SettingsProvider>().appLanguage);
    }
    _lastOwner = _chat.owner.value;
    _chat.addListener(_changed);
    _message.addListener(_edited);
    unawaited(_chat.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_chat.initialize());
  }

  void _edited() {
    final typed = _message.text.trim().isNotEmpty;
    if (typed != _typed) setState(() => _typed = typed);
  }

  void _changed() {
    if (!mounted) return;
    if (_lastOwner != _chat.owner.value) {
      _lastOwner = _chat.owner.value;
      _message.clear();
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        unawaited(_scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic));
      }
    });
  }

  /// Keeps the newest message above the composer when the chat shrinks
  /// beneath a reader who was already reading it.
  bool _scrolled(Notification notification) {
    switch (notification) {
      case ScrollEndNotification(:final metrics, depth: 0):
        _atLatest = metrics.extentAfter <= AppSpace.xl;
      case ScrollMetricsNotification(:final metrics, depth: 0):
        final height = metrics.viewportDimension;
        final shrank = _viewportHeight != null && height < _viewportHeight!;
        _viewportHeight = height;
        if (shrank && _atLatest && _scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
    }
    return false;
  }

  void _send([String? suggestion]) {
    final text = suggestion ?? _message.text;
    if (!_chat.canSend || text.trim().isEmpty || text.runes.length > 1000) {
      return;
    }
    _message.clear();
    final owner = _chat.owner.value;
    unawaited(_chat.send(text).then((_) {
      if (mounted &&
          _chat.owner.value == owner &&
          _chat.errorCode != null &&
          _chat.pending == null) {
        _message.text = text;
      }
    }));
  }

  void _newChat() {
    _message.clear();
    _chat.newChat();
  }

  void _open(MediaItem item) {
    if (widget.onOpenTitle case final open?) {
      open(context, item);
    } else {
      unawaited(MobilePlayback.openDetails(context, item));
    }
  }

  Future<void> _openPlus() async {
    await openPlus(context);
    if (mounted) await _chat.initialize();
  }

  Future<void> _delete(BuildContext sheet, FlixAiConversation chat) async {
    final confirmed = await showConfirmDialog(sheet,
        title: tr('flix_ai_delete'),
        message: tr('flix_ai_delete_message'),
        confirmLabel: tr('flix_ai_delete'),
        icon: PhosphorIcons.trash(),
        destructive: true);
    if (confirmed == true) await _chat.deleteChat(chat.id);
  }

  Future<void> _history() => showAppSheet<void>(
        context,
        builder: (sheet) => ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * .7),
          child: AnimatedBuilder(
            animation: _chat,
            builder: (context, _) => _HistorySheet(
              chats: _chat.conversations,
              current: _chat.conversationId,
              busy: _chat.busy,
              onOpen: (chat) {
                Navigator.of(sheet).pop();
                unawaited(_chat.openChat(chat.id));
              },
              onDelete: (chat) => unawaited(_delete(sheet, chat)),
            ),
          ),
        ),
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chat.removeListener(_changed);
    if (widget.controller == null) _chat.dispose();
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final signedIn = _chat.signedIn;
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(
        title: 'FlixAI',
        contentWidth: _columnWidth,
        actions: [
          if (signedIn) ...[
            IconButton(
              tooltip: tr('flix_ai_history'),
              onPressed: _chat.busy ? null : _history,
              icon: Icon(PhosphorIcons.clockCounterClockwise(), size: 22),
            ),
            IconButton(
              tooltip: tr('flix_ai_new_chat'),
              onPressed: _chat.busy ? null : _newChat,
              icon: Icon(PhosphorIcons.notePencil(), size: 22),
            ),
          ],
        ],
        // Always two pixels tall, so the page doesn't jump while it loads.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _chat.loading
              ? const LinearProgressIndicator(
                  minHeight: 2, backgroundColor: Colors.transparent)
              : const SizedBox(height: 2),
        ),
      ),
      body: !signedIn
          ? _signIn()
          : SafeArea(
              top: false,
              child: Column(children: [
                Expanded(
                  child: NotificationListener<Notification>(
                    onNotification: _scrolled,
                    child: _conversation(palette),
                  ),
                ),
                ReadableWidth(
                  maxWidth: _columnWidth,
                  child: _Composer(
                    controller: _message,
                    enabled: _chat.enabled &&
                        !_chat.busy &&
                        _chat.pending == null &&
                        !_limitReached,
                    canSend: _chat.canSend && _typed,
                    usage: _chat.usage,
                    onSend: _send,
                    onPlus: _openPlus,
                  ),
                ),
              ]),
            ),
    );
  }

  bool get _limitReached {
    final usage = _chat.usage;
    if (_chat.errorCode == 'flix_ai_limit_reached') return true;
    return usage != null &&
        usage.remaining == 0 &&
        DateTime.now().isBefore(usage.resetsAt);
  }

  Widget _conversation(AppPalette palette) {
    final gutter = AppSpace.gutter(context);
    final pending = _chat.pending;
    final error = _chat.errorCode;
    final empty = _chat.turns.isEmpty && pending == null;
    return ListView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: AppSpace.sm, bottom: AppSpace.lg),
      children: [
        for (final child in [
          // An old chat opening shows nothing until it arrives, rather than
          // the welcome flashing past.
          if (empty && !(_chat.loading && _chat.conversationId != null))
            _Welcome(
                enabled: _chat.canSend,
                onAsk: _send,
                padding: EdgeInsets.symmetric(horizontal: gutter)),
          for (final turn in _chat.turns)
            _TurnView(turn: turn, gutter: gutter, onOpen: _open),
          if (pending != null) _UserBubble(pending.message, gutter: gutter),
          if (_chat.sending) _Thinking(gutter: gutter),
          if (!_chat.enabled && !_chat.loading)
            _Notice(
              gutter: gutter,
              icon: PhosphorIcons.cloudSlash(),
              message: tr('flix_ai_unavailable'),
            )
          else if (_limitReached)
            _Notice(
              gutter: gutter,
              icon: PhosphorIcons.hourglassMedium(),
              message: tr('flix_ai_limit'),
              detail: switch (_chat.usage) {
                final usage? => tr('flix_ai_reset', args: [
                    DateFormat.MMMd(Localizations.localeOf(context).toString())
                        .add_Hm()
                        .format(usage.resetsAt.toLocal()),
                  ]),
                null => null,
              },
              actionLabel: _chat.usage?.plan == 'free'
                  ? tr('flix_ai_more_with_plus')
                  : null,
              actionIcon: PhosphorIcons.crownSimple(),
              onAction: _openPlus,
            )
          else if (error != null)
            _Notice(
              gutter: gutter,
              icon: PhosphorIcons.warningCircle(),
              error: true,
              message: tr(
                  error == 'flix_ai_busy' ? 'flix_ai_busy' : 'flix_ai_error'),
              actionLabel: pending != null
                  ? tr('flix_ai_retry')
                  : _chat.turns.isEmpty
                      ? tr('flix_ai_refresh')
                      : null,
              actionIcon: PhosphorIcons.arrowClockwise(),
              onAction: _chat.busy
                  ? null
                  : pending != null
                      ? () => unawaited(_chat.retry())
                      : () => unawaited(_chat.initialize()),
            ),
        ])
          ReadableWidth(maxWidth: _columnWidth, child: child),
      ],
    );
  }

  Widget _signIn() {
    final palette = AppPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const _Mark(size: 64),
            const SizedBox(height: AppSpace.xl),
            Text(tr('flix_ai_intro'),
                textAlign: TextAlign.center,
                style: AppType.sectionHeader.copyWith(
                    fontFamily: AppType.bold, color: palette.foreground)),
            const SizedBox(height: AppSpace.sm),
            Text(tr('flix_ai_sign_in'),
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: palette.mutedText)),
            const SizedBox(height: AppSpace.xl),
            PillButton(
              label: tr('login'),
              icon: PhosphorIcons.signIn(),
              primary: true,
              onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const LoginScreen())),
            ),
          ]),
        ),
      ),
    );
  }
}

/// FlixAI's mark in a soft circle, beside its replies; its sparks twinkle
/// while one is on its way.
class _Mark extends StatelessWidget {
  const _Mark({this.size = 28, this.thinking = false});
  final double size;
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration:
          BoxDecoration(color: palette.idleFill, shape: BoxShape.circle),
      child: FlixAiMark(
          height: size * .58, color: palette.foreground, thinking: thinking),
    );
  }
}

/// Something to press: it rings in ink under keyboard focus.
class _Tappable extends StatefulWidget {
  const _Tappable(
      {required this.child,
      required this.onTap,
      this.onLongPress,
      this.radius = AppRadii.hero,
      this.color});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Color? color;

  @override
  State<_Tappable> createState() => _TappableState();
}

class _TappableState extends State<_Tappable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final shape = BorderRadius.circular(widget.radius);
    return Material(
      color: widget.color ?? Colors.transparent,
      borderRadius: shape,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        borderRadius: shape,
        focusColor: Colors.transparent,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          foregroundDecoration: BoxDecoration(
            borderRadius: shape,
            border: Border.all(
                color: _focused ? palette.foreground : Colors.transparent,
                width: 2),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome(
      {required this.enabled, required this.onAsk, required this.padding});
  final bool enabled;
  final ValueChanged<String> onAsk;
  final EdgeInsetsGeometry padding;

  static final _examples = <(String, IconData)>[
    ('flix_ai_example_romance', PhosphorIcons.heart()),
    ('flix_ai_example_tv', PhosphorIcons.planet()),
    ('flix_ai_example_thriller', PhosphorIcons.detective()),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: padding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppSpace.xxl),
        const _Mark(size: 52),
        const SizedBox(height: AppSpace.xl),
        Text(tr('flix_ai_intro'),
            style: AppType.scaled(context, AppType.pageTitle)
                .copyWith(color: palette.foreground)),
        const SizedBox(height: AppSpace.sm),
        Text(tr('flix_ai_subtitle'),
            style: AppType.scaled(context, AppType.body).copyWith(
                fontSize: 15, height: 1.45, color: palette.mutedText)),
        const SizedBox(height: AppSpace.xxl),
        KickerHeading(tr('flix_ai_try'),
            padding: const EdgeInsets.only(bottom: AppSpace.sm)),
        for (final (key, icon) in _examples)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: _Tappable(
              color: palette.surface,
              onTap: enabled ? () => onAsk(tr(key)) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.lg, vertical: 14),
                child: Row(children: [
                  Icon(icon, size: 20, color: palette.mutedText),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                      child: Text(tr(key),
                          style: AppType.cardTitle.copyWith(
                              fontSize: 15, color: palette.foreground))),
                  const SizedBox(width: AppSpace.sm),
                  Icon(PhosphorIcons.arrowUpRight(),
                      size: 16, color: palette.mutedText),
                ]),
              ),
            ),
          ),
        const SizedBox(height: AppSpace.lg),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(PhosphorIcons.lockSimple(),
                size: 14, color: palette.mutedText),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
              child: Text(tr('flix_ai_privacy'),
                  style: AppType.metadata
                      .copyWith(fontSize: 11.5, color: palette.mutedText))),
        ]),
      ]),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text, {required this.gutter});
  final String text;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding:
          EdgeInsetsDirectional.fromSTEB(gutter * 3, AppSpace.lg, gutter, 0),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: palette.idleFill,
            borderRadius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(20),
              topEnd: Radius.circular(20),
              bottomStart: Radius.circular(20),
              bottomEnd: Radius.circular(6),
            ),
          ),
          child: SelectableText(text,
              style: AppType.body.copyWith(
                  fontSize: 15, height: 1.4, color: palette.foreground)),
        ),
      ),
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView(
      {required this.turn, required this.gutter, required this.onOpen});
  final FlixAiTurn turn;
  final double gutter;
  final ValueChanged<MediaItem> onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final note = AppType.metadata
        .copyWith(fontSize: 13, height: 1.4, color: palette.mutedText);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _UserBubble(turn.message, gutter: gutter),
      _Reply(
        gutter: gutter,
        children: [
          SelectableText(turn.reply,
              style: AppType.body.copyWith(
                  fontSize: 15, height: 1.55, color: palette.foreground)),
          if (turn.keywords.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final keyword in turn.keywords) _Tag(keyword),
            ]),
          ],
          if (turn.broadened) ...[
            const SizedBox(height: AppSpace.md),
            Text(tr('flix_ai_broadened'), style: note),
          ],
          if (turn.recommendations.isEmpty && !turn.needsClarification) ...[
            const SizedBox(height: AppSpace.md),
            Text(tr('flix_ai_no_matches'), style: note),
          ],
        ],
      ),
      if (turn.recommendations.isNotEmpty)
        _Recommendations(
            items: turn.recommendations, gutter: gutter, onOpen: onOpen),
    ]);
  }
}

/// A reply from FlixAI: its mark, then what it said, with no bubble.
class _Reply extends StatelessWidget {
  const _Reply(
      {required this.gutter, required this.children, this.thinking = false});
  final double gutter;
  final List<Widget> children;
  final bool thinking;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(gutter, AppSpace.lg, gutter, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Mark(thinking: thinking),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children),
            ),
          ),
        ]),
      );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: palette.hairline),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(label,
          style: AppType.metadata.copyWith(color: palette.secondaryText)),
    );
  }
}

/// The titles a reply picked, on a row that runs to the screen's edges.
class _Recommendations extends StatelessWidget {
  const _Recommendations(
      {required this.items, required this.gutter, required this.onOpen});
  final List<MediaItem> items;
  final double gutter;
  final ValueChanged<MediaItem> onOpen;

  static const _width = 128.0;
  static const _posterHeight = _width * 3 / 2;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final scale = MediaQuery.textScalerOf(context);
    final height = _posterHeight +
        AppSpace.sm +
        scale.scale(18) * 2 +
        scale.scale(16) +
        AppSpace.sm;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg),
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          // In line with the reply's text, past the mark.
          padding: EdgeInsetsDirectional.only(start: gutter + 40, end: gutter),
          clipBehavior: Clip.none,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpace.md),
          itemBuilder: (context, index) {
            final item = items[index];
            return SizedBox(
              width: _width,
              child: _Tappable(
                radius: AppRadii.card,
                onTap: () => onOpen(item),
                onLongPress: () => showTitleSheet(context, item),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        child: Stack(children: [
                          SizedBox(
                              width: _width,
                              height: _posterHeight,
                              child: MediaArt(
                                  item: item,
                                  path: item.posterPath ?? item.backdropPath,
                                  width: _width)),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: palette.hairline, width: .5),
                                borderRadius:
                                    BorderRadius.circular(AppRadii.card),
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: AppSpace.sm),
                      Text(item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.cardTitle.copyWith(
                              fontSize: 13, color: palette.foreground)),
                      Text(mediaFacts(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.metadata.copyWith(
                              fontSize: 11, color: palette.mutedText)),
                    ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// While a reply is on its way: the mark's sparks twinkle, beside a line on
/// what is happening.
class _Thinking extends StatelessWidget {
  const _Thinking({required this.gutter});
  final double gutter;

  @override
  Widget build(BuildContext context) => _Reply(
        gutter: gutter,
        thinking: true,
        children: [
          Text(tr('flix_ai_thinking'),
              style: AppType.body
                  .copyWith(color: AppPalette.of(context).mutedText)),
        ],
      );
}

/// Something about the chat itself, rather than a reply: it's unavailable,
/// the day's allowance is spent, or a request failed.
class _Notice extends StatelessWidget {
  const _Notice({
    required this.gutter,
    required this.icon,
    required this.message,
    this.detail,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.error = false,
  });
  final double gutter;
  final IconData icon;
  final String message;
  final String? detail;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final tint =
        error ? Theme.of(context).colorScheme.error : palette.foreground;
    final detail = this.detail;
    final actionLabel = this.actionLabel;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, AppSpace.xl, gutter, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.hero),
          border: Border.all(
              color: error ? tint.withValues(alpha: .35) : palette.hairline),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 22, color: tint),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(message,
                  style: AppType.cardTitle.copyWith(
                      fontSize: 15, height: 1.35, color: palette.foreground)),
              if (detail != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(detail,
                    style: AppType.metadata
                        .copyWith(fontSize: 13, color: palette.mutedText)),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: AppSpace.md),
                PillButton(
                    label: actionLabel, icon: actionIcon, onPressed: onAction),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The message field in a soft pill with the send button inside it, and
/// the day's allowance underneath.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.canSend,
    required this.usage,
    required this.onSend,
    required this.onPlus,
  });
  final TextEditingController controller;
  final bool enabled;
  final bool canSend;
  final FlixAiUsage? usage;
  final VoidCallback onSend;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final usage = this.usage;
    const none = InputBorder.none;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, AppSpace.xs, gutter, AppSpace.sm),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 4, 6, 4),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: palette.hairline),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                maxLength: 1000,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onSend(),
                cursorColor: palette.foreground,
                style: AppType.body.copyWith(
                    fontSize: 15, height: 1.35, color: palette.foreground),
                decoration: InputDecoration(
                  hintText: tr('flix_ai_hint'),
                  hintStyle: AppType.body.copyWith(
                      fontSize: 15, height: 1.35, color: palette.mutedText),
                  counterText: '',
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: none,
                  enabledBorder: none,
                  focusedBorder: none,
                  disabledBorder: none,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            IconButton(
              tooltip: tr('flix_ai_send'),
              onPressed: canSend ? onSend : null,
              style: IconButton.styleFrom(
                fixedSize: const Size.square(40),
                minimumSize: const Size.square(40),
                backgroundColor: palette.focusFill,
                foregroundColor: palette.onFocus,
                disabledBackgroundColor: palette.idleFill,
                disabledForegroundColor: palette.mutedText,
              ),
              icon: Icon(PhosphorIcons.arrowUp(PhosphorIconsStyle.bold),
                  size: 18),
            ),
          ]),
        ),
        if (usage != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 18, top: 2),
            child: Row(children: [
              Expanded(
                child: Text(
                    tr('flix_ai_remaining',
                        args: ['${usage.remaining}', '${usage.limit}']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.metadata.copyWith(color: palette.mutedText)),
              ),
              if (usage.plan == 'free')
                TextButton.icon(
                  onPressed: onPlus,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.foreground,
                    textStyle:
                        AppType.metadata.copyWith(fontFamily: AppType.semiBold),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(PhosphorIcons.crownSimple(), size: 14),
                  label: Text(tr('flix_ai_more_with_plus')),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({
    required this.chats,
    required this.current,
    required this.busy,
    required this.onOpen,
    required this.onDelete,
  });
  final List<FlixAiConversation> chats;
  final String? current;
  final bool busy;
  final ValueChanged<FlixAiConversation> onOpen;
  final ValueChanged<FlixAiConversation> onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.xl, 0, AppSpace.xl, AppSpace.sm),
            child: Text(tr('flix_ai_history'),
                style: AppType.sectionHeader.copyWith(
                    fontFamily: AppType.bold, color: palette.foreground)),
          ),
          if (chats.isEmpty)
            SizedBox(
              height: 220,
              child: EmptyState(
                  icon: PhosphorIcons.chatsCircle(),
                  title: tr('flix_ai_no_history')),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.sm, 0, AppSpace.sm, AppSpace.lg),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  final open = chat.id == current;
                  return _Tappable(
                    onTap: busy ? null : () => onOpen(chat),
                    color: open ? palette.idleFillFaint : null,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpace.md, 6, 0, 6),
                      child: Row(children: [
                        Icon(
                            open
                                ? PhosphorIcons.chatCircleText(
                                    PhosphorIconsStyle.fill)
                                : PhosphorIcons.chatCircleText(),
                            size: 20,
                            color:
                                open ? palette.foreground : palette.mutedText),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Text(chat.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.cardTitle.copyWith(
                                  fontSize: 15,
                                  height: 1.3,
                                  color: palette.foreground)),
                        ),
                        IconButton(
                          tooltip: tr('flix_ai_delete'),
                          color: palette.mutedText,
                          onPressed: busy ? null : () => onDelete(chat),
                          icon: Icon(PhosphorIcons.trash(), size: 20),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
        ]);
  }
}
