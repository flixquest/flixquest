import '../models/live_tv.dart';

/// Index bucket for names that do not start with A-Z (digits, symbols,
/// non-Latin scripts).
const String channelLetterOther = '#';

final RegExp _latinLetter = RegExp(r'[A-Z]');

/// The A-Z index letter a channel is filed under, from its display name.
String channelLetter(Channel channel) {
  final name = channel.name.trim();
  if (name.isEmpty) return channelLetterOther;
  final first = name[0].toUpperCase();
  return _latinLetter.hasMatch(first) ? first : channelLetterOther;
}

/// Letters that have at least one of [channels], A-Z first, then '#'.
List<String> channelLetters(Iterable<Channel> channels) {
  final letters = channels.map(channelLetter).toSet();
  final hasOther = letters.remove(channelLetterOther);
  return <String>[
    ...letters.toList()..sort(),
    if (hasOther) channelLetterOther,
  ];
}
