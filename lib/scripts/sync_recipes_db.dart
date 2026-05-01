// `supabase` arrives transitively via `supabase_flutter`; depending on
// it directly is the right call for a CLI tool that doesn't want
// Flutter-coupled code paths.
// ignore_for_file: depend_on_referenced_packages

// Phase 72 · live-DB recipe image_url sync.
//
// What it does:
//   1. Reads SUPABASE_URL / SUPABASE_ANON_KEY (and optional
//      SUPABASE_SERVICE_ROLE_KEY) directly from `.env`.
//   2. Connects to the live `recipes` table and SELECTs every row.
//   3. Slugifies each title to derive the expected local asset path
//      (`photos/meals/<slug>.webp`) using the same Turkish-folding +
//      "ve" stop-word rules the Phase 69 hand-mapped seed already
//      follows (re-checked against all 30 known mappings).
//   4. Diffs the recipe set against what is actually present in
//      `photos/meals/` and prints a three-bucket report:
//         • MISSING — DB has the recipe, the bundled asset does not
//           exist yet. The PM needs to generate the image.
//         • ORPHAN  — bundled asset exists, no DB row references it.
//         • UPDATE  — DB row's image_url is not the expected path
//           (e.g. still an old Unsplash URL or a CDN-rewritten one).
//   5. Always writes `supabase/sql/phase72_image_url_sync.sql` —
//      a `BEGIN; UPDATE...; COMMIT;` batch the PM can paste into the
//      Supabase SQL Editor (which bypasses RLS as superuser). This is
//      the safe-by-default delivery.
//   6. Appends skeleton entries to `docs/MEAL_IMAGE_PROMPTS.md` for any
//      MISSING meals so the PM can fill in the English description and
//      feed each one to Midjourney without re-typing the file-path
//      block.
//   7. With `--execute` AND a SUPABASE_SERVICE_ROLE_KEY present, also
//      runs the UPDATEs through the SDK directly. The anon key cannot
//      pass the recipes_admin_update RLS policy, so this branch
//      silently degrades to "wrote SQL only" without it.
//
// Why the anon-key UPDATE is gated:
//   `supabase/sql/rls_policies.sql` restricts `recipes` UPDATE to
//   authenticated JWTs carrying `app_metadata.role == 'admin'`. The
//   service_role key bypasses RLS entirely. Don't add the service-role
//   key to the committed .env — it is repo-wide write access.
//
// Usage:
//   dart run lib/scripts/sync_recipes_db.dart            # read-only
//   dart run lib/scripts/sync_recipes_db.dart --execute  # writes too

import 'dart:io';

import 'package:supabase/supabase.dart';

const _seedDir = 'photos/meals';
// Phase 74 · root-level cleanup moved generated SQL into supabase/sql/
// and human-edited prompt docs into docs/. The script writes both, so
// the constants follow the new homes.
const _sqlOut = 'supabase/sql/phase72_image_url_sync.sql';
const _promptsDoc = 'docs/MEAL_IMAGE_PROMPTS.md';

