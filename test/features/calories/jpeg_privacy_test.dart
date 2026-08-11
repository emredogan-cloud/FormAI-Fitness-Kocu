import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixpack_ai/features/calories/domain/jpeg_privacy.dart';

/// Proves the privacy claim in `docs/CALORIE_TRACKING_RESEARCH.md` §7
/// rather than assuming it.
///
/// The claim is specific — EXIF is stripped on-device, so the GPS in a
/// food photograph never leaves the handset — and it was previously
/// resting on a side effect of `image_picker`'s resize path. These tests
/// are what make it a property of our own code.
void main() {
  /// A minimal but structurally real JPEG: SOI, the segments named, then
  /// SOS with a scrap of entropy data, then EOI.
  Uint8List buildJpeg({
    bool withExif = false,
    bool withComment = false,
    bool withIcc = false,
  }) {
    final b = BytesBuilder();
    b.add([0xFF, 0xD8]); // SOI

    void segment(int marker, List<int> payload) {
      final len = payload.length + 2;
      b.add([0xFF, marker, (len >> 8) & 0xFF, len & 0xFF]);
      b.add(payload);
    }

    // APP0 / JFIF — always present on a real camera JPEG.
    segment(0xE0, [0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00]);

    if (withExif) {
      // APP1 with the "Exif\0\0" signature and a byte standing in for the
      // GPS IFD this test exists to remove.
      segment(0xE1, [0x45, 0x78, 0x69, 0x66, 0x00, 0x00, 0xDE, 0xAD]);
    }
    if (withIcc) {
      segment(0xE2, [0x49, 0x43, 0x43, 0x5F]); // APP2 / ICC_
    }
    if (withComment) {
      segment(0xFE, [0x68, 0x69]); // COM "hi"
    }

    // DQT — structural, must survive.
    segment(0xDB, List<int>.filled(65, 0x10));
    // SOF0 — structural, must survive.
    segment(0xC0, [0x08, 0x00, 0x10, 0x00, 0x10, 0x01, 0x01, 0x11, 0x00]);

    b.add([0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00]);
    b.add([0x12, 0x34, 0x56, 0x78]); // entropy-coded scan
    b.add([0xFF, 0xD9]); // EOI
    return b.toBytes();
  }

  group('stripJpegMetadata', () {
    test('removes EXIF, and hasMetadata proves it', () {
      final withExif = buildJpeg(withExif: true);
      expect(hasMetadata(withExif), isTrue,
          reason: 'the fixture must actually carry metadata, or the '
              'test below proves nothing');

      final stripped = stripJpegMetadata(withExif);
      expect(hasMetadata(stripped), isFalse);
      expect(stripped.length, lessThan(withExif.length));
    });

    test('removes APP0, APP2 and COM as well as APP1', () {
      // The point is not EXIF specifically — it is that no metadata
      // segment survives. IPTC and Photoshop blocks live in the same
      // APPn range and can carry location too.
      final loaded =
          buildJpeg(withExif: true, withIcc: true, withComment: true);
      final stripped = stripJpegMetadata(loaded);
      expect(hasMetadata(stripped), isFalse);
    });

    test('preserves the structural segments and the scan byte for byte', () {
      final stripped = stripJpegMetadata(buildJpeg(withExif: true));

      // SOI
      expect(stripped.sublist(0, 2), [0xFF, 0xD8]);
      // DQT and SOF0 survive.
      expect(_containsMarker(stripped, 0xDB), isTrue, reason: 'DQT dropped');
      expect(_containsMarker(stripped, 0xC0), isTrue, reason: 'SOF0 dropped');
      // The entropy-coded scan is intact and still ends with EOI.
      expect(stripped.sublist(stripped.length - 6),
          [0x12, 0x34, 0x56, 0x78, 0xFF, 0xD9]);
    });

    test('a JPEG with no metadata is returned unharmed', () {
      final clean = stripJpegMetadata(buildJpeg());
      expect(hasMetadata(clean), isFalse);
      // Idempotent — running it twice changes nothing.
      expect(stripJpegMetadata(clean), clean);
    });

    test('a non-JPEG is passed through rather than mangled', () {
      // A PNG must come out the other side identical: silently corrupting
      // an unexpected format would be a worse failure than not stripping.
      final png = Uint8List.fromList(
          [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]);
      expect(stripJpegMetadata(png), png);
      expect(hasMetadata(png), isFalse);
    });

    test('truncated input is returned rather than half-written', () {
      final truncated = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1, 0x00]);
      expect(stripJpegMetadata(truncated), truncated);
    });
  });

  group('against a real encoder', () {
    test('strips metadata from a JPEG produced by ImageMagick', () async {
      // The hand-built fixtures above prove the parser. This proves it
      // against bytes we did not write — a real encoder's segment order,
      // padding and table layout.
      final tmp = await Directory.systemTemp.createTemp('formai_exif');
      addTearDown(() => tmp.delete(recursive: true));
      final path = '${tmp.path}/probe.jpg';

      // `Process.run` THROWS when the binary is absent — it does not
      // return a non-zero exit code. Guarding only on exitCode passed
      // locally and turned CI red, because the runner has no ImageMagick.
      ProcessResult made;
      try {
        made = await Process.run('convert', [
          '-size',
          '32x32',
          'xc:red',
          '-set',
          'comment',
          'formai-test-comment',
          'jpeg:$path',
        ]);
      } on ProcessException {
        markTestSkipped('ImageMagick not installed on this machine');
        return;
      }
      if (made.exitCode != 0) {
        markTestSkipped('ImageMagick present but failed: ${made.stderr}');
        return;
      }

      final original = await File(path).readAsBytes();
      expect(hasMetadata(original), isTrue,
          reason: 'the encoder should have written at least JFIF/COM');

      final stripped = stripJpegMetadata(original);
      expect(hasMetadata(stripped), isFalse);

      // Still a decodable JPEG afterwards — verified by the decoder, not
      // by our own parser agreeing with itself.
      final out = '${tmp.path}/stripped.jpg';
      await File(out).writeAsBytes(stripped);
      ProcessResult identify;
      try {
        identify = await Process.run('identify', ['-format', '%wx%h', out]);
      } on ProcessException {
        markTestSkipped('ImageMagick identify not installed');
        return;
      }
      expect(identify.exitCode, 0,
          reason: 'stripped output failed to decode: ${identify.stderr}');
      expect(identify.stdout.toString().trim(), '32x32');
    });
  });
}

bool _containsMarker(Uint8List bytes, int marker) {
  for (var i = 0; i + 1 < bytes.length; i++) {
    if (bytes[i] == 0xFF && bytes[i + 1] == marker) return true;
  }
  return false;
}
