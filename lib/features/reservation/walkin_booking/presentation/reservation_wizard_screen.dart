import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/front_office_header_bar.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/session_notifier.dart';
import '../../../cashier_shift/presentation/active_shift_notifier.dart';
import '../../../cashier_shift/presentation/cashier_shift_sheet.dart';
import '../../../dashboard/presentation/dashboard_notifier.dart';
import '../../data/reservation_repository.dart';
import 'wizard_intent_provider.dart';

class SelectedRoomCartItem {
  SelectedRoomCartItem({
    required this.kodeTipeKamar,
    required this.namaTipe,
    required this.kodeRatePlan,
    required this.namaRatePlan,
    required this.pricePerNight,
    this.kodeKamar,
    this.nomorKamar,
  });

  final String kodeTipeKamar;
  final String namaTipe;
  final String kodeRatePlan;
  final String namaRatePlan;
  final double pricePerNight;
  final String? kodeKamar;
  final String? nomorKamar;
}

class ReservationWizardScreen extends ConsumerStatefulWidget {
  const ReservationWizardScreen({super.key});

  @override
  ConsumerState<ReservationWizardScreen> createState() =>
      _ReservationWizardScreenState();
}

class _ReservationWizardScreenState
    extends ConsumerState<ReservationWizardScreen> {
  bool _isWalkIn = true;
  int _currentStep = 0; // 0..3

  DateTime _checkIn = DateTime.now();
  DateTime _checkOut = DateTime.now().add(const Duration(days: 1));

  // Step 1: Room catalog & selected rooms
  List<Map<String, dynamic>> _roomTypes = [];
  bool _isLoadingRooms = false;
  final List<SelectedRoomCartItem> _selectedRooms = [];

  // Step 2: Extra facilities
  List<ExtraFacilityCatalogItem> _facilityCatalog = [];
  final Map<String, int> _facilityQuantities = {};

  // Step 3: Guest
  final _guestSearchController = TextEditingController();
  List<Map<String, dynamic>> _guestList = [];
  Map<String, dynamic>? _selectedGuest;
  bool _isSearchingGuest = false;

  // Step 4: Payment & confirmation
  late PaymentSelectionData _paymentData;
  final _paymentAmountController = TextEditingController();
  final _depositAmountController = TextEditingController(text: '0');
  final _specialRequestController = TextEditingController();
  final _guestCountController = TextEditingController(text: '2');

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _paymentData = PaymentSelectionData(
      paymentMethod: 'cash',
      referenceNo: AppFormatters.generatePaymentRefNo('cash'),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyLaunchIntentAndLoad();
    });
  }

  @override
  void dispose() {
    _guestSearchController.dispose();
    _paymentAmountController.dispose();
    _depositAmountController.dispose();
    _specialRequestController.dispose();
    _guestCountController.dispose();
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
      (sum, item) => sum + (item.pricePerNight * _nights),
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

  // Standard 10% tax + 11% service/tax or ~11% estimated tax
  double get _estimatedTax => (_subtotal * 0.11).roundToDouble();

  double get _estimatedGrandTotal => _subtotal + _estimatedTax;

  Future<void> _applyLaunchIntentAndLoad() async {
    final intent = ref.read(wizardIntentProvider.notifier).consumeIntent();
    if (intent != null) {
      setState(() {
        _isWalkIn = intent.isWalkIn;
        if (_isWalkIn) {
          _checkIn = DateTime.now();
          if (!_checkOut.isAfter(_checkIn)) {
            _checkOut = _checkIn.add(const Duration(days: 1));
          }
        }
        _currentStep = 0;
      });
    }
    await _loadRoomAndFacilityCatalog(intent: intent);
  }

  Future<void> _loadRoomAndFacilityCatalog({WizardLaunchIntent? intent}) async {
    final branchCode = ref.read(sessionProvider)?.activeKodeCabang ?? '';
    if (branchCode.isEmpty) return;

    setState(() {
      _isLoadingRooms = true;
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
        repo.fetchGuestList(branchCode: branchCode),
      ]);

      final packages = results[0] as List<Map<String, dynamic>>;
      final facilities = results[1] as List<ExtraFacilityCatalogItem>;
      final guests = results[2] as List<Map<String, dynamic>>;

      if (!mounted) return;
      setState(() {
        _roomTypes = packages;
        _facilityCatalog = facilities;
        _guestList = guests;

        if (intent?.preselectedRoomTypeCode != null) {
          final matchedType = packages.firstWhere(
            (t) =>
                t['kode_tipe_kamar']?.toString() ==
                intent!.preselectedRoomTypeCode,
            orElse: () => const {},
          );
          if (matchedType.isNotEmpty) {
            final rateList = matchedType['packages'];
            final firstRate =
                rateList is List && rateList.isNotEmpty && rateList.first is Map
                    ? Map<String, dynamic>.from(rateList.first as Map)
                    : null;
            if (firstRate != null) {
              _selectedRooms
                ..clear()
                ..add(
                  SelectedRoomCartItem(
                    kodeTipeKamar:
                        AppFormatters.parseString(matchedType['kode_tipe_kamar']),
                    namaTipe:
                        AppFormatters.parseString(matchedType['nama_tipe']),
                    kodeRatePlan:
                        AppFormatters.parseString(firstRate['kode_rate_plan']),
                    namaRatePlan:
                        AppFormatters.parseString(firstRate['nama_rate_plan']),
                    pricePerNight:
                        AppFormatters.parseDouble(firstRate['price_per_night']),
                    kodeKamar: intent!.preselectedRoomCode,
                    nomorKamar: intent.preselectedRoomNumber,
                  ),
                );
              _syncDefaultPaymentAmount();
            }
          }
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingRooms = false);
      }
    }
  }

  void _syncDefaultPaymentAmount() {
    final total = _estimatedGrandTotal.round();
    if (_isWalkIn) {
      _paymentAmountController.text = total.toString();
    } else {
      // Default booking DP 50%
      _depositAmountController.text = (total ~/ 2).toString();
    }
  }

  Future<void> _pickDate({required bool isCheckIn}) async {
    if (isCheckIn && _isWalkIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mode Walk-In Check-In otomatis menggunakan tanggal masuk hari ini.',
          ),
        ),
      );
      return;
    }

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
    await _loadRoomAndFacilityCatalog();
  }

  List<Map<String, dynamic>> get _filteredGuests {
    final q = _guestSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return _guestList;
    return _guestList.where((g) {
      final name = (g['full_name'] ?? '').toString().toLowerCase();
      final phone = (g['phone'] ?? '').toString().toLowerCase();
      final idNum = (g['id_number'] ?? '').toString().toLowerCase();
      final code = (g['kode_tamu'] ?? '').toString().toLowerCase();
      final email = (g['email'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          phone.contains(q) ||
          idNum.contains(q) ||
          code.contains(q) ||
          email.contains(q);
    }).toList();
  }

  Future<void> _searchGuest() async {
    final keyword = _guestSearchController.text.trim();
    final branchCode = ref.read(sessionProvider)?.activeKodeCabang ?? '';
    setState(() {
      _isSearchingGuest = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(reservationRepositoryProvider);
      final list = await repo.fetchGuestList(
        branchCode: branchCode,
        keyword: keyword.isEmpty ? null : keyword,
      );
      if (!mounted) return;
      setState(() {
        if (keyword.isEmpty) {
          _guestList = list;
        } else {
          final byCode = <String, Map<String, dynamic>>{};
          for (final g in list) {
            final c = (g['kode_tamu'] ?? '').toString();
            if (c.isNotEmpty) byCode[c] = g;
          }
          for (final g in _guestList) {
            final c = (g['kode_tamu'] ?? '').toString();
            if (c.isNotEmpty && !byCode.containsKey(c)) {
              byCode[c] = g;
            }
          }
          _guestList = byCode.values.toList();
          if (list.length == 1) {
            _selectedGuest = list.first;
          }
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSearchingGuest = false);
      }
    }
  }

  Future<void> _openCreateGuestSheet() async {
    final branchCode = ref.read(sessionProvider)?.activeKodeCabang ?? '';
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateGuestBottomSheet(
        branchCode: branchCode,
        initialKeyword: _guestSearchController.text.trim(),
      ),
    );
    if (created != null && mounted) {
      setState(() {
        _selectedGuest = created;
        final createdCode = (created['kode_tamu'] ?? '').toString();
        _guestList.removeWhere(
          (g) => (g['kode_tamu'] ?? '').toString() == createdCode,
        );
        _guestList.insert(0, created);
        _guestSearchController.clear();
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitTransaction() async {
    if (_isSubmitting) return;
    final branchCode = ref.read(sessionProvider)?.activeKodeCabang ?? '';
    final activeShift = ref.read(activeShiftProvider).value;

    if (_selectedRooms.isEmpty) {
      setState(() {
        _errorMessage = 'Pilih minimal 1 kamar terlebih dahulu.';
        _currentStep = 0;
      });
      return;
    }

    if (_isWalkIn &&
        _selectedRooms.any((r) => r.kodeKamar == null || r.kodeKamar!.isEmpty)) {
      setState(() {
        _errorMessage =
            'Transaksi Walk-In wajib memilih nomor kamar fisik untuk setiap kamar.';
        _currentStep = 0;
      });
      return;
    }

    if (_selectedGuest == null) {
      setState(() {
        _errorMessage = 'Pilih atau daftarkan data tamu terlebih dahulu.';
        _currentStep = 2;
      });
      return;
    }

    final paymentAmount =
        AppFormatters.parseDouble(_paymentAmountController.text);
    final depositAmount =
        AppFormatters.parseDouble(_depositAmountController.text);

    // Check Cashier Shift obligation
    final requiresShift =
        _isWalkIn || depositAmount > 0 || paymentAmount > 0;
    if (requiresShift && activeShift == null) {
      setState(() {
        _errorMessage =
            'Shift kasir belum dibuka. Silakan buka shift kasir terlebih dahulu.';
      });
      await CashierShiftSheet.show(context);
      return;
    }

    final extraFacilities = <Map<String, dynamic>>[];
    for (final fac in _facilityCatalog) {
      final qty = _facilityQuantities[fac.kodeFasilitas] ?? 0;
      if (qty > 0) {
        extraFacilities.add({
          'id': fac.chargeType,
          'kode_fasilitas': fac.kodeFasilitas,
          'nama': fac.nama,
          'qty': qty,
          'harga': fac.harga,
          'subtotal': fac.harga * qty,
        });
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(reservationRepositoryProvider);
      final guestCode = AppFormatters.parseString(_selectedGuest!['kode_tamu']);
      final checkInStr = AppFormatters.formatDateYmd(_checkIn);
      final checkOutStr = AppFormatters.formatDateYmd(_checkOut);

      Map<String, dynamic> result;
      if (_isWalkIn) {
        final payload = {
          'kode_cabang': branchCode,
          'kode_guest': guestCode,
          'check_in_date': checkInStr,
          'check_out_date': checkOutStr,
          'nights': _nights,
          'guest_count': AppFormatters.parseInt(_guestCountController.text, 2),
          'rooms': _selectedRooms
              .map(
                (r) => {
                  'kode_tipe_kamar': r.kodeTipeKamar,
                  'kode_kamar': r.kodeKamar,
                  'kode_rate_plan': r.kodeRatePlan,
                },
              )
              .toList(),
          'extra_facilities': extraFacilities,
          'special_request': _specialRequestController.text.trim(),
          'payment_amount': paymentAmount,
          'deposit_amount': depositAmount,
          'payment_method': _paymentData.paymentMethod,
          if (_paymentData.bankName.isNotEmpty)
            'bank_name': _paymentData.bankName,
          if (_paymentData.cardType.isNotEmpty)
            'card_type': _paymentData.cardType,
          'reference_no': _paymentData.referenceNo,
          if (activeShift != null)
            'kode_cashier_shift': activeShift.kodeCashierShift,
        };
        result = await repo.submitWalkIn(payload);
      } else {
        final payload = {
          'kode_cabang': branchCode,
          'kode_guest': guestCode,
          'check_in_date': checkInStr,
          'check_out_date': checkOutStr,
          'rooms': _selectedRooms
              .map(
                (r) => {
                  'kode_tipe_kamar': r.kodeTipeKamar,
                  'kode_rate_plan': r.kodeRatePlan,
                  if (r.kodeKamar != null && r.kodeKamar!.isNotEmpty)
                    'kode_kamar': r.kodeKamar,
                },
              )
              .toList(),
          'extra_facilities': extraFacilities,
          'special_request': _specialRequestController.text.trim(),
          'deposit_amount': depositAmount,
          if (depositAmount > 0) ...{
            'payment_method': _paymentData.paymentMethod,
            if (_paymentData.bankName.isNotEmpty)
              'bank_name': _paymentData.bankName,
            if (_paymentData.cardType.isNotEmpty)
              'card_type': _paymentData.cardType,
            'reference_no': _paymentData.referenceNo,
            if (activeShift != null)
              'kode_cashier_shift': activeShift.kodeCashierShift,
          },
        };
        result = await repo.createReservation(payload);
      }

      ref.invalidate(dashboardProvider);
      ref.invalidate(activeShiftProvider);

      if (!mounted) return;
      await _showSuccessDialog(result);

      if (!mounted) return;
      setState(() {
        _selectedRooms.clear();
        _facilityQuantities.clear();
        _selectedGuest = null;
        _guestSearchController.clear();
        _specialRequestController.clear();
        _currentStep = 0;
      });
      await _loadRoomAndFacilityCatalog();
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _showSuccessDialog(Map<String, dynamic> result) async {
    final kodeRes = AppFormatters.parseString(result['kode_reservasi'], '-');
    final kodeFolio = AppFormatters.parseString(result['kode_folio'], '-');
    final invoiceNo = AppFormatters.parseString(result['invoice_number'], '-');
    final grandTotal = AppFormatters.formatRupiah(result['grand_total']);
    final totalPaid = AppFormatters.formatRupiah(result['total_paid']);
    final balance = AppFormatters.formatRupiah(result['balance']);

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: _isWalkIn ? AppTheme.walkInGreen : AppTheme.bookingBlue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isWalkIn
                    ? 'Walk-In Check-In Berhasil'
                    : 'Booking Reservasi Berhasil',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryLine(label: 'Kode Reservasi', value: kodeRes, bold: true),
            const SizedBox(height: 4),
            _SummaryLine(label: 'Kode Folio', value: kodeFolio),
            const SizedBox(height: 4),
            _SummaryLine(label: 'No. Invoice', value: invoiceNo),
            const Divider(height: 18),
            _SummaryLine(label: 'Grand Total', value: grandTotal, bold: true),
            const SizedBox(height: 4),
            _SummaryLine(label: 'Sudah Dibayar / DP', value: totalPaid),
            const SizedBox(height: 4),
            _SummaryLine(label: 'Sisa Saldo Folio', value: balance),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  void _showFolioSummarySheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Estimasi Rincian Biaya Folio',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ..._selectedRooms.map(
                (r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: _SummaryLine(
                    label:
                        '${r.namaTipe} ${r.nomorKamar != null ? "(Kamar ${r.nomorKamar})" : ""} × $_nights mlm',
                    value: AppFormatters.formatRupiah(
                      r.pricePerNight * _nights,
                    ),
                  ),
                ),
              ),
              ..._facilityCatalog
                  .where((f) => (_facilityQuantities[f.kodeFasilitas] ?? 0) > 0)
                  .map((f) {
                final qty = _facilityQuantities[f.kodeFasilitas]!;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: _SummaryLine(
                    label: 'Add-On: ${f.nama} (${qty}x)',
                    value: AppFormatters.formatRupiah(f.harga * qty),
                  ),
                );
              }),
              const Divider(height: 18),
              _SummaryLine(
                label: 'Subtotal Kamar & Layanan',
                value: AppFormatters.formatRupiah(_subtotal),
              ),
              const SizedBox(height: 4),
              _SummaryLine(
                label: 'Estimasi Pajak & Service (~11%)',
                value: AppFormatters.formatRupiah(_estimatedTax),
              ),
              const Divider(height: 18),
              _SummaryLine(
                label: 'Estimasi Grand Total',
                value: AppFormatters.formatRupiah(_estimatedGrandTotal),
                bold: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for external launch intents from Dashboard/Room Rack
    ref.listen<WizardLaunchIntent?>(wizardIntentProvider, (prev, next) {
      if (next != null) {
        _applyLaunchIntentAndLoad();
      }
    });

    final activeColor =
        _isWalkIn ? AppTheme.walkInGreen : AppTheme.bookingBlue;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const FrontOfficeHeaderBar(compact: true),
            // Mode Switcher + 4-Step Indicator Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Column(
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.directions_walk_rounded, size: 18),
                        label: Text('Walk-In Check-In'),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.calendar_month_rounded, size: 18),
                        label: Text('Booking Reservasi'),
                      ),
                    ],
                    selected: {_isWalkIn},
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return _isWalkIn
                              ? AppTheme.walkInGreenBg
                              : AppTheme.bookingBlueBg;
                        }
                        return AppTheme.surface;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return activeColor;
                        }
                        return AppTheme.textSecondary;
                      }),
                    ),
                    onSelectionChanged: (val) {
                      final walkIn = val.first;
                      setState(() {
                        _isWalkIn = walkIn;
                        if (_isWalkIn) {
                          _checkIn = DateTime.now();
                          if (!_checkOut.isAfter(_checkIn)) {
                            _checkOut = _checkIn.add(const Duration(days: 1));
                          }
                        }
                        _selectedRooms.clear();
                      });
                      _loadRoomAndFacilityCatalog();
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _WizardStepTab(
                        stepNumber: 1,
                        label: 'Kamar',
                        active: _currentStep == 0,
                        completed: _selectedRooms.isNotEmpty,
                        color: activeColor,
                        onTap: () => setState(() => _currentStep = 0),
                      ),
                      _WizardStepTab(
                        stepNumber: 2,
                        label: 'Fasilitas',
                        active: _currentStep == 1,
                        completed: _facilitiesSubtotal > 0,
                        color: activeColor,
                        onTap: () => setState(() => _currentStep = 1),
                      ),
                      _WizardStepTab(
                        stepNumber: 3,
                        label: 'Tamu',
                        active: _currentStep == 2,
                        completed: _selectedGuest != null,
                        color: activeColor,
                        onTap: () => setState(() => _currentStep = 2),
                      ),
                      _WizardStepTab(
                        stepNumber: 4,
                        label: 'Bayar',
                        active: _currentStep == 3,
                        completed: false,
                        color: activeColor,
                        onTap: () {
                          _syncDefaultPaymentAmount();
                          setState(() => _currentStep = 3);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRedBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
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
                onRefresh: _loadRoomAndFacilityCatalog,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_currentStep == 0) _buildStep1Rooms(activeColor),
                    if (_currentStep == 1) _buildStep2Facilities(activeColor),
                    if (_currentStep == 2) _buildStep3Guest(activeColor),
                    if (_currentStep == 3) _buildStep4Payment(activeColor),
                  ],
                ),
              ),
            ),
            // Sticky Bottom Folio Summary Bar
            _StickyFolioSummaryBar(
              roomCount: _selectedRooms.length,
              nights: _nights,
              grandTotal: _estimatedGrandTotal,
              currentStep: _currentStep,
              isWalkIn: _isWalkIn,
              isSubmitting: _isSubmitting,
              onShowBreakdown: _showFolioSummarySheet,
              onNextOrSubmit: () {
                if (_currentStep < 3) {
                  if (_currentStep == 2) {
                    _syncDefaultPaymentAmount();
                  }
                  setState(() => _currentStep += 1);
                } else {
                  _submitTransaction();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Rooms(Color activeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Periode Menginap',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    StatusBadge(
                      label: '$_nights Malam',
                      variant: _isWalkIn
                          ? StatusBadgeVariant.readyGreen
                          : StatusBadgeVariant.occupiedBlue,
                      small: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isCheckIn: true),
                        icon: const Icon(Icons.login_rounded, size: 16),
                        label: Text(
                          'Masuk: ${AppFormatters.formatDateShortId(_checkIn)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(isCheckIn: false),
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: Text(
                          'Keluar: ${AppFormatters.formatDateShortId(_checkOut)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_selectedRooms.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: activeColor.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kamar Dipilih (${_selectedRooms.length} Unit):',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: activeColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _selectedRooms.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return InputChip(
                        label: Text(
                          '${item.namaTipe} ${item.nomorKamar != null ? "#${item.nomorKamar}" : "(Auto)"} · ${AppFormatters.formatRupiah(item.pricePerNight)}/mlm',
                          style: const TextStyle(fontSize: 11.5),
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
        const SizedBox(height: 14),
        const Text(
          'Katalog Tipe Kamar & Paket Harga',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (_isLoadingRooms)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_roomTypes.isEmpty)
          AppEmptyState(
            title: 'Katalog Kamar Kosong',
            subtitle: 'Tidak ada paket kamar tersedia untuk tanggal ini.',
            actionLabel: 'Muat Ulang',
            onAction: _loadRoomAndFacilityCatalog,
          )
        else
          ..._roomTypes.map(
            (roomType) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RoomTypeCatalogCard(
                roomType: roomType,
                isWalkIn: _isWalkIn,
                nights: _nights,
                selectedRooms: _selectedRooms,
                onRatePlanChanged: (kodeTipe, pkg) {
                  final newPlanCode =
                      AppFormatters.parseString(pkg['kode_rate_plan']);
                  final newPlanName =
                      AppFormatters.parseString(pkg['nama_rate_plan']);
                  final newPrice =
                      AppFormatters.parseDouble(pkg['price_per_night']);
                  setState(() {
                    for (int i = 0; i < _selectedRooms.length; i++) {
                      final r = _selectedRooms[i];
                      if (r.kodeTipeKamar == kodeTipe) {
                        _selectedRooms[i] = SelectedRoomCartItem(
                          kodeTipeKamar: r.kodeTipeKamar,
                          namaTipe: r.namaTipe,
                          kodeRatePlan: newPlanCode,
                          namaRatePlan: newPlanName,
                          pricePerNight: newPrice,
                          kodeKamar: r.kodeKamar,
                          nomorKamar: r.nomorKamar,
                        );
                      }
                    }
                  });
                },
                onToggleRoom: (cartItem) {
                  setState(() {
                    if (cartItem.kodeKamar != null) {
                      final existingIdx = _selectedRooms.indexWhere(
                        (r) => r.kodeKamar == cartItem.kodeKamar,
                      );
                      if (existingIdx >= 0) {
                        _selectedRooms.removeAt(existingIdx);
                      } else {
                        _selectedRooms.add(cartItem);
                      }
                    } else {
                      _selectedRooms.add(cartItem);
                    }
                  });
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStep2Facilities(Color activeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Fasilitas & Layanan Tambahan (Add-On)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Opsional — pilih layanan ekstra seperti Extra Bed, Sarapan, atau Laundry untuk dimasukkan ke Folio.',
          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        if (_facilityCatalog.isEmpty)
          const AppEmptyState(
            icon: Icons.room_service_outlined,
            title: 'Belum Ada Katalog Add-On',
            subtitle: 'Anda dapat langsung melanjutkan ke Langkah 3 (Data Tamu).',
          )
        else
          ..._facilityCatalog.map((item) {
            final qty = _facilityQuantities[item.kodeFasilitas] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: qty > 0
                              ? activeColor.withValues(alpha: 0.12)
                              : AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.chargeType == 'restaurant'
                              ? Icons.restaurant_outlined
                              : item.chargeType == 'laundry'
                                  ? Icons.local_laundry_service_outlined
                                  : Icons.add_box_outlined,
                          color:
                              qty > 0 ? activeColor : AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.nama,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              '${AppFormatters.formatRupiah(item.harga)} / item',
                              style: const TextStyle(
                                fontSize: 12,
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
                        icon: const Icon(Icons.remove, size: 16),
                        visualDensity: VisualDensity.compact,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '$qty',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () {
                          setState(() {
                            _facilityQuantities[item.kodeFasilitas] = qty + 1;
                          });
                        },
                        icon: const Icon(Icons.add, size: 16),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildStep3Guest(Color activeColor) {
    final filtered = _filteredGuests;
    final selectedCode = (_selectedGuest?['kode_tamu'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pencarian & Pilih Data Tamu',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ketik Nama Tamu, Nomor HP, atau KTP untuk memfilter daftar tamu, atau ketuk langsung dari daftar tamu di bawah.',
          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _guestSearchController,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _searchGuest(),
                decoration: InputDecoration(
                  hintText: 'Cari nama tamu, no. HP, atau KTP...',
                  prefixIcon: const Icon(Icons.person_search_outlined),
                  suffixIcon: _guestSearchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _guestSearchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear_rounded, size: 18),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _isSearchingGuest ? null : _searchGuest,
                icon: _isSearchingGuest
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search, size: 18),
                label: const Text('Cari'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _openCreateGuestSheet,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('+ Buat Tamu Baru'),
        ),
        if (_selectedGuest != null) ...[
          const SizedBox(height: 14),
          Card(
            color: activeColor.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: activeColor, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: activeColor,
                        radius: 18,
                        child: const Icon(
                          Icons.person,
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
                              AppFormatters.parseString(
                                _selectedGuest!['full_name'],
                                'Tamu Terpilih',
                              ),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'HP: ${_selectedGuest!['phone'] ?? '-'} · Kode: ${_selectedGuest!['kode_tamu'] ?? '-'}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const StatusBadge(
                        label: 'TERPILIH',
                        variant: StatusBadgeVariant.readyGreen,
                        small: true,
                      ),
                    ],
                  ),
                  const Divider(height: 18),
                  _SummaryLine(
                    label: 'Identitas',
                    value:
                        '${(_selectedGuest!['id_type'] ?? 'KTP').toString().toUpperCase()} — ${_selectedGuest!['id_number'] ?? '-'}',
                  ),
                  if (_selectedGuest!['email'] != null &&
                      _selectedGuest!['email'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _SummaryLine(
                      label: 'Email',
                      value: _selectedGuest!['email'].toString(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Daftar Tamu Terdaftar (${filtered.length} Tamu)',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _isSearchingGuest ? null : _searchGuest,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Muat Ulang', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_isSearchingGuest && _guestList.isEmpty)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (filtered.isEmpty)
          AppEmptyState(
            icon: Icons.person_off_outlined,
            title: _guestSearchController.text.trim().isEmpty
                ? 'Belum Ada Tamu Terdaftar'
                : 'Tamu "${_guestSearchController.text.trim()}" Tidak Ditemukan',
            subtitle:
                'Ketuk tombol "+ Buat Tamu Baru" di atas untuk mendaftarkan tamu baru.',
            actionLabel: '+ Buat Tamu Baru',
            onAction: _openCreateGuestSheet,
          )
        else
          ...filtered.map((guest) {
            final code = AppFormatters.parseString(guest['kode_tamu']);
            final name = AppFormatters.parseString(guest['full_name'], 'Tamu');
            final phone = AppFormatters.parseString(guest['phone'], '-');
            final idType =
                AppFormatters.parseString(guest['id_type'], 'KTP').toUpperCase();
            final idNum = AppFormatters.parseString(guest['id_number'], '-');
            final isSelected = selectedCode.isNotEmpty && selectedCode == code;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() {
                    _selectedGuest = guest;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? activeColor : AppTheme.border,
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isSelected
                            ? activeColor
                            : AppTheme.primary.withValues(alpha: 0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'T',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'HP: $phone · $idType: $idNum',
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
                      const SizedBox(width: 8),
                      if (isSelected)
                        Icon(
                          Icons.check_circle_rounded,
                          color: activeColor,
                          size: 22,
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: const Text(
                            'Pilih',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildStep4Payment(Color activeColor) {
    final activeShift = ref.watch(activeShiftProvider).value;
    final grandTotal = _estimatedGrandTotal.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ringkasan Pesanan & Folio',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _SummaryLine(
                  label: 'Tamu',
                  value: AppFormatters.parseString(
                    _selectedGuest?['full_name'],
                    'Belum dipilih',
                  ),
                  bold: true,
                ),
                const SizedBox(height: 4),
                _SummaryLine(
                  label: 'Periode',
                  value:
                      '${AppFormatters.formatDateShortId(_checkIn)} - ${AppFormatters.formatDateShortId(_checkOut)} ($_nights Malam)',
                ),
                const SizedBox(height: 4),
                _SummaryLine(
                  label: 'Jumlah Kamar',
                  value: '${_selectedRooms.length} Unit Kamar',
                ),
                const Divider(height: 18),
                _SummaryLine(
                  label: 'Subtotal Kamar & Fasilitas',
                  value: AppFormatters.formatRupiah(_subtotal),
                ),
                const SizedBox(height: 4),
                _SummaryLine(
                  label: 'Estimasi Pajak & Service',
                  value: AppFormatters.formatRupiah(_estimatedTax),
                ),
                const SizedBox(height: 6),
                _SummaryLine(
                  label: 'Estimasi Grand Total',
                  value: AppFormatters.formatRupiah(_estimatedGrandTotal),
                  bold: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isWalkIn) ...[
                  TextFormField(
                    controller: _paymentAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal Pembayaran Sewa Kamar (Rp)',
                      prefixIcon: Icon(Icons.payments_outlined),
                      helperText:
                          'Memotong langsung saldo tagihan sewa kamar di Folio',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: Text(
                          'Lunas (${AppFormatters.formatRupiah(grandTotal)})',
                        ),
                        onPressed: () => setState(
                          () => _paymentAmountController.text =
                              grandTotal.toString(),
                        ),
                      ),
                      ActionChip(
                        label: const Text('Bayar Saat Checkout (Rp 0)'),
                        onPressed: () => setState(
                          () => _paymentAmountController.text = '0',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _depositAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Uang Jaminan / Security Deposit (Opsional Rp)',
                      prefixIcon: Icon(Icons.shield_outlined),
                    ),
                  ),
                ] else ...[
                  TextFormField(
                    controller: _depositAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal Down Payment (DP) / Pembayaran (Rp)',
                      prefixIcon: Icon(Icons.payments_outlined),
                      helperText:
                          'Isi 0 jika reservasi belum disertai uang muka (status Reserved)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: Text(
                          'Lunas 100% (${AppFormatters.formatRupiah(grandTotal)})',
                        ),
                        onPressed: () => setState(
                          () => _depositAmountController.text =
                              grandTotal.toString(),
                        ),
                      ),
                      ActionChip(
                        label: Text(
                          'DP 50% (${AppFormatters.formatRupiah(grandTotal ~/ 2)})',
                        ),
                        onPressed: () => setState(
                          () => _depositAmountController.text =
                              (grandTotal ~/ 2).toString(),
                        ),
                      ),
                      ActionChip(
                        label: const Text('Tanpa DP (Rp 0)'),
                        onPressed: () => setState(
                          () => _depositAmountController.text = '0',
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                PaymentMethodSelector(
                  value: _paymentData,
                  activeShiftCode: activeShift?.kodeCashierShift,
                  requireShiftForAllMethods: _isWalkIn,
                  onOpenShiftRequested: () => CashierShiftSheet.show(context),
                  onChanged: (val) => setState(() => _paymentData = val),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _specialRequestController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Permintaan Khusus / Special Request (Opsional)',
                    hintText: 'Contoh: Kamar bebas asap rokok, lantai atas',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WizardStepTab extends StatelessWidget {
  const _WizardStepTab({
    required this.stepNumber,
    required this.label,
    required this.active,
    required this.completed,
    required this.color,
    required this.onTap,
  });

  final int stepNumber;
  final String label;
  final bool active;
  final bool completed;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.14)
                : (completed
                    ? AppTheme.walkInGreenBg.withValues(alpha: 0.5)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? color : AppTheme.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 9,
                backgroundColor: active
                    ? color
                    : (completed ? AppTheme.walkInGreen : AppTheme.border),
                child: completed && !active
                    ? const Icon(Icons.check, size: 11, color: Colors.white)
                    : Text(
                        '$stepNumber',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: active ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? color : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomTypeCatalogCard extends StatefulWidget {
  const _RoomTypeCatalogCard({
    required this.roomType,
    required this.isWalkIn,
    required this.nights,
    required this.selectedRooms,
    required this.onRatePlanChanged,
    required this.onToggleRoom,
  });

  final Map<String, dynamic> roomType;
  final bool isWalkIn;
  final int nights;
  final List<SelectedRoomCartItem> selectedRooms;
  final void Function(String kodeTipeKamar, Map<String, dynamic> ratePlan)
      onRatePlanChanged;
  final ValueChanged<SelectedRoomCartItem> onToggleRoom;

  @override
  State<_RoomTypeCatalogCard> createState() => _RoomTypeCatalogCardState();
}

class _RoomTypeCatalogCardState extends State<_RoomTypeCatalogCard> {
  String? _selectedRatePlanCode;

  List<Map<String, dynamic>> get _packages {
    final raw = widget.roomType['packages'];
    if (raw is! List) return const [];
    final seenCodes = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final item in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final code = AppFormatters.parseString(
        map['kode_rate_plan'],
        'RP-${result.length}',
      );
      if (seenCodes.add(code)) {
        result.add(map);
      }
    }
    return result;
  }

  List<Map<String, dynamic>> get _availablePhysicalRooms {
    final raw = widget.roomType['available_rooms'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
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
  void didUpdateWidget(covariant _RoomTypeCatalogCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pkgs = _packages;
    if (pkgs.isNotEmpty &&
        !pkgs.any(
          (p) =>
              AppFormatters.parseString(p['kode_rate_plan']) ==
              _selectedRatePlanCode,
        )) {
      _selectedRatePlanCode =
          AppFormatters.parseString(pkgs.first['kode_rate_plan']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = AppFormatters.parseString(widget.roomType['kode_tipe_kamar']);
    final name =
        AppFormatters.parseString(widget.roomType['nama_tipe'], 'Tipe Kamar');
    final availCount =
        AppFormatters.parseInt(widget.roomType['available_count']);
    final luas = AppFormatters.parseInt(widget.roomType['luas_m2'], 24);
    final kap = AppFormatters.parseInt(widget.roomType['kapasitas_dasar'], 2);
    final rawPhoto = widget.roomType['foto_cover_url']?.toString();
    final photoUrl = AppConfig.resolveAssetUrl(rawPhoto);
    final packages = _packages;
    final activePkg = packages.firstWhere(
      (p) =>
          AppFormatters.parseString(p['kode_rate_plan']) ==
          _selectedRatePlanCode,
      orElse: () =>
          packages.isNotEmpty ? packages.first : <String, dynamic>{},
    );
    final hasActivePkg = activePkg.isNotEmpty;
    final availRooms = _availablePhysicalRooms;
    final themeColor =
        widget.isWalkIn ? AppTheme.walkInGreen : AppTheme.bookingBlue;
    final themeBg =
        widget.isWalkIn ? AppTheme.walkInGreenBg : AppTheme.bookingBlueBg;
    final selectedCountForType = widget.selectedRooms
        .where((s) => s.kodeTipeKamar == code)
        .length;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selectedCountForType > 0 ? themeColor : AppTheme.border,
          width: selectedCountForType > 0 ? 1.6 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Room Type Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 68,
                    height: 68,
                    color: AppTheme.primaryLight,
                    child: photoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => const Icon(
                              Icons.king_bed_outlined,
                              color: AppTheme.primary,
                              size: 30,
                            ),
                          )
                        : const Icon(
                            Icons.king_bed_outlined,
                            color: AppTheme.primary,
                            size: 30,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          StatusBadge(
                            label: availCount > 0
                                ? '$availCount Ready'
                                : 'Penuh',
                            variant: availCount > 0
                                ? StatusBadgeVariant.readyGreen
                                : StatusBadgeVariant.dangerRed,
                            small: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _RoomSpecChip(
                            icon: Icons.people_outline_rounded,
                            label: '$kap Dewasa',
                          ),
                          _RoomSpecChip(
                            icon: Icons.square_foot_rounded,
                            label: '$luas m²',
                          ),
                          _RoomSpecChip(
                            icon: Icons.tag_rounded,
                            label: code,
                          ),
                        ],
                      ),
                      if (hasActivePkg) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              AppFormatters.formatRupiah(
                                activePkg['price_per_night'],
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: themeColor,
                              ),
                            ),
                            const Text(
                              ' / malam',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // Interactive Rate Plan Selector Cards (100% immune to Dropdown Map assertion)
            if (packages.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Pilih Paket Tarif (Rate Plan):',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              ...packages.map((pkg) {
                final rpCode =
                    AppFormatters.parseString(pkg['kode_rate_plan']);
                final rpName = AppFormatters.parseString(
                  pkg['nama_rate_plan'],
                  'Standard Rate',
                );
                final pricePerNight =
                    AppFormatters.parseDouble(pkg['price_per_night']);
                final isSelectedRp = rpCode ==
                    AppFormatters.parseString(activePkg['kode_rate_plan']);
                final isBreakfast =
                    AppFormatters.parseBool(pkg['is_breakfast_included']) ||
                        rpName.toLowerCase().contains('breakfast') ||
                        rpName.toLowerCase().contains('sarapan');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedRatePlanCode = rpCode);
                      widget.onRatePlanChanged(code, pkg);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelectedRp
                            ? themeBg.withValues(alpha: 0.55)
                            : AppTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelectedRp ? themeColor : AppTheme.border,
                          width: isSelectedRp ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelectedRp
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 18,
                            color: isSelectedRp
                                ? themeColor
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rpName,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelectedRp
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  isBreakfast
                                      ? 'Termasuk Sarapan · Kode $rpCode'
                                      : 'Room Only · Kode $rpCode',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${AppFormatters.formatRupiah(pricePerNight)}/mlm',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: isSelectedRp
                                      ? themeColor
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              if (widget.nights > 1)
                                Text(
                                  'Total ${AppFormatters.formatRupiah(pricePerNight * widget.nights)}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
            const Divider(height: 18),
            // Physical Room Allocation Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.isWalkIn
                        ? 'Ketuk Nomor Kamar Fisik (Wajib Walk-In):'
                        : 'Ketuk Nomor Kamar Fisik (Opsional Booking):',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                if (selectedCountForType > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: themeBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$selectedCountForType Dipilih',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: themeColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (availRooms.isEmpty && widget.isWalkIn)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRedBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Tidak ada kamar fisik berstatus Clean & Vacant pada tipe ini.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.dangerRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...availRooms.map((rm) {
                    final rmCode = AppFormatters.parseString(rm['kode_kamar']);
                    final rmNo = AppFormatters.parseString(rm['nomor_kamar']);
                    final lantai = AppFormatters.parseString(rm['lantai']);
                    final isSelected = widget.selectedRooms.any(
                      (s) => s.kodeKamar == rmCode,
                    );
                    return FilterChip(
                      selected: isSelected,
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        lantai.isNotEmpty
                            ? 'Kamar #$rmNo ($lantai)'
                            : 'Kamar #$rmNo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      selectedColor: themeBg,
                      checkmarkColor: themeColor,
                      side: BorderSide(
                        color: isSelected ? themeColor : AppTheme.border,
                      ),
                      onSelected: !hasActivePkg
                          ? null
                          : (_) {
                              widget.onToggleRoom(
                                SelectedRoomCartItem(
                                  kodeTipeKamar: code,
                                  namaTipe: name,
                                  kodeRatePlan: AppFormatters.parseString(
                                    activePkg['kode_rate_plan'],
                                  ),
                                  namaRatePlan: AppFormatters.parseString(
                                    activePkg['nama_rate_plan'],
                                  ),
                                  pricePerNight: AppFormatters.parseDouble(
                                    activePkg['price_per_night'],
                                  ),
                                  kodeKamar: rmCode,
                                  nomorKamar: rmNo,
                                ),
                              );
                            },
                    );
                  }),
                  if (!widget.isWalkIn && availCount > 0 && hasActivePkg)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: themeBg.withValues(alpha: 0.5),
                      side: BorderSide(color: themeColor),
                      avatar: Icon(Icons.add_rounded, size: 16, color: themeColor),
                      label: Text(
                        'Tambah Tanpa No. Kamar',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: themeColor,
                        ),
                      ),
                      onPressed: () {
                        widget.onToggleRoom(
                          SelectedRoomCartItem(
                            kodeTipeKamar: code,
                            namaTipe: name,
                            kodeRatePlan: AppFormatters.parseString(
                              activePkg['kode_rate_plan'],
                            ),
                            namaRatePlan: AppFormatters.parseString(
                              activePkg['nama_rate_plan'],
                            ),
                            pricePerNight: AppFormatters.parseDouble(
                              activePkg['price_per_night'],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RoomSpecChip extends StatelessWidget {
  const _RoomSpecChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StickyFolioSummaryBar extends StatelessWidget {
  const _StickyFolioSummaryBar({
    required this.roomCount,
    required this.nights,
    required this.grandTotal,
    required this.currentStep,
    required this.isWalkIn,
    required this.isSubmitting,
    required this.onShowBreakdown,
    required this.onNextOrSubmit,
  });

  final int roomCount;
  final int nights;
  final double grandTotal;
  final int currentStep;
  final bool isWalkIn;
  final bool isSubmitting;
  final VoidCallback onShowBreakdown;
  final VoidCallback onNextOrSubmit;

  @override
  Widget build(BuildContext context) {
    final primaryColor = isWalkIn ? AppTheme.walkInGreen : AppTheme.bookingBlue;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onShowBreakdown,
              borderRadius: BorderRadius.circular(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '$roomCount Kamar · $nights Malam',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                    ],
                  ),
                  Text(
                    AppFormatters.formatRupiah(grandTotal),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: isSubmitting ? null : onNextOrSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            ),
            icon: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    currentStep < 3
                        ? Icons.arrow_forward_rounded
                        : Icons.check_circle_outline,
                    size: 18,
                  ),
            label: Text(
              currentStep < 3
                  ? 'Lanjut Langkah ${currentStep + 2}'
                  : (isSubmitting ? 'Menyimpan...' : 'Konfirmasi & Simpan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateGuestBottomSheet extends ConsumerStatefulWidget {
  const _CreateGuestBottomSheet({
    required this.branchCode,
    required this.initialKeyword,
  });

  final String branchCode;
  final String initialKeyword;

  @override
  ConsumerState<_CreateGuestBottomSheet> createState() =>
      _CreateGuestBottomSheetState();
}

class _CreateGuestBottomSheetState
    extends ConsumerState<_CreateGuestBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nationalityController = TextEditingController(text: 'Indonesia');
  String _idType = 'ktp';
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialKeyword.isNotEmpty) {
      final kw = widget.initialKeyword.trim();
      final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(kw);
      if (kw.startsWith('08') || kw.startsWith('+62')) {
        _phoneController.text = kw;
      } else if (hasLetters) {
        _nameController.text = kw;
      } else {
        _idNumberController.text = kw;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idNumberController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nationalityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final guest = await ref.read(reservationRepositoryProvider).createGuest(
            branchCode: widget.branchCode,
            fullName: _nameController.text.trim(),
            idType: _idType,
            idNumber: _idNumberController.text.trim(),
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
            nationality: _nationalityController.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context, guest);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Registrasi Tamu Baru',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRedBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppTheme.dangerRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap Tamu *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 125,
                      child: DropdownButtonFormField<String>(
                        initialValue: _idType,
                        decoration: const InputDecoration(labelText: 'Tipe ID'),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _idNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Nomor Identitas *',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Nomor ID wajib diisi'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Telepon / WhatsApp *',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nomor telepon wajib diisi'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (Opsional)',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _isSaving ? 'Menyimpan...' : 'Simpan & Pilih Tamu Ini',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: bold ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 13.5 : 12.5,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