Future<void> main(List<String> args) async {
  final execute = args.contains('--execute');

  final env = _readDotenv('.env');
  final url = env['SUPABASE_URL'];
  final anonKey = env['SUPABASE_ANON_KEY'];
  final serviceKey = env['SUPABASE_SERVICE_ROLE_KEY'];

  if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
    stderr.writeln('FATAL: SUPABASE_URL / SUPABASE_ANON_KEY missing in .env');
    exit(1);
  }

  // Pick the most-privileged key available for the SELECT. Service
  // role bypasses RLS so we can also use it for the UPDATEs below.
  final hasService = serviceKey != null && serviceKey.isNotEmpty;
  final keyForRead = hasService ? serviceKey : anonKey;
  final client = SupabaseClient(url, keyForRead);

  stdout.writeln('• Connected to $url');
  stdout.writeln('• Auth: ${hasService ? "service_role" : "anon"}');

  // 1. Fetch all recipes.
  final rows = await client.from('recipes').select('id, title, image_url');
  final recipes = (rows as List)
      .map((r) => _Recipe.fromJson(r as Map<String, dynamic>))
      .toList(growable: false);
  stdout.writeln('• Fetched ${recipes.length} recipes from `recipes`');

  // 2. List local assets.
  final localFiles = _listLocalMeals();
  stdout.writeln(
      '• Found ${localFiles.length} bundled .webp files in $_seedDir/');

  // 3. Bucketize.
  final missing = <_Recipe>[];
  final updates = <_Recipe>[];
  final correct = <_Recipe>[];
  final referencedSlugs = <String>{};

  for (final r in recipes) {
    final slug = _slugify(r.title);
    final expected = 'photos/meals/$slug.webp';
    referencedSlugs.add('$slug.webp');

    final hasAsset = localFiles.contains('$slug.webp');
    if (!hasAsset) {
      missing.add(r.copyWith(expectedPath: expected, slug: slug));
    }
    if (r.imageUrl != expected) {
      updates.add(r.copyWith(expectedPath: expected, slug: slug));
    } else {
      correct.add(r);
    }
  }

  final orphans = localFiles.difference(referencedSlugs).toList()..sort();

  // 4. Print report. The DB sometimes has duplicate rows with the same
  //    title (a separate cleanup concern); for the human-facing report
  //    we dedupe so the PM gets a clean per-asset list. The SQL batch
  //    below still issues one UPDATE per row so duplicates get fixed.
  final missingByTitle = <String, _Recipe>{};
  for (final r in missing) {
    missingByTitle.putIfAbsent(r.title, () => r);
  }
  final uniqueMissing = missingByTitle.values.toList()
    ..sort((a, b) => a.title.compareTo(b.title));

  stdout.writeln('\n=== MISSING MEALS (no bundled asset) ===');
  if (uniqueMissing.isEmpty) {
    stdout.writeln('  (none — every DB recipe has a matching .webp)');
  } else {
    final dupCount = missing.length - uniqueMissing.length;
    if (dupCount > 0) {
      stdout.writeln(
          '  (${uniqueMissing.length} unique titles; ${missing.length} rows total — $dupCount duplicate DB rows folded)');
    }
    for (final r in uniqueMissing) {
      stdout.writeln('  • "${r.title}"  →  expected ${r.expectedPath}');
    }
  }

  stdout.writeln('\n=== ORPHAN ASSETS (no DB row uses them) ===');
  if (orphans.isEmpty) {
    stdout.writeln('  (none)');
  } else {
    for (final f in orphans) {
      stdout.writeln('  • $f');
    }
  }

  stdout.writeln('\n=== ROWS NEEDING UPDATE ===');
  stdout.writeln(
      '  ${updates.length} of ${recipes.length} rows have image_url != expected path');
  stdout.writeln('  ${correct.length} are already correct.');

  // 5. Always emit the SQL batch (only for rows that need it).
  if (updates.isEmpty) {
    stdout.writeln('\n• No SQL written — all rows already correct.');
    if (File(_sqlOut).existsSync()) File(_sqlOut).deleteSync();
  } else {
    _writeSqlBatch(updates);
    stdout.writeln('\n• Wrote ${updates.length} UPDATE statements to $_sqlOut');
  }

  // 6. Append skeleton prompt entries for missing meals (deduped on
  //    title — see comment above).
  if (uniqueMissing.isNotEmpty) {
    _appendPromptsSkeleton(uniqueMissing);
    stdout.writeln(
        '• Appended ${uniqueMissing.length} skeleton entries to $_promptsDoc');
  }

  // 7. Execute against live DB only when explicitly asked AND with
  //    elevated credentials.
  if (!execute) {
    stdout.writeln(
        '\n• --execute not passed; live DB is unchanged. Run the SQL via'
        ' the Supabase SQL Editor when ready.');
    return;
  }
  if (!hasService) {
    stderr.writeln(
        '\n• --execute requested but SUPABASE_SERVICE_ROLE_KEY missing in .env.');
    stderr.writeln(
        '  The anon key cannot pass the recipes_admin_update RLS policy.');
    stderr.writeln(
        '  Either add SUPABASE_SERVICE_ROLE_KEY to .env (DO NOT commit it)');
    stderr.writeln('  or paste $_sqlOut into the Supabase SQL Editor instead.');
    exit(2);
  }

  stdout.writeln('\n• Executing ${updates.length} UPDATEs via service_role...');
  var ok = 0;
  for (final r in updates) {
    try {
      await client
          .from('recipes')
          .update({'image_url': r.expectedPath}).eq('id', r.id);
      ok++;
    } catch (e) {
      stderr.writeln('  FAIL ${r.id} "${r.title}": $e');
    }
  }
  stdout.writeln('• $ok / ${updates.length} rows updated.');
}

// --------------------------------------------------------------------------
// Helpers
// --------------------------------------------------------------------------

