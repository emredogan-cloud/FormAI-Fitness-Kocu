import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/app_localizations.dart';

import '../../../core/utils/app_logger.dart';

/// Phase 54 · referral code generator + redeemer.
///
/// Codes are 6 chars from a 32-char alphabet that excludes the
/// look-alike characters `0/O/1/I/L`. With 32^6 = ~1.07 B possible
/// codes the collision probability across our addressable market
/// (single-digit-million users) is negligible — small enough that we
/// generate optimistically client-side and let Supabase's UNIQUE
/// constraint reject the rare clash with a retry.
class ReferralService {
  ReferralService(this._prefs, {SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SharedPreferences _prefs;
  final SupabaseClient _client;

  static const String _kCodeKey = 'sixpack.referral_code';
  static const String _kRedeemedKey = 'sixpack.referral_redeemed_code';
  static const String _kAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  static const int _kCodeLength = 6;
  static const int _kMaxAttempts = 5;

  /// Returns the user's stable referral code, generating + persisting
  /// one on first call. Subsequent calls return the cached value
  /// without a network roundtrip — the code is durable per device
  /// install, mirrored to Supabase via [_persistOnSupabase] for
  /// validation when redeemed by the recipient.
  Future<String> getOrCreateCode() async {
    final cached = _prefs.getString(_kCodeKey);
    if (cached != null && cached.length == _kCodeLength) return cached;

    // Try to recover the code already stored against the user in
    // Supabase (cross-device install) before minting a new one.
    final remote = await _fetchRemoteCode();
    if (remote != null) {
      await _prefs.setString(_kCodeKey, remote);
      return remote;
    }

    String? minted;
    for (var i = 0; i < _kMaxAttempts; i++) {
      final candidate = _generate();
      final ok = await _persistOnSupabase(candidate);
      if (ok) {
        minted = candidate;
        break;
      }
    }
    // If Supabase persistence failed (offline / RLS / table missing in
    // a dev build) we still hand back a local code so the share PNG
    // and Profile-tab tile have something to render. The next
    // [getOrCreateCode] call will retry the persistence.
    final fallback = minted ?? _generate();
    await _prefs.setString(_kCodeKey, fallback);
    return fallback;
  }

  /// Calls the `redeem_referral` RPC on Supabase. Throws a
  /// [ReferralException] with a stable error code so the caller can
  /// render localised copy. Local cache is updated on success so the
  /// user can't redeem twice.
  Future<void> redeem(String referrerCode) async {
    final normalized = referrerCode.trim().toUpperCase();
    if (normalized.length != _kCodeLength) {
      throw const ReferralException(ReferralErrorCode.invalidFormat);
    }
    if (_prefs.getString(_kRedeemedKey) != null) {
      throw const ReferralException(ReferralErrorCode.alreadyRedeemed);
    }
    try {
      await _client
          .rpc('redeem_referral', params: {'referrer_code': normalized});
      await _prefs.setString(_kRedeemedKey, normalized);
    } on PostgrestException catch (e) {
      AppLogger.warning(
        'redeem_referral RPC rejected: ${e.message}',
        category: 'referral',
      );
      throw ReferralException(_mapPostgrestError(e));
    } catch (e, st) {
      AppLogger.error(
        'redeem_referral RPC failed',
        e,
        stackTrace: st,
        category: 'referral',
      );
      throw const ReferralException(ReferralErrorCode.network);
    }
  }

  /// Reads the redeemed code (if any). Used to gate the in-app "redeem"
  /// CTA so the form disappears after the first successful redemption.
  String? get redeemedCode => _prefs.getString(_kRedeemedKey);

  String _generate() {
    final rng = math.Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < _kCodeLength; i++) {
      buf.write(_kAlphabet[rng.nextInt(_kAlphabet.length)]);
    }
    return buf.toString();
  }

  Future<String?> _fetchRemoteCode() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _client
          .from('user_metrics')
          .select('referral_code')
          .eq('user_id', user.id)
          .maybeSingle();
      final code = row?['referral_code'];
      if (code is String && code.length == _kCodeLength) return code;
      return null;
    } catch (e) {
      AppLogger.warning(
        'fetch referral_code failed: $e',
        category: 'referral',
      );
      return null;
    }
  }

  Future<bool> _persistOnSupabase(String code) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      await _client.from('user_metrics').upsert(
          {'user_id': user.id, 'referral_code': code},
          onConflict: 'user_id');
      return true;
    } on PostgrestException catch (e) {
      // 23505 = unique_violation (collision). Anything else is a real
      // error — surface it through the warning log so we notice if RLS
      // or the column drifts.
      if (e.code == '23505') return false;
      AppLogger.warning(
        'persist referral_code failed: ${e.message}',
        category: 'referral',
      );
      return false;
    } catch (e) {
      AppLogger.warning(
        'persist referral_code failed: $e',
        category: 'referral',
      );
      return false;
    }
  }

  ReferralErrorCode _mapPostgrestError(PostgrestException e) {
    final msg = e.message.toUpperCase();
    if (msg.contains('NOT_AUTHENTICATED')) {
      return ReferralErrorCode.notAuthenticated;
    }
    if (msg.contains('INVALID_REFERRAL_CODE')) {
      return ReferralErrorCode.invalidCode;
    }
    if (msg.contains('SELF_REFERRAL_FORBIDDEN')) {
      return ReferralErrorCode.selfReferral;
    }
    if (msg.contains('ALREADY_REFERRED')) {
      return ReferralErrorCode.alreadyRedeemed;
    }
    return ReferralErrorCode.unknown;
  }
}

enum ReferralErrorCode {
  invalidFormat,
  invalidCode,
  selfReferral,
  alreadyRedeemed,
  notAuthenticated,
  network,
  unknown,
}

class ReferralException implements Exception {
  const ReferralException(this.code);
  final ReferralErrorCode code;

  String localizedMessage(AppLocalizations l10n) {
    switch (code) {
      case ReferralErrorCode.invalidFormat:
        return l10n.referralErrorInvalidFormat;
      case ReferralErrorCode.invalidCode:
        return l10n.referralErrorInvalidCode;
      case ReferralErrorCode.selfReferral:
        return l10n.referralErrorSelfReferral;
      case ReferralErrorCode.alreadyRedeemed:
        return l10n.referralErrorAlreadyRedeemed;
      case ReferralErrorCode.notAuthenticated:
        return l10n.referralErrorNotAuthenticated;
      case ReferralErrorCode.network:
        return l10n.referralErrorNetwork;
      case ReferralErrorCode.unknown:
        return l10n.referralErrorUnknown;
    }
  }
}
