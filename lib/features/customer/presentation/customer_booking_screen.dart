import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/session_notifier.dart';
import '../../reservation/data/reservation_repository.dart';

class CustomerSelectedRoomItem {
  CustomerSelectedRoomItem({
    required this.kodeTipeKamar,
    required this.namaTipe,
    required this.kodeRatePlan,
    required this.namaRatePlan,
    required this.pricePerNight,
    this.fotoUrl,
    this.kapasitas = 2,
    this.luasM2 = 0,
  });

  final String kodeTipeKamar;
  final String namaTipe;
  final String kodeRatePlan;
  final String namaRatePlan;
  final double pricePerNight;
  final String? fotoUrl;
  final int kapasitas;
  final double luasM2;
}

class CustomerBookingScreen extends ConsumerStatefulWidget {
  const CustomerBookingScreen({super.key});

  @override
  ConsumerState<CustomerBookingScreen> createState() =>
      _CustomerBookingScreenState();
}

class _CustomerBookingScreenState extends ConsumerState<CustomerBookingScreen> {
  // Step 0: Pilih Tanggal & Katalog Kamar
  // Step 1: Registrasi Identitas Tamu (Sesuai Master Tamu Web Admin)
  // Step 2: Pembayaran & Konfirmasi
  // Step 3: E-Voucher Reservasi Selesai
  int _currentStep = 0;

  List<Map<String, dynamic>> _branches = [];
  Map<String, dynamic>? _activeBranch;

  DateTime _checkIn = DateTime.now();
  DateTime _checkOut = DateTime.now().add(const Duration(days: 1));

  bool _isLoadingCatalog = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _roomTypes = [];
  final List<CustomerSelectedRoomItem> _selectedRooms = [];

  List<ExtraFacilityCatalogItem> _facilityCatalog = [];
  final Map<String, int> _facilityQuantities = {};
  List<Map<String, dynamic>> _activeTaxes = [];

  final _specialRequestController = TextEditingController();

  // Step 1: Form Identitas Master Tamu (Sesuai Website Admin master_tamu/form.tsx)
  final _guestFormKey = GlobalKey<FormState>();
  String _guestType = 'individual'; // 'individual' | 'group'
  String _title = 'Mr'; // 'Mr' | 'Mrs' | 'Ms' | 'Dr'
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String _idType = 'ktp'; // 'ktp' | 'passport' | 'sim' | 'other'
  final _idNumberController = TextEditingController();
  String _gender = 'L'; // 'L' | 'P'
  DateTime? _birthDate;
  final _nationalityController = TextEditingController(text: 'Indonesia');
  final _internalNotesController = TextEditingController();

  Map<String, dynamic>? _registeredGuest;
  bool _isSavingGuest = false;

  // Step 2: Payment & Completion
  String _selectedPaymentMethod = 'qris'; // 'qris' | 'transfer' | 'card' | 'pay_at_hotel'
  String _selectedBank = 'BCA Virtual Account';
  bool _isSubmittingBooking = false;
  Map<String, dynamic>? _completedReservationResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  void dispose() {
    _specialRequestController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idNumberController.dispose();
    _nationalityController.dispose();
    _internalNotesController.dispose();
    super.dispose();
  }

  int get _nights {
    final cin = DateTime(_checkIn.year, _checkIn.month, _checkIn.day);
    final cout = DateTime(_checkOut.year, _checkOut.month, _checkOut.day);
    final diff = cout.difference(cin).inDays;
    return diff < 1 ? 1 : diff;
  }

  double get _roomsSubtotal {
    return _selectedRooms.fold<double>(
      0,
      (sum, r) => sum + (r.pricePerNight * _nights),
    );
  }

  double get _facilitiesSubtotal {
    double total = 0;
    for (final item in _facilityCatalog) {
      final qty = _facilityQuantities[item.kodeFasilitas] ?? 0;
      if (qty > 0) {
        total += item.harga * qty;
      }
    }
    return total;
  }

  double get _subtotal => _roomsSubtotal + _facilitiesSubtotal;

  double get _taxAndServiceTotal {
    if (_activeTaxes.isEmpty) {
      return (_subtotal * 0.11).roundToDouble();
    }
    double total = 0;
    for (final t in _activeTaxes) {
      final pct = AppFormatters.parseDouble(t['percentage']);
      total += (_subtotal * (pct / 100)).roundToDouble();
    }
    return total;
  }

  double get _grandTotal => _subtotal + _taxAndServiceTotal;

  String get _activeBranchCode {
    return AppFormatters.parseString(
      _activeBranch?['kode_cabang'] ??
          ref.read(sessionProvider)?.activeKodeCabang,
      'CAB0001',
    );
  }

  String get _activeBranchName {
    return AppFormatters.parseString(
      _activeBranch?['nama_hotel'] ??
          _activeBranch?['name'] ??
          ref.read(sessionProvider)?.activeBranchName,
      'Grand Marstech Hotel',
    );
  }

  Future<void> _initializeData() async {
    final repo = ref.read(reservationRepositoryProvider);
    final branches = await repo.fetchHotelBranches();
    final savedGuest = await repo.readSavedCustomerGuest();

    if (!mounted) return;
    setState(() {
      _branches = branches;
      if (branches.isNotEmpty) {
        final currentCode = ref.read(sessionProvider)?.activeKodeCabang;
        _activeBranch = branches.firstWhere(
          (b) => b['kode_cabang']?.toString() == currentCode,
          orElse: () => branches.first,
        );
        ref.read(sessionProvider.notifier).setCustomerActiveBranch(
              kodeCabang: AppFormatters.parseString(
                _activeBranch!['kode_cabang'],
                'CAB0001',
              ),
              namaHotel: AppFormatters.parseString(
                _activeBranch!['nama_hotel'] ?? _activeBranch!['name'],
                'Grand Marstech Hotel',
              ),
              branchId: AppFormatters.parseInt(_activeBranch!['id'], 1),
            );
      }
      if (savedGuest != null) {
        _applyGuestToForm(savedGuest);
      }
    });

    await _loadCatalog();
  }

