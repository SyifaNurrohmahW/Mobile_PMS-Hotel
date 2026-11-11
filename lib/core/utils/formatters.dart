import 'dart:math';
import 'package:intl/intl.dart';

class AppFormatters {
  const AppFormatters._();

  static final NumberFormat _idrFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _decimalFormat = NumberFormat.decimalPattern('id_ID');

  /// Safe dynamic double parser for MySQL/Knex DECIMAL or numeric fields
  static double parseDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.trim();
      if (cleaned.isEmpty) return fallback;
      return double.tryParse(cleaned) ??
          double.tryParse(cleaned.replaceAll(',', '')) ??
          fallback;
    }
    return fallback;
  }

  /// Safe dynamic int parser for MySQL/Knex integer or string fields
  static int parseInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final cleaned = value.trim();
      if (cleaned.isEmpty) return fallback;
      return int.tryParse(cleaned) ??
          double.tryParse(cleaned)?.toInt() ??
          fallback;
    }
    return fallback;
  }

  /// Safe dynamic bool parser for 1/0, "1"/"0", true/false
  static bool parseBool(dynamic value, [bool fallback = false]) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == '1' || lower == 'true' || lower == 'yes') return true;
      if (lower == '0' || lower == 'false' || lower == 'no') return false;
    }
    return fallback;
  }

  /// Safe dynamic string parser
  static String parseString(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final str = value.toString().trim();
    return str.isEmpty ? fallback : str;
  }

  /// Format number as Indonesian Rupiah (e.g. Rp 450.000)
  static String formatRupiah(dynamic value) {
    final amount = parseDouble(value);
    return _idrFormat.format(amount.round());
  }

  /// Format number with thousand separators without Rp prefix
  static String formatNumber(dynamic value) {
    final amount = parseDouble(value);
    return _decimalFormat.format(amount.round());
  }

  /// Format DateTime to yyyy-MM-dd for backend API payloads
  static String formatDateYmd(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Alias for formatDateYmd
  static String apiDate(DateTime date) => formatDateYmd(date);

  /// Alias for formatDateShortId
  static String shortDate(dynamic raw) => formatDateShortId(raw);

  /// Alias for formatDateTimeId
  static String shortDateTime(dynamic raw) => formatDateTimeId(raw);

  /// Calculate number of nights between check-in and check-out dates
  static int calculateNights(DateTime checkIn, DateTime checkOut) {
    final start = DateTime(checkIn.year, checkIn.month, checkIn.day);
    final end = DateTime(checkOut.year, checkOut.month, checkOut.day);
    final diff = end.difference(start).inDays;
    return diff > 0 ? diff : 1;
  }

  /// Parse date string safely
  static DateTime? tryParseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    // Handle dd/MM/yyyy format from dashboard summary active_stay
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(str)) {
      final parts = str.split('/');
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return DateTime.tryParse(str);
  }

  /// Format date to readable Indonesian date (e.g. "30 Okt 2026")
  static String formatDateShortId(dynamic raw) {
    final dt = tryParseDate(raw);
    if (dt == null) return raw?.toString() ?? '-';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  /// Format date to full Indonesian date (e.g. "Jumat, 30 Okt 2026")
  static String formatDateFullId(dynamic raw) {
    final dt = tryParseDate(raw);
    if (dt == null) return raw?.toString() ?? '-';
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return '${days[dt.weekday - 1]}, ${formatDateShortId(dt)}';
  }

  /// Format DateTime with time (e.g. "30 Okt 2026, 14:05")
  static String formatDateTimeId(dynamic raw) {
    final dt = tryParseDate(raw);
    if (dt == null) return raw?.toString() ?? '-';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${formatDateShortId(dt)}, $hh:$mm';
  }

  /// Extract YYYY-MM-DD from ISO or datetime string
  static String normalizeYmd(dynamic raw) {
    if (raw == null) return '';
    final str = raw.toString().trim();
    if (str.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(str)) {
      return str.substring(0, 10);
    }
    final dt = tryParseDate(raw);
    if (dt != null) return formatDateYmd(dt);
    return str;
  }

  /// Generate standardized payment reference number aligned with Sakai PMS Web
  static String generatePaymentRefNo(
    String paymentMethod, {
    String? bankName,
    String? cardType,
  }) {
    final now = DateTime.now();
    final datePart = DateFormat('yyyyMMdd-HHmm').format(now);
    final randPart = (1000 + Random().nextInt(9000)).toString();
    final method = paymentMethod.toLowerCase();

    return switch (method) {
      'cash' => 'CASH-$datePart-$randPart',
      'qris' => 'QRIS-$datePart-$randPart',
      'transfer' =>
        'TRF-${(bankName ?? 'BANK').toUpperCase().replaceAll(' ', '')}-$datePart-$randPart',
      'card' =>
        'EDC-${(cardType ?? 'CARD').toUpperCase()}-${(bankName ?? 'BANK').toUpperCase().replaceAll(' ', '')}-$datePart-$randPart',
      _ => 'PAY-$datePart-$randPart',
    };
  }
}