/// Minimal dotenv reader. Avoids `flutter_dotenv` because that package
/// pulls in Flutter and breaks `dart run`. The format we care about is
/// `KEY=VALUE` per line, with `#`-prefixed comments.
Map<String, String> _readDotenv(String path) {
  final out = <String, String>{};
  for (final line in File(path).readAsLinesSync()) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    final eq = t.indexOf('=');
    if (eq <= 0) continue;
    final k = t.substring(0, eq).trim();
    var v = t.substring(eq + 1).trim();
    if ((v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))) {
      v = v.substring(1, v.length - 1);
    }
    out[k] = v;
  }
  return out;
}

Set<String> _listLocalMeals() {
  final dir = Directory(_seedDir);
  if (!dir.existsSync()) return const {};
  return dir
      .listSync()
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last)
      .where((n) => n.endsWith('.webp'))
      .toSet();
}

/// Title → slug. Mirrors the hand-mapping the Phase 69 seed already
/// uses (verified against all 30 known recipes):
///   • Lowercase
///   • Turkish letter folding (ı→i, ğ→g, ş→s, ç→c, ü→u, ö→o, İ→i)
///   • Drop the conjunction "ve" ("and") as a whole-word token
///   • Spaces → underscore, then strip any non-[a-z0-9_]
String _slugify(String title) {
  const fold = {
    'İ': 'i',
    'I': 'i',
    'ı': 'i',
    'Ğ': 'g',
    'ğ': 'g',
    'Ş': 's',
    'ş': 's',
    'Ç': 'c',
    'ç': 'c',
    'Ü': 'u',
    'ü': 'u',
    'Ö': 'o',
    'ö': 'o',
  };
  var s = title;
  fold.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.toLowerCase();
  final parts = s.split(RegExp(r'\s+')).where((w) => w != 've' && w.isNotEmpty);
  s = parts.join('_');
  s = s.replaceAll(RegExp(r'[^a-z0-9_]'), '');
  s = s.replaceAll(RegExp(r'_+'), '_');
  return s;
}

void _writeSqlBatch(List<_Recipe> updates) {
  final buf = StringBuffer()
    ..writeln(
        '-- Phase 72 · auto-generated by lib/scripts/sync_recipes_db.dart')
    ..writeln(
        '-- Paste into the Supabase SQL Editor when you want to apply this batch.')
    ..writeln(
        '-- Wrapped in BEGIN/COMMIT so any failure rolls the whole batch back.')
    ..writeln('BEGIN;');
  for (final r in updates) {
    final escapedId = r.id.replaceAll("'", "''");
    final escapedPath = r.expectedPath.replaceAll("'", "''");
    buf.writeln(
        "UPDATE public.recipes SET image_url = '$escapedPath' WHERE id = '$escapedId';");
  }
  buf.writeln('COMMIT;');
  File(_sqlOut).writeAsStringSync(buf.toString());
}

void _appendPromptsSkeleton(List<_Recipe> missing) {
  final f = File(_promptsDoc);
  final existing = f.existsSync() ? f.readAsStringSync() : '';
  // Avoid double-appending the same skeleton block on repeat runs.
  if (existing.contains('## Phase 72 — Pending Generation')) {
    return;
  }
  final buf = StringBuffer()
    ..writeln()
    ..writeln('---')
    ..writeln()
    ..writeln('## Phase 72 — Pending Generation')
    ..writeln()
    ..writeln(
        'Live-DB recipes added after Phase 66 that still need a Midjourney')
    ..writeln(
        'pass. Replace `<TODO: english description>` with a one-line plate')
    ..writeln(
        'description and feed the prompt verbatim to Midjourney v6, then drop')
    ..writeln('the output at the file path indicated.')
    ..writeln();
  for (final r in missing) {
    buf
      ..writeln('### ${r.title}')
      ..writeln('**File Path:** `${r.expectedPath}`')
      ..writeln(
          '**Prompt:** Ultra realistic food photography, <TODO: english description>, modern ceramic plate, soft natural lighting, top-down angle, minimal clean background, high detail, 4k')
      ..writeln();
  }
  f.writeAsStringSync(existing + buf.toString());
}

class _Recipe {
  _Recipe({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.expectedPath = '',
    this.slug = '',
  });

  factory _Recipe.fromJson(Map<String, dynamic> j) => _Recipe(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] as String?) ?? '',
        imageUrl: j['image_url'] as String?,
      );

  final String id;
  final String title;
  final String? imageUrl;
  final String expectedPath;
  final String slug;

  _Recipe copyWith({String? expectedPath, String? slug}) => _Recipe(
        id: id,
        title: title,
        imageUrl: imageUrl,
        expectedPath: expectedPath ?? this.expectedPath,
        slug: slug ?? this.slug,
      );
}
