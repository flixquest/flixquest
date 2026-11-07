// Creates the scraper key inputs and prints the value the server needs.
//
//   dart run tool/scraper_key.dart init
//   dart run tool/scraper_key.dart server-key --mode prod --cert <sha256>
//
// `server-key` prints a secret. Run it in your own terminal, not anywhere its
// output is logged or shared.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flixquest/core/network/scraper_v3/scraper_key_derivation.dart';

const _envPath = '.env';
const _packageName = 'dev.beamlak.flixquest_v2';

Future<void> main(List<String> args) async {
  switch (args.firstOrNull) {
    case 'init':
      _init();
    case 'server-key':
      await _serverKey(args.skip(1).toList());
    default:
      _usage();
  }
}

void _usage() {
  stderr.writeln('Usage: dart run tool/scraper_key.dart init');
  stderr.writeln('       dart run tool/scraper_key.dart server-key '
      '--mode <prod|dev> --cert <sha256>');
  exitCode = 64;
}

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

void _init() {
  final file = File(_envPath);
  final existing = file.existsSync() ? file.readAsStringSync() : '';
  if (existing.contains('SCRAPER_')) {
    stderr.writeln('$_envPath already has scraper key inputs. Replacing them '
        'changes every key, so remove those lines first if that is what you '
        'want.');
    exitCode = 1;
    return;
  }
  final now = DateTime.now();
  final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  final nativeSecret = _randomBytes(32)
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  file.writeAsStringSync(
    '''

# Inputs to the scraper v3 key. Changing any of these changes the key.
SCRAPER_PROD_KID=$month
SCRAPER_PROD_FRAGMENT=${base64Encode(_randomBytes(32))}
SCRAPER_DEV_KID=dev-$month
SCRAPER_DEV_FRAGMENT=${base64Encode(_randomBytes(32))}
SCRAPER_NATIVE_SECRET=$nativeSecret
''',
    mode: FileMode.append,
  );
  stdout.writeln('Added scraper key inputs to $_envPath. Next: dart run '
      'build_runner clean && dart run build_runner build '
      '--delete-conflicting-outputs');
}

Future<void> _serverKey(List<String> args) async {
  String? option(String name) {
    final index = args.indexOf(name);
    return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
  }

  final mode = option('--mode');
  final cert = option('--cert');
  if ((mode != 'prod' && mode != 'dev') || cert == null) {
    _usage();
    return;
  }

  final env = <String, String>{
    for (final line in File(_envPath).readAsLinesSync())
      if (line.contains('=') && !line.startsWith('#'))
        line.substring(0, line.indexOf('=')):
            line.substring(line.indexOf('=') + 1),
  };
  final prefix = 'SCRAPER_${mode!.toUpperCase()}';
  final kid = env['${prefix}_KID']!;
  final certificateHash = normalizeCertificateHash(cert);
  final nativeSecret = env['SCRAPER_NATIVE_SECRET']!;

  final mix = await Hmac.sha256().calculateMac(
    nativeMixInput(
      packageName: _packageName,
      certificateHash: certificateHash,
    ),
    secretKey: SecretKey(<int>[
      for (var i = 0; i < nativeSecret.length; i += 2)
        int.parse(nativeSecret.substring(i, i + 2), radix: 16),
    ]),
  );
  final rootKey = await deriveScraperRootKey(
    fragment: base64Decode(env['${prefix}_FRAGMENT']!),
    nativeMix: mix.bytes,
    certificateHash: certificateHash,
    packageName: _packageName,
    kid: kid,
  );
  stdout.writeln('$kid:${base64Encode(rootKey)}');
}
