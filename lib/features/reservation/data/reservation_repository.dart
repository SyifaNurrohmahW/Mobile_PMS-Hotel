import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/utils/formatters.dart';

final reservationRepositoryProvider = Provider<ReservationRepository>((ref) {
  return ReservationRepository(
    ApiClient(ref.watch(apiClientProvider)),
    const SecureStorageService(),
  );
});

class ExtraFacilityCatalogItem {
  const ExtraFacilityCatalogItem({
    required this.kodeFasilitas,
    required this.nama,
    required this.harga,
    required this.chargeType,
  });

  final String kodeFasilitas;
  final String nama;
  final double harga;
  final String chargeType; // 'restaurant' | 'laundry' | 'other'

  factory ExtraFacilityCatalogItem.fromJson(
    Map<String, dynamic> json, {
    bool isAmenity = false,
  }) {
    final code = AppFormatters.parseString(
      json['kode_fasilitas'] ?? json['kode_amenity'],
    );
    final name = AppFormatters.parseString(
      json['name'] ?? json['nama'],
      'Fasilitas',
    );
    final lowerName = name.toLowerCase();
    final chargeType = lowerName.contains('laundry')
        ? 'laundry'
        : (lowerName.contains('sarapan') ||
                lowerName.contains('breakfast') ||
                lowerName.contains('makan')
            ? 'restaurant'
            : 'other');

    return ExtraFacilityCatalogItem(
      kodeFasilitas: code.isNotEmpty ? code : (isAmenity ? 'AMN' : 'FAS'),
      nama: name,
      harga: AppFormatters.parseDouble(json['harga']),
      chargeType: chargeType,
    );
  }
}

class ReservationRepository {
  ReservationRepository(this._apiClient, [this._storage = const SecureStorageService()]);

  final ApiClient _apiClient;
  final SecureStorageService _storage;

  static const _guestProfileKey = 'customer_guest_profile_json';
  static const _bookingCodesKey = 'customer_booking_codes_json';

  // ===========================================================================
  // A. CUSTOMER SELF-SERVICE: CABANG HOTEL, PAJAK, PROFIL MASTER TAMU & BOOKING
  // ===========================================================================

  Future<List<Map<String, dynamic>>> fetchHotelBranches() async {
    try {
      final response = await _apiClient.post('/master/cabang/cabang-data', {});
      final list = _listData(response)
          .where((b) => AppFormatters.parseBool(b['is_active'], true))
          .toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}
    return [
      {
        'id': 1,
        'kode_cabang': 'CAB0001',
        'nama_hotel': 'Grand Marstech Hotel',
        'address': 'Jl. Utama Pusat Kota No. 1',
        'check_in_time': '14:00:00',
        'check_out_time': '12:00:00',
      },
    ];
  }