  void _applyGuestToForm(Map<String, dynamic> guest) {
    _registeredGuest = guest;
    final gType = AppFormatters.parseString(guest['guest_type'], 'individual');
    _guestType = (gType == 'group') ? 'group' : 'individual';

    final gTitle = AppFormatters.parseString(guest['title'], 'Mr');
    _title = const ['Mr', 'Mrs', 'Ms', 'Dr'].contains(gTitle) ? gTitle : 'Mr';

    _fullNameController.text = AppFormatters.parseString(guest['full_name']);
    _phoneController.text = AppFormatters.parseString(guest['phone']);
    _emailController.text = AppFormatters.parseString(guest['email']);

    final rawIdType =
        AppFormatters.parseString(guest['id_type'], 'ktp').toLowerCase();
    _idType = const ['ktp', 'passport', 'sim', 'other'].contains(rawIdType)
        ? rawIdType
        : 'ktp';

    _idNumberController.text = AppFormatters.parseString(
      guest['id_number_raw'] ?? guest['id_number'],
    );

    final rawGender = AppFormatters.parseString(guest['gender'], 'L');
    _gender = (rawGender == 'P') ? 'P' : 'L';

    final rawBirth = AppFormatters.parseString(guest['birth_date']);
    if (rawBirth.isNotEmpty) {
      _birthDate = DateTime.tryParse(rawBirth);
    }

    final nat = AppFormatters.parseString(guest['nationality'], 'Indonesia');
    _nationalityController.text = nat.isNotEmpty ? nat : 'Indonesia';
    _internalNotesController.text =
        AppFormatters.parseString(guest['internal_notes']);
  }

