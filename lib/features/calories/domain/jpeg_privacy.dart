/// Removes metadata segments from a JPEG, in Dart, before it is uploaded.
///
/// ------------------------------------------------------------
/// WHY THIS EXISTS WHEN image_picker ALREADY RE-ENCODES
/// ------------------------------------------------------------
///
/// `image_picker`'s `maxWidth`/`imageQuality` path decodes to a bitmap
/// and re-encodes, which drops EXIF as a side effect. That is almost
/// certainly enough — and "almost certainly" is the problem.
///
/// `docs/CALORIE_TRACKING_RESEARCH.md` §7 commits us to a specific claim
/// about food photographs: EXIF is stripped on-device before upload, so
/// the GPS coordinates of the user's kitchen never leave the handset.
/// Resting that on a side effect of another package's resize path means
/// the claim silently becomes false the day someone raises the size cap
/// above the source image (no resize, no re-encode, EXIF intact), swaps
/// the picker, or adds a share-sheet entry point that hands us the
/// original file.
///
/// So the strip is explicit, ours, and unit-tested. It costs a single
/// pass over a ~90 KB buffer, and it converts a privacy claim from
/// "expected" to "true by construction".
///
/// ------------------------------------------------------------
/// WHAT IT REMOVES
/// ------------------------------------------------------------
///
/// Every `APPn` marker (`FFE0`–`FFEF`) and every `COM` comment
/// (`FFFE`). That covers EXIF (`APP1`, where GPS lives), ICC profiles
/// (`APP2`), Photoshop/IPTC (`APP13`) and JFIF (`APP0`).
///
/// Dropping `APP0`/JFIF is safe: it carries only density units and an
/// optional thumbnail, and every decoder treats its absence as "assume
/// the defaults". Dropping `APP2`/ICC can shift colour slightly on a
/// wide-gamut source, which is an acceptable trade for a nutrition
/// estimate and not one a user could notice in a plate of food.
///
/// Everything structural — quantisation tables, Huffman tables, frame
/// headers, and the entropy-coded scan itself — is preserved byte for
/// byte, so the result is the same image.
library;

import 'dart:typed_data';

/// Marker bytes that need no length field and are copied as-is.
const int _markerPrefix = 0xFF;
const int _soi = 0xD8; // start of image
const int _eoi = 0xD9; // end of image
const int _sos = 0xDA; // start of scan — entropy data follows, stop parsing
const int _comment = 0xFE;

bool _isAppMarker(int marker) => marker >= 0xE0 && marker <= 0xEF;

/// Returns [bytes] with all metadata segments removed.
///
/// Returns the input unchanged when it is not a JPEG, or when the
/// structure is not something we recognise. A photo that reaches the
/// scanner un-stripped is worse than one that fails to send, so callers
/// that care should pair this with [hasMetadata] rather than assuming.
Uint8List stripJpegMetadata(Uint8List bytes) {
  if (!_looksLikeJpeg(bytes)) return bytes;

  final out = BytesBuilder(copy: false);
  out.addByte(_markerPrefix);
  out.addByte(_soi);

  var i = 2;
  while (i + 1 < bytes.length) {
    if (bytes[i] != _markerPrefix) {
      // Not sitting on a marker boundary — the file is malformed or uses
      // something we do not model. Bail out and return the original
      // rather than emit a corrupted image.
      return bytes;
    }

    // Fill bytes: a run of 0xFF before a marker is legal padding.
    var j = i;
    while (j < bytes.length && bytes[j] == _markerPrefix) {
      j++;
    }
    if (j >= bytes.length) return bytes;
    final marker = bytes[j];

    if (marker == _eoi) {
      out.addByte(_markerPrefix);
      out.addByte(_eoi);
      break;
    }

    if (marker == _sos) {
      // Everything from here to the end is the scan. Copy verbatim.
      out.add(Uint8List.sublistView(bytes, i));
      break;
    }

    if (j + 2 >= bytes.length) return bytes;
    final length = (bytes[j + 1] << 8) | bytes[j + 2];
    if (length < 2) return bytes;

    final segmentEnd = j + 1 + length;
    if (segmentEnd > bytes.length) return bytes;

    final drop = _isAppMarker(marker) || marker == _comment;
    if (!drop) {
      out.addByte(_markerPrefix);
      out.addByte(marker);
      out.add(Uint8List.sublistView(bytes, j + 1, segmentEnd));
    }

    i = segmentEnd;
  }

  return out.toBytes();
}

/// Whether [bytes] still carries any metadata segment.
///
/// Used by the test suite to prove the strip worked, and available to
/// callers that want to assert rather than trust.
bool hasMetadata(Uint8List bytes) {
  if (!_looksLikeJpeg(bytes)) return false;

  var i = 2;
  while (i + 3 < bytes.length) {
    if (bytes[i] != _markerPrefix) return false;
    var j = i;
    while (j < bytes.length && bytes[j] == _markerPrefix) {
      j++;
    }
    if (j >= bytes.length) return false;
    final marker = bytes[j];
    if (marker == _sos || marker == _eoi) return false;
    if (_isAppMarker(marker) || marker == _comment) return true;
    if (j + 2 >= bytes.length) return false;
    final length = (bytes[j + 1] << 8) | bytes[j + 2];
    if (length < 2) return false;
    i = j + 1 + length;
  }
  return false;
}

bool _looksLikeJpeg(Uint8List b) =>
    b.length > 4 && b[0] == _markerPrefix && b[1] == _soi;