  Future<List<Map<String, dynamic>>> fetchActiveTaxes({
    required String branchCode,
  }) async {
    try {
      final response = await _apiClient.post('/master/pajak/pajak-data', {
        'kode_cabang': branchCode,
      });
      return _listData(response)
          .where((t) => AppFormatters.parseBool(t['is_active'], true))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>?> readSavedCustomerGuest() async {
    try {
      final raw = await _storage.read(_guestProfileKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<void> saveCustomerGuest(Map<String, dynamic> guest) async {
    await _storage.write(_guestProfileKey, jsonEncode(guest));
  }

  Future<void> clearSavedCustomerGuest() async {
    await _storage.write(_guestProfileKey, '');
  }

  Future<void> saveCustomServerUrl(String url) async {
    final trimmed = url.trim();
    await _storage.write('custom_api_base_url', trimmed);
  }

  Future<List<String>> readSavedBookingCodes() async {
    try {
      final raw = await _storage.read(_bookingCodesKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<void> addSavedBookingCode(String kodeReservasi) async {
    if (kodeReservasi.isEmpty) return;
    final current = (await readSavedBookingCodes()).toList();
    if (!current.contains(kodeReservasi)) {
      current.insert(0, kodeReservasi);
      await _storage.write(_bookingCodesKey, jsonEncode(current));
    }
  }

  /// Registrasi atau perbarui profil identitas pelanggan sesuai form Master Tamu di Website Admin
  Future<Map<String, dynamic>> registerOrUpdateMasterGuest({
    required String branchCode,
    String? existingKodeTamu,
    required String guestType, // 'individual' | 'group'
    required String title, // 'Mr' | 'Mrs' | 'Ms' | 'Dr'
    required String fullName,
    required String phone,
    String? email,
    required String idType, // 'ktp' | 'passport' | 'sim' | 'other'
    required String idNumber,
    String gender = 'L', // 'L' | 'P'
    String? birthDate, // YYYY-MM-DD
    String nationality = 'Indonesia',
    String? internalNotes,
  }) async {
    final payload = <String, dynamic>{
      'kode_cabang': branchCode,
      'guest_type': guestType,
      'title': title,
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'email': (email != null && email.trim().isNotEmpty) ? email.trim() : null,
      'id_type': idType,
      'id_number': idNumber.trim(),
      'gender': gender,
      'birth_date':
          (birthDate != null && birthDate.trim().isNotEmpty)
              ? birthDate.trim()
              : null,
      'nationality':
          nationality.trim().isNotEmpty ? nationality.trim() : 'Indonesia',
      'internal_notes':
          (internalNotes != null && internalNotes.trim().isNotEmpty)
              ? internalNotes.trim()
              : null,
      'source': 'mobile_customer_app',
    };

    // 1. Jika sudah ada kode_tamu sebelumnya, coba update terlebih dahulu
    if (existingKodeTamu != null && existingKodeTamu.trim().isNotEmpty) {
      try {
        final updateResp = await _apiClient.post('/master/guest/guest-update', {
          ...payload,
          'kode_tamu': existingKodeTamu.trim(),
        });
        if (updateResp['data'] is Map) {
          final updated = Map<String, dynamic>.from(updateResp['data'] as Map);
          await saveCustomerGuest(updated);
          return updated;
        }
      } catch (_) {}
    }

    // 2. Coba buat baru melalui endpoint Master Tamu (/master/guest/guest-create)
    try {
      final response = await _apiClient.post(
        '/master/guest/guest-create',
        payload,
      );
      if (response['data'] is Map) {
        final created = Map<String, dynamic>.from(response['data'] as Map);
        await saveCustomerGuest(created);
        return created;
      }
    } catch (_) {
      // Jika gagal karena Nomor Identitas atau No. HP sudah terdaftar, cari data tamu eksisting lalu update
      final existingList = await fetchGuestList(
        branchCode: branchCode,
        keyword: idNumber.trim(),
      );
      Map<String, dynamic>? matched = existingList.isNotEmpty
          ? existingList.first
          : null;

      if (matched == null) {
        final byPhone = await fetchGuestList(
          branchCode: branchCode,
          keyword: phone.trim(),
        );
        if (byPhone.isNotEmpty) {
          matched = byPhone.first;
        }
      }

      if (matched != null) {
        final matchedCode = AppFormatters.parseString(matched['kode_tamu']);
        if (matchedCode.isNotEmpty) {
          try {
            final updateResp = await _apiClient.post(
              '/master/guest/guest-update',
              {
                ...payload,
                'kode_tamu': matchedCode,
              },
            );
            if (updateResp['data'] is Map) {
              final updated =
                  Map<String, dynamic>.from(updateResp['data'] as Map);
              await saveCustomerGuest(updated);
              return updated;
            }
          } catch (_) {}
          final fallbackMerged = {...matched, ...payload, 'kode_tamu': matchedCode};
          await saveCustomerGuest(fallbackMerged);
          return fallbackMerged;
        }
      }

      // Fallback ke endpoint /reservasi/guest/guest-create
      final fallbackCreated = await createGuest(
        branchCode: branchCode,
        fullName: fullName.trim(),
        idType: idType,
        idNumber: idNumber.trim(),
        phone: phone.trim(),
        email: email,
        nationality: nationality,
      );
      await saveCustomerGuest(fallbackCreated);
      return fallbackCreated;
    }

    throw const ApiException(
      message: 'Gagal menyimpan registrasi identitas tamu.',
    );
  }

  /// Menyelesaikan 1 alur transaksi reservasi pelanggan ke database
  Future<Map<String, dynamic>> submitCustomerBooking({
    required String branchCode,
    required String kodeGuest,
    required String checkInDate,
    required String checkOutDate,
    required List<Map<String, dynamic>> rooms,
    required List<Map<String, dynamic>> extraFacilities,
    String? specialRequest,
    required String paymentMethod,
    required double depositAmount,
    String? bankName,
    String? referenceNo,
  }) async {
    String? openShiftCode;
    if (depositAmount > 0) {
      try {
        final shiftRes = await _apiClient.post(
          '/master/cashier-shift/dropdown',
          {'kode_cabang': branchCode},
        );
        final shiftList = _listData(shiftRes);
        if (shiftList.isNotEmpty) {
          openShiftCode = AppFormatters.parseString(
            shiftList.first['kode_cashier_shift'],
          );
        }
      } catch (_) {}

      if (openShiftCode == null || openShiftCode.isEmpty) {
        try {
          final curShift = await _apiClient.post('/kasir/shift-current', {
            'kode_cabang': branchCode,
          });
          if (curShift['data'] is Map) {
            openShiftCode = AppFormatters.parseString(
              (curShift['data'] as Map)['kode_cashier_shift'],
            );
          }
        } catch (_) {}
      }
    }

    final hasOpenShift = openShiftCode != null && openShiftCode.isNotEmpty;
    final effectiveDeposit = hasOpenShift ? depositAmount.round() : 0;

    String combinedSpecialRequest = (specialRequest ?? '').trim();
    if (depositAmount > 0 && !hasOpenShift) {
      final paymentNote =
          'Metode Pembayaran Pilihan Pelanggan: ${paymentMethod.toUpperCase()}${bankName != null && bankName.isNotEmpty ? " ($bankName)" : ""}${referenceNo != null && referenceNo.isNotEmpty ? " Ref: $referenceNo" : ""}';
      combinedSpecialRequest = combinedSpecialRequest.isEmpty
          ? paymentNote
          : '$combinedSpecialRequest | $paymentNote';
    }

    final payload = <String, dynamic>{
      'kode_cabang': branchCode,
      'kode_guest': kodeGuest,
      'check_in_date': checkInDate,
      'check_out_date': checkOutDate,
      'source_channel': 'mobile',
      'rooms': rooms,
      'extra_facilities': extraFacilities,
      'special_request': combinedSpecialRequest,
      'deposit_amount': effectiveDeposit,
      if (effectiveDeposit > 0) ...{
        'payment_method': paymentMethod,
        'kode_cashier_shift': openShiftCode,
        if (bankName != null && bankName.isNotEmpty) 'bank_name': bankName,
        if (referenceNo != null && referenceNo.isNotEmpty)
          'reference_no': referenceNo,
      },
    };

    try {
      final result = await createReservation(payload);
      final kodeRes = AppFormatters.parseString(result['kode_reservasi']);
      await addSavedBookingCode(kodeRes);
      return result;
    } on ApiException catch (e) {
      // Jika shift kasir di server baru saja ditutup, ulangi otomatis sebagai Pay at Hotel / Reserved
      if (e.message.toLowerCase().contains('shift kasir')) {
        final fallbackPayload = <String, dynamic>{
          'kode_cabang': branchCode,
          'kode_guest': kodeGuest,
          'check_in_date': checkInDate,
          'check_out_date': checkOutDate,
          'source_channel': 'mobile',
          'rooms': rooms,
          'extra_facilities': extraFacilities,
          'special_request': combinedSpecialRequest,
          'deposit_amount': 0,
        };
        final result = await createReservation(fallbackPayload);
        final kodeRes = AppFormatters.parseString(result['kode_reservasi']);
        await addSavedBookingCode(kodeRes);
        return result;
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchCustomerReservations({
    required String branchCode,
    String? searchKeyword,
  }) async {
    final response = await _apiClient.post(
      '/reservasi/booking/reservation-data',
      {
        'kode_cabang': branchCode,
        'status': const [
          'reserved',
          'confirmed',
          'booked',
          'assigned',
          'checked_in',
          'checked_out',
          'cancelled',
        ],
      },
    );
    final allRows = _listData(response);
    final savedGuest = await readSavedCustomerGuest();
    final savedCodes = await readSavedBookingCodes();

    final guestCode = AppFormatters.parseString(savedGuest?['kode_tamu']);
    final guestPhone = AppFormatters.parseString(savedGuest?['phone']);
    final guestIdNum = AppFormatters.parseString(savedGuest?['id_number']);

    final kw = (searchKeyword ?? '').trim().toLowerCase();

    return allRows.where((row) {
      final rowResCode = AppFormatters.parseString(row['kode_reservasi']);
      final rowGuestCode = AppFormatters.parseString(row['kode_tamu']);
      final rowPhone = AppFormatters.parseString(row['guest_phone']);
      final rowIdNum = AppFormatters.parseString(row['guest_id_number']);
      final rowGuestName = AppFormatters.parseString(row['guest_name']);

      if (kw.isNotEmpty) {
        return rowResCode.toLowerCase().contains(kw) ||
            rowGuestName.toLowerCase().contains(kw) ||
            rowPhone.toLowerCase().contains(kw) ||
            rowIdNum.toLowerCase().contains(kw);
      }

      if (savedCodes.isNotEmpty && savedCodes.contains(rowResCode)) {
        return true;
      }
      if (guestCode.isNotEmpty && rowGuestCode == guestCode) {
        return true;
      }
      if (guestPhone.isNotEmpty && rowPhone == guestPhone) {
        return true;
      }
      if (guestIdNum.isNotEmpty && rowIdNum == guestIdNum) {
        return true;
      }

      // Jika pelanggan belum punya profil lokal tersimpan, tampilkan reservasi terbaru
      if (savedGuest == null && savedCodes.isEmpty) {
        return true;
      }
      return false;
    }).toList();
  }

  // ===========================================================================
  // D. TAMU, KATALOG KAMAR, FASILITAS, WALK-IN & BOOKING
  // ===========================================================================

  Future<List<Map<String, dynamic>>> roomPackages({
    required String branchCode,
    required String checkInDate,
    required String checkOutDate,
  }) async {
    final response = await _apiClient.post('/reservasi/kamar/room-packages', {
      'kode_cabang': branchCode,
      'check_in_date': checkInDate,
      'check_out_date': checkOutDate,
    });
    return _listData(response);
  }

  Future<List<Map<String, dynamic>>> checkAvailablePhysicalRooms({
    required String branchCode,
    required String roomTypeCode,
    required String ratePlanCode,
    required String checkInDate,
    required String checkOutDate,
  }) async {
    final response = await _apiClient.post('/reservasi/kamar/availability', {
      'kode_cabang': branchCode,
      'kode_tipe_kamar': roomTypeCode,
      'kode_rate_plan': ratePlanCode,
      'check_in_date': checkInDate,
      'check_out_date': checkOutDate,
    });
    final data = response['data'];
    if (data is Map && data['available_rooms'] is List) {
      return (data['available_rooms'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Future<List<ExtraFacilityCatalogItem>> fetchExtraFacilitiesCatalog({
    required String branchCode,
  }) async {
    final results = await Future.wait([
      _apiClient
          .post('/master/fasilitas/fasilitas-data', {'kode_cabang': branchCode})
          .catchError((_) => <String, dynamic>{'data': const []}),
      _apiClient
          .post('/master/amenity/amenity-data', const {})
          .catchError((_) => <String, dynamic>{'data': const []}),
    ]);

    final items = <ExtraFacilityCatalogItem>[];
    final seenNames = <String>{};

    for (final row in _listData(results[0])) {
      final isActive = AppFormatters.parseBool(row['is_active'], true);
      if (!isActive) continue;
      final item = ExtraFacilityCatalogItem.fromJson(row);
      if (item.harga > 0 && seenNames.add(item.nama.toLowerCase())) {
        items.add(item);
      }
    }

    for (final row in _listData(results[1])) {
      final isActive = AppFormatters.parseBool(row['is_active'], true);
      if (!isActive) continue;
      final item = ExtraFacilityCatalogItem.fromJson(row, isAmenity: true);
      if (item.harga > 0 && seenNames.add(item.nama.toLowerCase())) {
        items.add(item);
      }
    }

    return items;
  }

  Future<List<Map<String, dynamic>>> fetchGuestList({
    required String branchCode,
    String? keyword,
  }) async {
    final kw = keyword?.trim() ?? '';
    final results = await Future.wait([
      _apiClient
          .post('/reservasi/guest/guest-list', {'kode_cabang': branchCode})
          .catchError((_) => <String, dynamic>{'data': const []}),
      _apiClient
          .post('/master/guest/guest-data', {
            if (kw.isNotEmpty) 'keyword': kw,
            'perPage': 100,
          })
          .catchError((_) => <String, dynamic>{'data': const []}),
    ]);

    final merged = <Map<String, dynamic>>[];
    final seenCodes = <String>{};

    for (final row in _listData(results[0])) {
      final code = AppFormatters.parseString(row['kode_tamu']);
      if (code.isNotEmpty && seenCodes.add(code)) {
        merged.add(row);
      }
    }

    for (final row in _listData(results[1])) {
      final rowBranch = AppFormatters.parseString(row['kode_cabang']);
      if (rowBranch.isNotEmpty &&
          branchCode.isNotEmpty &&
          rowBranch != branchCode) {
        continue;
      }
      final code = AppFormatters.parseString(row['kode_tamu']);
      if (code.isNotEmpty && seenCodes.add(code)) {
        merged.add(row);
      }
    }

    if (kw.isEmpty) return merged;

    final lowerKw = kw.toLowerCase();
    return merged.where((g) {
      final name = AppFormatters.parseString(g['full_name']).toLowerCase();
      final phone = AppFormatters.parseString(g['phone']).toLowerCase();
      final idNum = AppFormatters.parseString(
        g['id_number_raw'] ?? g['id_number'],
      ).toLowerCase();
      final code = AppFormatters.parseString(g['kode_tamu']).toLowerCase();
      final email = AppFormatters.parseString(g['email']).toLowerCase();
      return name.contains(lowerKw) ||
          phone.contains(lowerKw) ||
          idNum.contains(lowerKw) ||
          code.contains(lowerKw) ||
          email.contains(lowerKw);
    }).toList();
  }

  Future<Map<String, dynamic>> findGuest({
    required String keyword,
    required String branchCode,
  }) async {
    final matches = await fetchGuestList(
      branchCode: branchCode,
      keyword: keyword,
    );
    if (matches.isNotEmpty) {
      return matches.first;
    }
    final response = await _apiClient.post('/reservasi/guest/guest-search', {
      'keyword': keyword,
      'kode_cabang': branchCode,
    });
    final guest = response['data'];
    if (guest is! Map) {
      throw ApiException(
        message: response['message']?.toString() ?? 'Data tamu tidak ditemukan',
      );
    }
    return Map<String, dynamic>.from(guest);
  }

  Future<Map<String, dynamic>> createGuest({
    required String branchCode,
    required String fullName,
    required String idType,
    required String idNumber,
    required String phone,
    String? email,
    String? nationality,
  }) async {
    final response = await _apiClient.post('/reservasi/guest/guest-create', {
      'kode_cabang': branchCode,
      'full_name': fullName,
      'id_type': idType,
      'id_number': idNumber,
      'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      if (nationality != null && nationality.isNotEmpty)
        'nationality': nationality,
    });
    final data = response['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const ApiException(message: 'Gagal membuat data tamu baru.');
  }

  Future<Map<String, dynamic>> submitWalkIn(
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post(
      '/reservasi/walk-in/walk-in-submit',
      payload,
    );
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : response;
  }

  Future<Map<String, dynamic>> createReservation(
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post(
      '/reservasi/booking/reservation-create',
      payload,
    );
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : response;
  }

  // ===========================================================================
  // E. KEDATANGAN (ARRIVALS), CHECK-IN, RESCHEDULE & PEMBATALAN
  // ===========================================================================

  Future<List<Map<String, dynamic>>> arrivals({
    required String branchCode,
    String? checkInDate,
  }) async {
    final response = await _apiClient.post(
      '/reservasi/booking/reservation-data',
      {
        'kode_cabang': branchCode,
        'status': const ['reserved', 'confirmed', 'booked'],
        if (checkInDate != null && checkInDate.isNotEmpty)
          'check_in_date': checkInDate,
      },
    );
    return _listData(response);
  }

  Future<Map<String, dynamic>> checkIn(String reservationRoomCode) async {
    return submitCheckIn({'kode_reservasi_room': reservationRoomCode});
  }

  Future<Map<String, dynamic>> submitCheckIn(
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post(
      '/reservasi/checkin/checkin-submit',
      payload,
    );
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : response;
  }

  Future<Map<String, dynamic>> checkReschedule({
    required String kodeReservasi,
    required String newCheckInDate,
    required String newCheckOutDate,
  }) async {
    final response = await _apiClient.post(
      '/reservasi/reschedule/reschedule-check',
      {
        'kode_reservasi': kodeReservasi,
        'new_check_in_date': newCheckInDate,
        'new_check_out_date': newCheckOutDate,
      },
    );
    final data = response['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException(message: 'Gagal memuat simulasi reschedule.');
  }

  Future<Map<String, dynamic>> submitReschedule({
    required String kodeReservasi,
    required String newCheckInDate,
    required String newCheckOutDate,
    String? notes,
    List<Map<String, dynamic>>? roomAssignments,
  }) async {
    final response = await _apiClient.post(
      '/reservasi/reschedule/reschedule-submit',
      {
        'kode_reservasi': kodeReservasi,
        'new_check_in_date': newCheckInDate,
        'new_check_out_date': newCheckOutDate,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'room_assignments': ?roomAssignments,
      },
    );
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : response;
  }

  Future<Map<String, dynamic>> submitCancelReservation(
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post(
      '/reservasi/batal/cancel-submit',
      payload,
    );
    return response;
  }

  // ===========================================================================
  // F. TAMU MENGINAP (IN-HOUSE OPERATIONS)
  // ===========================================================================

  Future<List<Map<String, dynamic>>> inHouse({
    required String branchCode,
    String? keyword,
  }) async {
    final response = await _apiClient.post('/reservasi/inhouse/inhouse-list', {
      'kode_cabang': branchCode,
      if (keyword != null && keyword.trim().isNotEmpty)
        'keyword': keyword.trim(),
    });
    return _listData(response);
  }

  Future<Map<String, dynamic>> fetchFolioDetail({
    String? kodeFolio,
    String? kodeReservation,
    String? kodeReservasiRoom,
  }) async {
    final response = await _apiClient.post('/reservasi/inhouse/folio-detail', {
      if (kodeFolio != null && kodeFolio.isNotEmpty) 'kode_folio': kodeFolio,
      if (kodeReservation != null && kodeReservation.isNotEmpty)
        'kode_reservation': kodeReservation,
      if (kodeReservasiRoom != null && kodeReservasiRoom.isNotEmpty)
        'kode_reservasi_room': kodeReservasiRoom,
    });
    final data = response['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException(message: 'Rincian folio tidak ditemukan.');
  }

  Future<Map<String, dynamic>> addInHouseFacility(
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post(
      '/reservasi/inhouse/fasilitas-add',
      payload,
    );
    return response;
  }

  Future<Map<String, dynamic>> checkExtendStay({
    required String kodeReservasiRoom,
    required String newCheckOutDate,
  }) async {
    final response = await _apiClient.post('/reservasi/inhouse/extend-check', {
      'kode_reservasi_room': kodeReservasiRoom,
      'new_check_out_date': newCheckOutDate,
    });
    final data = response['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException(message: 'Gagal mengecek perpanjangan menginap.');
  }

  Future<Map<String, dynamic>> submitExtendStay(
    Map<String, dynamic> payload,
  ) async {
    final response = await _apiClient.post(
      '/reservasi/inhouse/extend-submit',
      payload,
    );
    return response;
  }

  Future<Map<String, dynamic>> requestHousekeepingTask({
    required String kodeKamar,
    required String branchCode,
    String? kodeReservasiRoom,
    String taskType = 'cleaning',
    String priority = 'normal',
    String? notes,
  }) async {
    final response = await _apiClient.post(
      '/reservasi/inhouse/housekeeping-request',
      {
        'kode_kamar': kodeKamar,
        'kode_cabang': branchCode,
        if (kodeReservasiRoom != null && kodeReservasiRoom.isNotEmpty)
          'kode_reservasi_room': kodeReservasiRoom,
        'task_type': taskType,
        'priority': priority,
        'auto_assign': true,
        'request_source': 'front_office',
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return response;
  }

  // ===========================================================================
  // G. CHECKOUT, INSPEKSI KAMAR & INVOICE
  // ===========================================================================

  Future<List<Map<String, dynamic>>> checkoutSearch({
    required String branchCode,
    String? keyword,
  }) async {
    final response = await _apiClient.post(
      '/reservasi/checkout/checkout-search',
      {
        'kode_cabang': branchCode,
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
      },
    );
    return _listData(response);
  }

  Future<Map<String, dynamic>> requestCheckoutInspection({
    required String kodeKamar,
    String? kodeReservasiRoom,
    required String branchCode,
    String priority = 'urgent',
    String? notes,
  }) async {
    final response = await _apiClient.post(
      '/reservasi/checkout/request-inspection',
      {
        'kode_kamar': kodeKamar,
        if (kodeReservasiRoom != null && kodeReservasiRoom.isNotEmpty)
          'kode_reservasi_room': kodeReservasiRoom,
        'kode_cabang': branchCode,
        'priority': priority,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return response;
  }

  Future<Map<String, dynamic>> cancelCheckoutInspection({
    String? kodeHousekeepingTask,
    String? kodeKamar,
    String? cancelReason,
  }) async {
    final response = await _apiClient.post(
      '/reservasi/checkout/cancel-inspection',
      {
        if (kodeHousekeepingTask != null && kodeHousekeepingTask.isNotEmpty)
          'kode_housekeeping_task': kodeHousekeepingTask,
        if (kodeKamar != null && kodeKamar.isNotEmpty) 'kode_kamar': kodeKamar,
        'cancel_reason': cancelReason ??
            'Dibatalkan oleh Front Office (Express Checkout Override)',
      },
    );
    return response;
  }

  Future<Map<String, dynamic>> checkout(Map<String, dynamic> payload) async {
    final response = await _apiClient.post(
      '/reservasi/checkout/checkout-submit',
      payload,
    );
    final data = response['data'];
    return data is Map ? Map<String, dynamic>.from(data) : response;
  }

  List<Map<String, dynamic>> _listData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