  Future<void> _loadCatalog() async {
    final branchCode = _activeBranchCode;
    if (branchCode.isEmpty) return;

    setState(() {
      _isLoadingCatalog = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(reservationRepositoryProvider);
      final results = await Future.wait([
        repo.roomPackages(
          branchCode: branchCode,
          checkInDate: AppFormatters.formatDateYmd(_checkIn),
          checkOutDate: AppFormatters.formatDateYmd(_checkOut),
        ),
        repo.fetchExtraFacilitiesCatalog(branchCode: branchCode),
        repo.fetchActiveTaxes(branchCode: branchCode),
      ]);

      if (!mounted) return;
      setState(() {
        _roomTypes = results[0] as List<Map<String, dynamic>>;
        _facilityCatalog = results[1] as List<ExtraFacilityCatalogItem>;
        _activeTaxes = results[2] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingCatalog = false);
      }
    }
  }

  Future<void> _pickStayDate({required bool isCheckIn}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = isCheckIn ? _checkIn : _checkOut;
    final first = isCheckIn ? today : _checkIn.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isCheckIn) {
        _checkIn = picked;
        if (!_checkOut.isAfter(_checkIn)) {
          _checkOut = _checkIn.add(const Duration(days: 1));
        }
      } else {
        _checkOut = picked;
      }
      _selectedRooms.clear();
    });
    await _loadCatalog();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1930, 1, 1),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
    }
  }

  void _showBranchPickerSheet() {
    if (_branches.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pilih Properti / Cabang Hotel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Data properti hotel diambil langsung dari pengaturan Superadmin.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _branches.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final branch = _branches[idx];
                      final code =
                          AppFormatters.parseString(branch['kode_cabang']);
                      final name = AppFormatters.parseString(
                        branch['nama_hotel'] ?? branch['name'],
                        code,
                      );
                      final addr = AppFormatters.parseString(
                        branch['address'] ?? branch['alamat'],
                        'Lokasi strategis pusat kota',
                      );
                      final isSelected = code == _activeBranchCode;

                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (!isSelected) {
                            setState(() {
                              _activeBranch = branch;
                              _selectedRooms.clear();
                            });
                            ref
                                .read(sessionProvider.notifier)
                                .setCustomerActiveBranch(
                                  kodeCabang: code,
                                  namaHotel: name,
                                  branchId: AppFormatters.parseInt(
                                    branch['id'],
                                    1,
                                  ),
                                );
                            _loadCatalog();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryLight
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.apartment_rounded,
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '$code · $addr',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.primary,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openExistingGuestLookupSheet() async {
    final branchCode = _activeBranchCode;
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExistingGuestLookupSheet(branchCode: branchCode),
    );
    if (selected != null && mounted) {
      setState(() {
        _applyGuestToForm(selected);
        _errorMessage = null;
      });
      await ref
          .read(reservationRepositoryProvider)
          .saveCustomerGuest(selected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profil identitas "${selected['full_name']}" berhasil dimuat.',
            ),
            backgroundColor: AppTheme.walkInGreen,
          ),
        );
      }
    }
  }

  Future<void> _saveGuestIdentityAndProceed() async {
    if (_isSavingGuest) return;
    if (!_guestFormKey.currentState!.validate()) {
      setState(() {
        _errorMessage =
            'Mohon lengkapi kolom wajib (*) pada formulir identitas tamu.';
      });
      return;
    }

    setState(() {
      _isSavingGuest = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(reservationRepositoryProvider);
      final saved = await repo.registerOrUpdateMasterGuest(
        branchCode: _activeBranchCode,
        existingKodeTamu:
            AppFormatters.parseString(_registeredGuest?['kode_tamu']),
        guestType: _guestType,
        title: _title,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        idType: _idType,
        idNumber: _idNumberController.text.trim(),
        gender: _gender,
        birthDate: _birthDate != null
            ? AppFormatters.formatDateYmd(_birthDate!)
            : null,
        nationality: _nationalityController.text.trim(),
        internalNotes: _internalNotesController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _applyGuestToForm(saved);
        _currentStep = 2; // Lanjut ke langkah Pembayaran & Konfirmasi
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingGuest = false);
      }
    }
  }

  Future<void> _completeBookingTransaction() async {
    if (_isSubmittingBooking) return;
    final kodeGuest = AppFormatters.parseString(_registeredGuest?['kode_tamu']);
    if (kodeGuest.isEmpty) {
      setState(() {
        _errorMessage = 'Silakan lengkapi registrasi identitas tamu terlebih dahulu.';
        _currentStep = 1;
      });
      return;
    }

    setState(() {
      _isSubmittingBooking = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(reservationRepositoryProvider);

      final roomsPayload = _selectedRooms
          .map(
            (r) => <String, dynamic>{
              'kode_tipe_kamar': r.kodeTipeKamar,
              'kode_rate_plan': r.kodeRatePlan,
            },
          )
          .toList();

      final extraFacilitiesPayload = <Map<String, dynamic>>[];
      for (final item in _facilityCatalog) {
        final qty = _facilityQuantities[item.kodeFasilitas] ?? 0;
        if (qty > 0) {
          extraFacilitiesPayload.add({
            'kode_fasilitas': item.kodeFasilitas,
            'id': item.chargeType,
            'nama': item.nama,
            'qty': qty,
            'harga': item.harga.round(),
            'subtotal': (item.harga * qty).round(),
          });
        }
      }

      final isPayAtHotel = _selectedPaymentMethod == 'pay_at_hotel';
      final depositAmount = isPayAtHotel ? 0.0 : _grandTotal;
      final refNo = AppFormatters.generatePaymentRefNo(_selectedPaymentMethod);

      final notesParts = <String>[];
      if (_specialRequestController.text.trim().isNotEmpty) {
        notesParts.add(_specialRequestController.text.trim());
      }
      if (_internalNotesController.text.trim().isNotEmpty) {
        notesParts.add('Preferensi Tamu: ${_internalNotesController.text.trim()}');
      }

      final result = await repo.submitCustomerBooking(
        branchCode: _activeBranchCode,
        kodeGuest: kodeGuest,
        checkInDate: AppFormatters.formatDateYmd(_checkIn),
        checkOutDate: AppFormatters.formatDateYmd(_checkOut),
        rooms: roomsPayload,
        extraFacilities: extraFacilitiesPayload,
        specialRequest: notesParts.join(' | '),
        paymentMethod: isPayAtHotel ? 'cash' : _selectedPaymentMethod,
        depositAmount: depositAmount,
        bankName: _selectedPaymentMethod == 'transfer' ? _selectedBank : null,
        referenceNo: refNo,
      );

      if (!mounted) return;
      setState(() {
        _completedReservationResult = result;
        _currentStep = 3; // E-Voucher Selesai
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingBooking = false);
      }
    }
  }

  void _resetForNewBooking() {
    setState(() {
      _selectedRooms.clear();
      _facilityQuantities.clear();
      _specialRequestController.clear();
      _completedReservationResult = null;
      _errorMessage = null;
      _currentStep = 0;
    });
    _loadCatalog();
  }

  Future<void> _showServerConfigDialog() async {
    final controller = TextEditingController(
      text: AppConfig.effectiveApiBaseUrl,
    );
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Pengaturan Alamat Server API',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan IP Wi-Fi laptop tempat backend express_pms_be berjalan (port 8000):',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'URL API Server',
                hintText: 'http://192.168.1.18:8000/api/v1',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, 'http://192.168.1.18:8000/api/v1'),
            child: const Text('Reset Default'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Simpan & Muat Ulang'),
          ),
        ],
      ),
    );

    if (saved != null && saved.isNotEmpty && mounted) {
      String normalized = saved;
      if (!normalized.startsWith('http://') &&
          !normalized.startsWith('https://')) {
        normalized = 'http://$normalized';
      }
      if (!normalized.endsWith('/api/v1')) {
        normalized =
            normalized.replaceAll(RegExp(r'/+$'), '') +
            (normalized.contains(':8000') ? '/api/v1' : ':8000/api/v1');
      }
      AppConfig.runtimeApiBaseUrl = normalized;
      await ref
          .read(reservationRepositoryProvider)
          .saveCustomServerUrl(normalized);
      await _initializeData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTravelokaTopHeader(),
            if (_currentStep < 3) _buildStepProgressHeader(),
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRedBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.dangerRed,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppTheme.dangerRed,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _showServerConfigDialog,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text(
                        'Atur IP',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _errorMessage = null),
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadCatalog,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_currentStep == 0) _buildStep0DateAndCatalog(),
                    if (_currentStep == 1) _buildStep1GuestIdentityForm(),
                    if (_currentStep == 2) _buildStep2PaymentAndReview(),
                    if (_currentStep == 3) _buildStep3SuccessVoucher(),
                  ],
                ),
              ),
            ),
            if (_currentStep < 3) _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelokaTopHeader() {
    final checkInTime = AppFormatters.parseString(
      _activeBranch?['check_in_time'],
      '14:00',
    ).split(':').take(2).join(':');
    final checkOutTime = AppFormatters.parseString(
      _activeBranch?['check_out_time'],
      '12:00',
    ).split(':').take(2).join(':');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F4C81), Color(0xFF1E6BB8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.luggage_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reservasi Hotel Online',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Check-In $checkInTime · Check-Out $checkOutTime',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _showBranchPickerSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          _activeBranchName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _showServerConfigDialog,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.settings_ethernet_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepProgressHeader() {
    final steps = [
      (0, '1. Pilih Kamar', Icons.bed_rounded),
      (1, '2. Identitas Tamu', Icons.badge_outlined),
      (2, '3. Pembayaran', Icons.receipt_long_rounded),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: steps.map((step) {
          final idx = step.$1;
          final label = step.$2;
          final isCurrent = _currentStep == idx;
          final isDone = _currentStep > idx;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (idx < _currentStep) {
                    setState(() => _currentStep = idx);
                  } else if (idx == 1 && _selectedRooms.isNotEmpty) {
                    setState(() => _currentStep = 1);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppTheme.bookingBlueBg
                        : (isDone
                            ? AppTheme.walkInGreenBg
                            : AppTheme.background),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCurrent
                          ? AppTheme.bookingBlue
                          : (isDone ? AppTheme.walkInGreen : AppTheme.border),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDone ? Icons.check_circle_rounded : step.$3,
                        size: 14,
                        color: isCurrent
                            ? AppTheme.bookingBlue
                            : (isDone
                                ? AppTheme.walkInGreen
                                : AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isCurrent || isDone
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isCurrent
                                ? AppTheme.bookingBlue
                                : (isDone
                                    ? AppTheme.walkInGreen
                                    : AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ===========================================================================
  // STEP 0: PILIH TANGGAL MULAI & AKHIR MENGINAP + KATALOG KAMAR
  // ===========================================================================
  Widget _buildStep0DateAndCatalog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Date Box ala Traveloka
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: AppTheme.bookingBlue,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Tanggal Menginap Anda',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    StatusBadge(
                      label: '$_nights Malam',
                      variant: StatusBadgeVariant.occupiedBlue,
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateSelectTile(
                        title: 'Mulai Menginap (Check-In)',
                        dateText: AppFormatters.formatDateShortId(_checkIn),
                        icon: Icons.login_rounded,
                        onTap: () => _pickStayDate(isCheckIn: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateSelectTile(
                        title: 'Akhir Menginap (Check-Out)',
                        dateText: AppFormatters.formatDateShortId(_checkOut),
                        icon: Icons.logout_rounded,
                        onTap: () => _pickStayDate(isCheckIn: false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Selected Rooms Summary Banner
        if (_selectedRooms.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: AppTheme.bookingBlueBg.withValues(alpha: 0.65),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppTheme.bookingBlue),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kamar Dipilih (${_selectedRooms.length} Kamar)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.bookingBlue,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _selectedRooms.clear()),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text(
                          'Reset Pilihan',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selectedRooms.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return InputChip(
                        backgroundColor: Colors.white,
                        label: Text(
                          '${item.namaTipe} (${item.namaRatePlan}) · ${AppFormatters.formatRupiah(item.pricePerNight)}/mlm',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onDeleted: () {
                          setState(() => _selectedRooms.removeAt(idx));
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Pilih Katalog Kamar Tersedia',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Text(
              '${_roomTypes.length} Tipe Kamar',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Semua foto, fasilitas kamar, dan tarif paket diambil langsung dari database hotel.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 10),

        if (_isLoadingCatalog)
          const Padding(
            padding: EdgeInsets.all(36),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_roomTypes.isEmpty)
          AppEmptyState(
            icon: Icons.bed_outlined,
            title: 'Katalog Kamar Belum Tersedia',
            subtitle:
                'Tidak ada tipe kamar aktif untuk tanggal ini di cabang $_activeBranchName.',
            actionLabel: 'Muat Ulang Katalog',
            onAction: _loadCatalog,
          )
        else
          ..._roomTypes.map((roomType) {
            final kodeTipe =
                AppFormatters.parseString(roomType['kode_tipe_kamar']);
            final selectedCountForType = _selectedRooms
                .where((r) => r.kodeTipeKamar == kodeTipe)
                .length;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _CustomerRoomCatalogCard(
                roomType: roomType,
                nights: _nights,
                selectedCount: selectedCountForType,
                onSelectPackage: (pkg) {
                  final availableCount =
                      AppFormatters.parseInt(roomType['available_count']);
                  if (selectedCountForType >= availableCount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Jumlah kamar tipe ${roomType['nama_tipe']} yang dipilih sudah mencapai batas ketersediaan ($availableCount kamar).',
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _selectedRooms.add(
                      CustomerSelectedRoomItem(
                        kodeTipeKamar: kodeTipe,
                        namaTipe: AppFormatters.parseString(
                          roomType['nama_tipe'],
                          'Kamar Hotel',
                        ),
                        kodeRatePlan: AppFormatters.parseString(
                          pkg['kode_rate_plan'],
                        ),
                        namaRatePlan: AppFormatters.parseString(
                          pkg['nama_rate_plan'],
                          'Standard Rate',
                        ),
                        pricePerNight: AppFormatters.parseDouble(
                          pkg['price_per_night'],
                        ),
                        fotoUrl:
                            AppFormatters.parseString(roomType['foto_cover_url']),
                        kapasitas: AppFormatters.parseInt(
                          roomType['kapasitas_maksimal'] ??
                              roomType['kapasitas_dasar'],
                          2,
                        ),
                        luasM2: AppFormatters.parseDouble(roomType['luas_m2']),
                      ),
                    );
                    _errorMessage = null;
                  });
                },
                onRemoveOne: selectedCountForType > 0
                    ? () {
                        final idx = _selectedRooms.lastIndexWhere(
                          (r) => r.kodeTipeKamar == kodeTipe,
                        );
                        if (idx >= 0) {
                          setState(() => _selectedRooms.removeAt(idx));
                        }
                      }
                    : null,
              ),
            );
          }),

        // Optional Extra Facilities (Add-Ons)
        if (_facilityCatalog.isNotEmpty) ...[
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.room_service_outlined,
                        size: 18,
                        color: AppTheme.bookingBlue,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Layanan & Fasilitas Tambahan (Opsional)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._facilityCatalog.map((item) {
                    final qty = _facilityQuantities[item.kodeFasilitas] ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.nama,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  AppFormatters.formatRupiah(item.harga),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.outlined(
                            onPressed: qty <= 0
                                ? null
                                : () {
                                    setState(() {
                                      _facilityQuantities[item.kodeFasilitas] =
                                          qty - 1;
                                    });
                                  },
                            icon: const Icon(Icons.remove, size: 15),
                            visualDensity: VisualDensity.compact,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '$qty',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: () {
                              setState(() {
                                _facilityQuantities[item.kodeFasilitas] =
                                    qty + 1;
                              });
                            },
                            icon: const Icon(Icons.add, size: 15),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Permintaan Khusus Menginap (Opsional)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _specialRequestController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText:
                        'Contoh: Kamar bebas asap rokok (Non-Smoking), lantai atas, bantal tambahan...',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // STEP 1: REGISTRASI IDENTITAS TAMU (SESUAI MASTER TAMU WEBSITE ADMIN)
  // ===========================================================================
  Widget _buildStep1GuestIdentityForm() {
    return Form(
      key: _guestFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: AppTheme.bookingBlueBg.withValues(alpha: 0.55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppTheme.bookingBlue),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    color: AppTheme.bookingBlue,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sudah Pernah Menginap Sebelumnya?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Text(
                          'Muat cepat identitas Anda menggunakan Nama, No. HP, atau KTP.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: _openExistingGuestLookupSheet,
                    icon: const Icon(Icons.person_search_rounded, size: 16),
                    label: const Text(
                      'Cari Data',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registrasi Identitas Tamu Pemesan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Lengkapi formulir profil tamu sesuai kartu identitas resmi',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 22),

                  // 1. Tipe Tamu
                  const Text(
                    'Tipe Tamu *',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'individual',
                        label: Text(
                          'Individual (Perorangan)',
                          style: TextStyle(fontSize: 12),
                        ),
                        icon: Icon(Icons.person_outline, size: 16),
                      ),
                      ButtonSegment<String>(
                        value: 'group',
                        label: Text(
                          'Group (Rombongan)',
                          style: TextStyle(fontSize: 12),
                        ),
                        icon: Icon(Icons.groups_outlined, size: 16),
                      ),
                    ],
                    selected: {_guestType},
                    onSelectionChanged: (val) {
                      if (val.isNotEmpty) {
                        setState(() => _guestType = val.first);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // 2. Cabang Hotel (Read-Only Sesuai Cabang Aktif)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cabang Hotel',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Text(
                        'Sesuai Cabang Aktif',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.apartment_rounded,
                          size: 18,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _activeBranchName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: _activeBranchCode,
                          variant: StatusBadgeVariant.occupiedBlue,
                          small: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3 & 4. Gelar & Nama Lengkap
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('title_$_title'),
                          initialValue: _title,
                          decoration: const InputDecoration(
                            labelText: 'Gelar',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Mr', child: Text('Mr')),
                            DropdownMenuItem(value: 'Mrs', child: Text('Mrs')),
                            DropdownMenuItem(value: 'Ms', child: Text('Ms')),
                            DropdownMenuItem(value: 'Dr', child: Text('Dr')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _title = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _fullNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nama Lengkap *',
                            hintText: 'Sesuai kartu identitas',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Nama lengkap wajib diisi'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 5. Telp / WhatsApp
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telp / WhatsApp *',
                      hintText: 'Contoh: 081234567890',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nomor telepon / WhatsApp wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // 6. Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'tamu@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 7 & 8. Tipe Identitas & Nomor Identitas
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 122,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('id_type_$_idType'),
                          initialValue: _idType,
                          decoration: const InputDecoration(
                            labelText: 'Tipe ID *',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'ktp', child: Text('KTP')),
                            DropdownMenuItem(
                              value: 'passport',
                              child: Text('Paspor'),
                            ),
                            DropdownMenuItem(value: 'sim', child: Text('SIM')),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Lainnya'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _idType = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _idNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Nomor Identitas *',
                            hintText: 'Nomor KTP / Paspor / SIM',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Nomor identitas wajib diisi'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 9 & 10. Jenis Kelamin & Tanggal Lahir
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('gender_$_gender'),
                          initialValue: _gender,
                          decoration: const InputDecoration(
                            labelText: 'Jenis Kelamin',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'L',
                              child: Text('Laki-laki'),
                            ),
                            DropdownMenuItem(
                              value: 'P',
                              child: Text('Perempuan'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _gender = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _pickBirthDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Tanggal Lahir',
                              suffixIcon: Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                              ),
                            ),
                            child: Text(
                              _birthDate != null
                                  ? AppFormatters.formatDateYmd(_birthDate!)
                                  : 'Pilih Tanggal',
                              style: TextStyle(
                                fontSize: 13,
                                color: _birthDate != null
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 11. Kewarganegaraan
                  TextFormField(
                    controller: _nationalityController,
                    decoration: const InputDecoration(
                      labelText: 'Kewarganegaraan',
                      hintText: 'Indonesia',
                      prefixIcon: Icon(Icons.public_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 12. Catatan / Preferensi (Opsional)
                  TextFormField(
                    controller: _internalNotesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (Opsional)',
                      hintText:
                          'Catatan khusus, preferensi kamar, atau alergi tamu...',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 2: PEMBAYARAN & KONFIRMASI TRANSAKSI
  // ===========================================================================
  Widget _buildStep2PaymentAndReview() {
    final guestName = AppFormatters.parseString(
      _registeredGuest?['full_name'],
      _fullNameController.text,
    );
    final guestCode = AppFormatters.parseString(
      _registeredGuest?['kode_tamu'],
      '-',
    );
    final guestPhone = AppFormatters.parseString(
      _registeredGuest?['phone'],
      _phoneController.text,
    );
    final guestIdNum = AppFormatters.parseString(
      _registeredGuest?['id_number'],
      _idNumberController.text,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card Identitas Tamu Terverifikasi
        Card(
          color: AppTheme.walkInGreenBg.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.walkInGreen),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.walkInGreen,
                      child: Icon(
                        Icons.verified_user_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_title. $guestName',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Kode Tamu: $guestCode · HP: $guestPhone',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _currentStep = 1),
                      child: const Text('Ubah', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Text(
                  'Identitas: ${_idType.toUpperCase()} — $guestIdNum · Tipe: ${_guestType == 'group' ? 'Group' : 'Individual'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Ringkasan Kamar & Rincian Harga
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ringkasan Pesanan Kamar',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _SummaryRow(label: 'Properti Hotel', value: _activeBranchName),
                const SizedBox(height: 4),
                _SummaryRow(
                  label: 'Check-In',
                  value: AppFormatters.formatDateShortId(_checkIn),
                ),
                const SizedBox(height: 4),
                _SummaryRow(
                  label: 'Check-Out',
                  value:
                      '${AppFormatters.formatDateShortId(_checkOut)} ($_nights Malam)',
                ),
                const Divider(height: 20),
                ..._selectedRooms.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _SummaryRow(
                      label: '${r.namaTipe} (${r.namaRatePlan}) x $_nights mlm',
                      value: AppFormatters.formatRupiah(
                        r.pricePerNight * _nights,
                      ),
                    ),
                  ),
                ),
                if (_facilitiesSubtotal > 0) ...[
                  const SizedBox(height: 4),
                  _SummaryRow(
                    label: 'Layanan & Fasilitas Tambahan',
                    value: AppFormatters.formatRupiah(_facilitiesSubtotal),
                  ),
                ],
                const Divider(height: 18),
                _SummaryRow(
                  label: 'Subtotal',
                  value: AppFormatters.formatRupiah(_subtotal),
                ),
                const SizedBox(height: 4),
                _SummaryRow(
                  label: 'Pajak & Service Charge Hotel',
                  value: AppFormatters.formatRupiah(_taxAndServiceTotal),
                ),
                const SizedBox(height: 8),
                _SummaryRow(
                  label: 'Total Pembayaran',
                  value: AppFormatters.formatRupiah(_grandTotal),
                  bold: true,
                  highlightColor: AppTheme.bookingBlue,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Metode Pembayaran ala Traveloka
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih Metode Pembayaran',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _PaymentOptionTile(
                  value: 'qris',
                  groupValue: _selectedPaymentMethod,
                  title: 'QRIS Instan (GoPay, OVO, Dana, M-Banking)',
                  subtitle: 'Konfirmasi otomatis & cepat',
                  icon: Icons.qr_code_2_rounded,
                  onTap: () => setState(() => _selectedPaymentMethod = 'qris'),
                ),
                const SizedBox(height: 8),
                _PaymentOptionTile(
                  value: 'transfer',
                  groupValue: _selectedPaymentMethod,
                  title: 'Transfer Bank / Virtual Account',
                  subtitle: 'BCA, Mandiri, BNI, BRI',
                  icon: Icons.account_balance_rounded,
                  onTap: () =>
                      setState(() => _selectedPaymentMethod = 'transfer'),
                ),
                if (_selectedPaymentMethod == 'transfer') ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('bank_$_selectedBank'),
                    initialValue: _selectedBank,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Bank Tujuan',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'BCA Virtual Account',
                        child: Text('BCA Virtual Account'),
                      ),
                      DropdownMenuItem(
                        value: 'Mandiri Virtual Account',
                        child: Text('Mandiri Virtual Account'),
                      ),
                      DropdownMenuItem(
                        value: 'BNI Virtual Account',
                        child: Text('BNI Virtual Account'),
                      ),
                      DropdownMenuItem(
                        value: 'BRI Virtual Account',
                        child: Text('BRI Virtual Account'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedBank = v);
                    },
                  ),
                ],
                const SizedBox(height: 8),
                _PaymentOptionTile(
                  value: 'card',
                  groupValue: _selectedPaymentMethod,
                  title: 'Kartu Debit / Kredit (Visa / Mastercard)',
                  subtitle: 'Pembayaran kartu terenkripsi',
                  icon: Icons.credit_card_rounded,
                  onTap: () => setState(() => _selectedPaymentMethod = 'card'),
                ),
                const SizedBox(height: 8),
                _PaymentOptionTile(
                  value: 'pay_at_hotel',
                  groupValue: _selectedPaymentMethod,
                  title: 'Bayar Saat Check-In di Hotel (Pay at Hotel)',
                  subtitle:
                      'Kamar langsung diamankan, bayar di resepsionis saat tiba',
                  icon: Icons.storefront_rounded,
                  onTap: () =>
                      setState(() => _selectedPaymentMethod = 'pay_at_hotel'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // STEP 3: E-VOUCHER RESERVASI SELESAI
  // ===========================================================================
  Widget _buildStep3SuccessVoucher() {
    final res = _completedReservationResult ?? const {};
    final kodeReservasi =
        AppFormatters.parseString(res['kode_reservasi'], 'RES-BARU');
    final invoiceNumber =
        AppFormatters.parseString(res['invoice_number'], '-');
    final kodeFolio = AppFormatters.parseString(res['kode_folio'], '-');
    final grandTotal =
        AppFormatters.parseDouble(res['grand_total'], _grandTotal);
    final statusLabel = AppFormatters.parseString(
      res['payment_status_label'],
      'Reservasi Terkonfirmasi',
    );
    final guestName = AppFormatters.parseString(
      _registeredGuest?['full_name'],
      _fullNameController.text,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.walkInGreen, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppTheme.walkInGreenBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.walkInGreen,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Reservasi Kamar Berhasil!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'E-Voucher Anda telah terbit dan tercatat di sistem resepsionis hotel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'KODE BOOKING RESERVASI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kodeReservasi,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No. Invoice: $invoiceNumber · Folio: $kodeFolio',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                _SummaryRow(label: 'Hotel', value: _activeBranchName, bold: true),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Nama Tamu Pemesan',
                  value: '$_title. $guestName',
                ),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Jadwal Check-In',
                  value: AppFormatters.formatDateShortId(_checkIn),
                ),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Jadwal Check-Out',
                  value:
                      '${AppFormatters.formatDateShortId(_checkOut)} ($_nights Malam)',
                ),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Jumlah Kamar',
                  value: '${_selectedRooms.length} Kamar',
                ),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Status Tagihan',
                  value: statusLabel,
                ),
                const Divider(height: 20),
                _SummaryRow(
                  label: 'Grand Total',
                  value: AppFormatters.formatRupiah(grandTotal),
                  bold: true,
                  highlightColor: AppTheme.primary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            context.go(AppRoutes.reservation);
          },
          icon: const Icon(Icons.confirmation_number_outlined),
          label: const Text('Lihat di Menu Pesanan Saya'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _resetForNewBooking,
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: const Text('Buat Reservasi Kamar Lainnya'),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            IconButton.outlined(
              onPressed: () => setState(() => _currentStep -= 1),
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              tooltip: 'Kembali',
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_selectedRooms.length} Kamar · $_nights Malam',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  AppFormatters.formatRupiah(_grandTotal),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: (_isSavingGuest || _isSubmittingBooking)
                  ? null
                  : () {
                      if (_currentStep == 0) {
                        if (_selectedRooms.isEmpty) {
                          setState(() {
                            _errorMessage =
                                'Pilih minimal 1 kamar dari katalog terlebih dahulu.';
                          });
                          return;
                        }
                        setState(() {
                          _errorMessage = null;
                          _currentStep = 1;
                        });
                      } else if (_currentStep == 1) {
                        _saveGuestIdentityAndProceed();
                      } else if (_currentStep == 2) {
                        _completeBookingTransaction();
                      }
                    },
              icon: (_isSavingGuest || _isSubmittingBooking)
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _currentStep == 2
                          ? Icons.lock_outline_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                    ),
              label: Text(
                _currentStep == 0
                    ? 'Isi Identitas'
                    : _currentStep == 1
                        ? 'Simpan & Bayar'
                        : 'Selesaikan Pesanan',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSelectTile extends StatelessWidget {
  const _DateSelectTile({
    required this.title,
    required this.dateText,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String dateText;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, size: 15, color: AppTheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    dateText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerRoomCatalogCard extends StatefulWidget {
  const _CustomerRoomCatalogCard({
    required this.roomType,
    required this.nights,
    required this.selectedCount,
    required this.onSelectPackage,
    this.onRemoveOne,
  });

  final Map<String, dynamic> roomType;
  final int nights;
  final int selectedCount;
  final ValueChanged<Map<String, dynamic>> onSelectPackage;
  final VoidCallback? onRemoveOne;

  @override
  State<_CustomerRoomCatalogCard> createState() =>
      _CustomerRoomCatalogCardState();
}

class _CustomerRoomCatalogCardState extends State<_CustomerRoomCatalogCard> {
  String? _selectedRatePlanCode;

  List<Map<String, dynamic>> get _packages {
    final raw = widget.roomType['packages'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic>? get _selectedRatePlan {
    final pkgs = _packages;
    if (pkgs.isEmpty) return null;
    if (_selectedRatePlanCode != null) {
      for (final p in pkgs) {
        if (AppFormatters.parseString(p['kode_rate_plan']) ==
            _selectedRatePlanCode) {
          return p;
        }
      }
    }
    return pkgs.first;
  }

  @override
  void initState() {
    super.initState();
    final pkgs = _packages;
    if (pkgs.isNotEmpty) {
      _selectedRatePlanCode =
          AppFormatters.parseString(pkgs.first['kode_rate_plan']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.roomType;
    final namaTipe = AppFormatters.parseString(r['nama_tipe'], 'Tipe Kamar');
    final deskripsi = AppFormatters.parseString(r['deskripsi']);
    final luas = AppFormatters.parseDouble(r['luas_m2']);
    final kapasitas = AppFormatters.parseInt(
      r['kapasitas_maksimal'] ?? r['kapasitas_dasar'],
      2,
    );
    final availableCount = AppFormatters.parseInt(r['available_count']);
    final rawFoto = AppFormatters.parseString(r['foto_cover_url']);
    final fotoUrl = AppConfig.resolveAssetUrl(rawFoto) ?? '';

    final fasilitas = (r['fasilitas'] is List ? r['fasilitas'] as List : const [])
        .whereType<Map>()
        .map((f) => AppFormatters.parseString(f['nama_fasilitas']))
        .where((s) => s.isNotEmpty)
        .toList();

    final amenities = (r['amenities'] is List ? r['amenities'] as List : const [])
        .whereType<Map>()
        .map((a) => AppFormatters.parseString(a['nama_amenity']))
        .where((s) => s.isNotEmpty)
        .toList();

    final allTags = [...fasilitas, ...amenities];
    final currentPkg = _selectedRatePlan;
    final pricePerNight =
        AppFormatters.parseDouble(currentPkg?['price_per_night']);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.selectedCount > 0 ? AppTheme.bookingBlue : AppTheme.border,
          width: widget.selectedCount > 0 ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gambar Kamar ala Traveloka
          Stack(
            children: [
              SizedBox(
                height: 165,
                width: double.infinity,
                child: fotoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: fotoUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: AppTheme.primaryLight,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, _, _) => _RoomPhotoPlaceholder(
                          title: namaTipe,
                        ),
                      )
                    : _RoomPhotoPlaceholder(title: namaTipe),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: StatusBadge(
                  label: availableCount > 0
                      ? 'Sisa $availableCount Kamar'
                      : 'Kamar Penuh',
                  variant: availableCount > 0
                      ? StatusBadgeVariant.readyGreen
                      : StatusBadgeVariant.dangerRed,
                ),
              ),
              if (widget.selectedCount > 0)
                Positioned(
                  top: 10,
                  left: 10,
                  child: StatusBadge(
                    label: '${widget.selectedCount} Dipilih',
                    variant: StatusBadgeVariant.occupiedBlue,
                  ),
                ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  namaTipe,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.people_outline_rounded,
                          size: 15,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Maks. $kapasitas Tamu',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (luas > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.square_foot_rounded,
                            size: 15,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${luas.toStringAsFixed(0)} m²',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (deskripsi.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    deskripsi,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                if (allTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: allTags.take(6).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const Divider(height: 20),

                // Pilihan Paket Harga (Rate Plan)
                if (_packages.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pilih Paket Harga:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Wrap(
                        spacing: 6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.event_repeat_rounded,
                                size: 13,
                                color: AppTheme.walkInGreen,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Bisa Reschedule',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.walkInGreen,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.verified_user_outlined,
                                size: 13,
                                color: AppTheme.bookingBlue,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Bisa Refund',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.bookingBlue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ..._packages.map((pkg) {
                    final code =
                        AppFormatters.parseString(pkg['kode_rate_plan']);
                    final name = AppFormatters.parseString(
                      pkg['nama_rate_plan'],
                      'Room Only',
                    );
                    final price =
                        AppFormatters.parseDouble(pkg['price_per_night']);
                    final isSelected =
                        code == (_selectedRatePlanCode ?? _packages.first['kode_rate_plan']);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() => _selectedRatePlanCode = code);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.bookingBlueBg.withValues(alpha: 0.45)
                                : AppTheme.surfaceMuted,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.bookingBlue
                                  : AppTheme.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 18,
                                color: isSelected
                                    ? AppTheme.bookingBlue
                                    : AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '${AppFormatters.formatRupiah(price)} / mlm',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.bookingBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total ${widget.nights} Malam:',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            AppFormatters.formatRupiah(
                              pricePerNight * widget.nights,
                            ),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onRemoveOne != null) ...[
                      IconButton.outlined(
                        onPressed: widget.onRemoveOne,
                        icon: const Icon(Icons.remove, size: 18),
                        tooltip: 'Kurangi Kamar',
                      ),
                      const SizedBox(width: 6),
                    ],
                    FilledButton.icon(
                      onPressed: availableCount > 0 && currentPkg != null
                          ? () => widget.onSelectPackage(currentPkg)
                          : null,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        widget.selectedCount > 0
                            ? 'Tambah Kamar'
                            : 'Pilih Kamar',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomPhotoPlaceholder extends StatelessWidget {
  const _RoomPhotoPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.king_bed_rounded,
              size: 44,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  const _PaymentOptionTile({
    required this.value,
    required this.groupValue,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String value;
  final String groupValue;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.bookingBlueBg.withValues(alpha: 0.45)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.bookingBlue : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.bookingBlue : AppTheme.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppTheme.bookingBlue : AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.highlightColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: bold ? 13.5 : 12.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: bold ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 12.5,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: highlightColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ExistingGuestLookupSheet extends ConsumerStatefulWidget {
  const _ExistingGuestLookupSheet({required this.branchCode});

  final String branchCode;

  @override
  ConsumerState<_ExistingGuestLookupSheet> createState() =>
      _ExistingGuestLookupSheetState();
}

class _ExistingGuestLookupSheetState
    extends ConsumerState<_ExistingGuestLookupSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _guests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGuests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGuests([String? kw]) async {
    setState(() => _isLoading = true);
    try {
      final list = await ref
          .read(reservationRepositoryProvider)
          .fetchGuestList(branchCode: widget.branchCode, keyword: kw);
      if (mounted) {
        setState(() => _guests = list);
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final q = _searchController.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _guests
        : _guests.where((g) {
            final name = (g['full_name'] ?? '').toString().toLowerCase();
            final phone = (g['phone'] ?? '').toString().toLowerCase();
            final idNum = (g['id_number'] ?? '').toString().toLowerCase();
            return name.contains(q) || phone.contains(q) || idNum.contains(q);
          }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cari Profil Identitas Tamu',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ketik Nama Lengkap, Nomor HP, atau Nomor KTP Anda.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              onSubmitted: (v) => _loadGuests(v),
              decoration: const InputDecoration(
                hintText: 'Cari nama, no. HP, atau KTP...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Data tamu tidak ditemukan. Silakan tutup dan isi formulir registrasi tamu baru.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final g = filtered[idx];
                    final name =
                        AppFormatters.parseString(g['full_name'], 'Tamu');
                    final phone = AppFormatters.parseString(g['phone'], '-');
                    final idNum =
                        AppFormatters.parseString(g['id_number'], '-');
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.border),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryLight,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'T',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        'HP: $phone · ID: $idNum',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.primary,
                      ),
                      onTap: () => Navigator.pop(context, g),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

