import '../../../core/utils/formatters.dart';

class CashierShiftStats {
  const CashierShiftStats({
    required this.totalCheckinKamar,
    required this.totalCheckinPax,
    required this.walkinKamar,
    required this.reservasiKamar,
    required this.totalCheckoutKamar,
    required this.totalCheckoutPax,
    required this.openingCash,
    required this.totalCashIn,
    required this.totalNonCashIn,
    required this.totalPaymentIn,
    required this.systemCash,
    required this.totalFasilitasItem,
    required this.totalFasilitasAmount,
  });

  final int totalCheckinKamar;
  final int totalCheckinPax;
  final int walkinKamar;
  final int reservasiKamar;
  final int totalCheckoutKamar;
  final int totalCheckoutPax;
  final double openingCash;
  final double totalCashIn;
  final double totalNonCashIn;
  final double totalPaymentIn;
  final double systemCash;
  final int totalFasilitasItem;
  final double totalFasilitasAmount;

  factory CashierShiftStats.fromJson(Map<String, dynamic> json) {
    return CashierShiftStats(
      totalCheckinKamar: AppFormatters.parseInt(json['total_checkin_kamar']),
      totalCheckinPax: AppFormatters.parseInt(json['total_checkin_pax']),
      walkinKamar: AppFormatters.parseInt(json['walkin_kamar']),
      reservasiKamar: AppFormatters.parseInt(json['reservasi_kamar']),
      totalCheckoutKamar: AppFormatters.parseInt(json['total_checkout_kamar']),
      totalCheckoutPax: AppFormatters.parseInt(json['total_checkout_pax']),
      openingCash: AppFormatters.parseDouble(json['opening_cash']),
      totalCashIn: AppFormatters.parseDouble(json['total_cash_in']),
      totalNonCashIn: AppFormatters.parseDouble(json['total_non_cash_in']),
      totalPaymentIn: AppFormatters.parseDouble(json['total_payment_in']),
      systemCash: AppFormatters.parseDouble(json['system_cash']),
      totalFasilitasItem: AppFormatters.parseInt(json['total_fasilitas_item']),
      totalFasilitasAmount:
          AppFormatters.parseDouble(json['total_fasilitas_amount']),
    );
  }
}

class CashierShift {
  const CashierShift({
    required this.kodeCashierShift,
    required this.kodeCabang,
    required this.kodeCashierCounter,
    required this.sesi,
    required this.namaShift,
    required this.namaCounter,
    required this.cabangName,
    required this.openingCash,
    required this.openedAt,
    required this.cashierName,
    this.shiftMulai,
    this.shiftSelesai,
    this.stats,
  });

  final String kodeCashierShift;
  final String kodeCabang;
  final String kodeCashierCounter;
  final String sesi;
  final String namaShift;
  final String namaCounter;
  final String cabangName;
  final double openingCash;
  final String openedAt;
  final String cashierName;
  final String? shiftMulai;
  final String? shiftSelesai;
  final CashierShiftStats? stats;

  double get systemCash => stats?.systemCash ?? openingCash;
  bool get hasActiveShift => kodeCashierShift.isNotEmpty;

  factory CashierShift.fromJson(Map<String, dynamic> json) {
    final statsMap = json['stats'] is Map
        ? Map<String, dynamic>.from(json['stats'] as Map)
        : null;
    final sesiStr = AppFormatters.parseString(json['sesi'], 'pagi');
    return CashierShift(
      kodeCashierShift: AppFormatters.parseString(json['kode_cashier_shift']),
      kodeCabang: AppFormatters.parseString(json['kode_cabang']),
      kodeCashierCounter:
          AppFormatters.parseString(json['kode_cashier_counter']),
      sesi: sesiStr,
      namaShift: AppFormatters.parseString(json['nama_shift'], sesiStr),
      namaCounter: AppFormatters.parseString(
        json['nama_counter'],
        AppFormatters.parseString(json['kode_cashier_counter'], 'Loket Kasir'),
      ),
      cabangName: AppFormatters.parseString(json['cabang_name']),
      openingCash: AppFormatters.parseDouble(json['opening_cash']),
      openedAt: AppFormatters.parseString(json['opened_at']),
      cashierName: AppFormatters.parseString(
        json['cashier_name'],
        AppFormatters.parseString(json['cashier_username'], 'Kasir'),
      ),
      shiftMulai: json['shift_mulai']?.toString(),
      shiftSelesai: json['shift_selesai']?.toString(),
      stats: statsMap != null ? CashierShiftStats.fromJson(statsMap) : null,
    );
  }
}

class CashierCounter {
  const CashierCounter({
    required this.kodeCounter,
    required this.kodeCabang,
    required this.name,
    required this.isActive,
    required this.isInUse,
    this.activeUser,
    required this.statusKeterangan,
  });

  final String kodeCounter;
  final String kodeCabang;
  final String name;
  final bool isActive;
  final bool isInUse;
  final String? activeUser;
  final String statusKeterangan;

  factory CashierCounter.fromJson(Map<String, dynamic> json) {
    return CashierCounter(
      kodeCounter: AppFormatters.parseString(json['kode_counter']),
      kodeCabang: AppFormatters.parseString(json['kode_cabang']),
      name: AppFormatters.parseString(json['name'], 'Loket Kasir'),
      isActive: AppFormatters.parseBool(json['is_active'], true),
      isInUse: AppFormatters.parseBool(json['is_in_use']),
      activeUser: json['active_user']?.toString(),
      statusKeterangan:
          AppFormatters.parseString(json['status_keterangan'], 'Tersedia'),
    );
  }
}

class MasterShiftOption {
  const MasterShiftOption({
    required this.kodeShift,
    required this.namaShift,
    required this.waktuMulai,
    required this.waktuSelesai,
    required this.defaultOpeningCash,
    required this.isNightAudit,
  });

  final String kodeShift;
  final String namaShift;
  final String waktuMulai;
  final String waktuSelesai;
  final double defaultOpeningCash;
  final bool isNightAudit;

  String get timeRangeLabel {
    final start =
        waktuMulai.length >= 5 ? waktuMulai.substring(0, 5) : waktuMulai;
    final end =
        waktuSelesai.length >= 5 ? waktuSelesai.substring(0, 5) : waktuSelesai;
    if (start.isEmpty && end.isEmpty) return namaShift;
    return '$namaShift ($start - $end)';
  }

  factory MasterShiftOption.fromJson(Map<String, dynamic> json) {
    return MasterShiftOption(
      kodeShift: AppFormatters.parseString(json['kode_shift']),
      namaShift: AppFormatters.parseString(json['nama_shift'], 'Shift'),
      waktuMulai: AppFormatters.parseString(json['waktu_mulai']),
      waktuSelesai: AppFormatters.parseString(json['waktu_selesai']),
      defaultOpeningCash:
          AppFormatters.parseDouble(json['default_opening_cash']),
      isNightAudit: AppFormatters.parseBool(json['is_night_audit']),
    );
  }
}

class CashierShiftDetail {
  const CashierShiftDetail({
    required this.shift,
    required this.summary,
    required this.paymentSummary,
    required this.checkins,
    required this.checkouts,
    required this.facilities,
    required this.payments,
  });

  final CashierShift shift;
  final CashierShiftStats summary;
  final Map<String, double> paymentSummary;
  final List<Map<String, dynamic>> checkins;
  final List<Map<String, dynamic>> checkouts;
  final List<Map<String, dynamic>> facilities;
  final List<Map<String, dynamic>> payments;

  factory CashierShiftDetail.fromJson(Map<String, dynamic> json) {
    final shiftMap = json['shift'] is Map
        ? Map<String, dynamic>.from(json['shift'] as Map)
        : <String, dynamic>{};
    final summaryMap = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : <String, dynamic>{};
    final paySumRaw = json['payment_summary'] is Map
        ? Map<String, dynamic>.from(json['payment_summary'] as Map)
        : <String, dynamic>{};

    final paySum = <String, double>{};
    for (final entry in paySumRaw.entries) {
      paySum[entry.key] = AppFormatters.parseDouble(entry.value);
    }

    List<Map<String, dynamic>> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return CashierShiftDetail(
      shift: CashierShift.fromJson(shiftMap),
      summary: CashierShiftStats.fromJson(summaryMap),
      paymentSummary: paySum,
      checkins: parseList(json['checkins']),
      checkouts: parseList(json['checkouts']),
      facilities: parseList(json['facilities']),
      payments: parseList(json['payments']),
    );
  }
}

