import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/session_notifier.dart';
import '../../reservation/data/reservation_repository.dart';

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _bookings = [];
  String _selectedTab = 'all'; // 'all' | 'active' | 'inhouse' | 'history'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyBookings();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMyBookings() async {
    final branchCode = ref.read(sessionProvider)?.activeKodeCabang ?? 'CAB0001';
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await ref
          .read(reservationRepositoryProvider)
          .fetchCustomerReservations(
            branchCode: branchCode,
            searchKeyword: _searchController.text.trim(),
          );
      if (mounted) {
        setState(() => _bookings = list);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _resolveEffectiveStatus(Map<String, dynamic> item) {
    final resStatus =
        AppFormatters.parseString(item['res_status']).toLowerCase();
    final roomStatus =
        AppFormatters.parseString(item['room_status']).toLowerCase();
    if (resStatus == 'cancelled' || roomStatus == 'cancelled') {
      return 'cancelled';
    }
    if (roomStatus == 'checked_out' || resStatus == 'checked_out') {
      return 'checked_out';
    }
    if (roomStatus == 'checked_in' || resStatus == 'checked_in') {
      return 'checked_in';
    }
    if (resStatus == 'confirmed' || roomStatus == 'confirmed') {
      return 'confirmed';
    }
    return roomStatus.isNotEmpty
        ? roomStatus
        : (resStatus.isNotEmpty ? resStatus : 'reserved');
  }

  List<Map<String, dynamic>> get _filteredBookings {
    return _bookings.where((item) {
      final st = _resolveEffectiveStatus(item);
      switch (_selectedTab) {
        case 'active':
          return const ['reserved', 'confirmed', 'booked', 'assigned']
              .contains(st);
        case 'inhouse':
          return st == 'checked_in';
        case 'history':
          return st == 'checked_out' || st == 'cancelled';
        default:
          return true;
      }
    }).toList();
  }

  void _showVoucherSheet(Map<String, dynamic> item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BookingVoucherDetailSheet(
        booking: item,
        onOpenReschedule: () {
          Navigator.pop(context);
          _openRescheduleSheet(item);
        },
        onOpenCancelRefund: () {
          Navigator.pop(context);
          _openCancelRefundSheet(item);
        },
        onOpenExtendStay: () {
          Navigator.pop(context);
          _openExtendStaySheet(item);
        },
      ),
    );
  }

  Future<void> _openRescheduleSheet(Map<String, dynamic> item) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustomerRescheduleBottomSheet(booking: item),
    );
    if (updated == true && mounted) {
      await _loadMyBookings();
    }
  }

  Future<void> _openCancelRefundSheet(Map<String, dynamic> item) async {
    final cancelled = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustomerCancelRefundBottomSheet(booking: item),
    );
    if (cancelled == true && mounted) {
      await _loadMyBookings();
    }
  }

  Future<void> _openExtendStaySheet(Map<String, dynamic> item) async {
    final extended = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustomerExtendStayBottomSheet(booking: item),
    );
    if (extended == true && mounted) {
      await _loadMyBookings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchName =
        ref.watch(sessionProvider)?.activeBranchName ?? 'Grand Marstech Hotel';
    final filtered = _filteredBookings;

    final activeCount = _bookings.where((b) {
      final st = _resolveEffectiveStatus(b);
      return const ['reserved', 'confirmed', 'booked', 'assigned'].contains(st);
    }).length;
    final inhouseCount =
        _bookings.where((b) => _resolveEffectiveStatus(b) == 'checked_in').length;
    final historyCount = _bookings.where((b) {
      final st = _resolveEffectiveStatus(b);
      return st == 'checked_out' || st == 'cancelled';
    }).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header Traveloka-Style
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F4C81), Color(0xFF1E6BB8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_rounded,
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
                          'Pesanan Saya & Kelola Jadwal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'E-Voucher, Reschedule & Refund · $branchName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isLoading ? null : _loadMyBookings,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                    ),
                    tooltip: 'Muat Ulang',
                  ),
                ],
              ),
            ),

            // Filter Kategori Pesanan ala Traveloka
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterTabChip(
                      label: 'Semua (${_bookings.length})',
                      isSelected: _selectedTab == 'all',
                      onTap: () => setState(() => _selectedTab = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterTabChip(
                      label: 'Aktif ($activeCount)',
                      isSelected: _selectedTab == 'active',
                      onTap: () => setState(() => _selectedTab = 'active'),
                    ),
                    const SizedBox(width: 8),
                    _FilterTabChip(
                      label: 'Sedang Menginap ($inhouseCount)',
                      isSelected: _selectedTab == 'inhouse',
                      onTap: () => setState(() => _selectedTab = 'inhouse'),
                    ),
                    const SizedBox(width: 8),
                    _FilterTabChip(
                      label: 'Selesai / Refund ($historyCount)',
                      isSelected: _selectedTab == 'history',
                      onTap: () => setState(() => _selectedTab = 'history'),
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _loadMyBookings(),
                      decoration: InputDecoration(
                        hintText:
                            'Cari Kode Booking (RES-...), Nama, atau No. HP...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _loadMyBookings();
                                },
                                icon: const Icon(Icons.clear_rounded, size: 18),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 46,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _loadMyBookings,
                      child: const Text('Cari'),
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRedBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.dangerRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMyBookings,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              AppEmptyState(
                                icon: Icons.receipt_long_outlined,
                                title: 'Belum Ada Pesanan pada Kategori Ini',
                                subtitle:
                                    'Pesan kamar hotel pilihan Anda pada menu Pesan Kamar atau ubah filter kategori di atas.',
                                actionLabel: 'Cari & Pesan Kamar',
                                onAction: () => context.go(AppRoutes.home),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, idx) {
                              final item = filtered[idx];
                              final kodeRes = AppFormatters.parseString(
                                item['kode_reservasi'],
                                '-',
                              );
                              final guestName = AppFormatters.parseString(
                                item['guest_name'],
                                'Tamu Hotel',
                              );
                              final roomType = AppFormatters.parseString(
                                item['tipe_kamar_name'],
                                'Kamar Hotel',
                              );
                              final nomorKamar =
                                  AppFormatters.parseString(item['nomor_kamar']);
                              final checkIn = AppFormatters.formatDateShortId(
                                item['check_in_date'],
                              );
                              final checkOut = AppFormatters.formatDateShortId(
                                item['check_out_date'],
                              );
                              final nights =
                                  AppFormatters.parseInt(item['nights'], 1);
                              final deposit = AppFormatters.parseDouble(
                                item['deposit_amount'],
                              );
                              final grandTotal = AppFormatters.parseDouble(
                                item['folio_grand_total'],
                                AppFormatters.parseDouble(
                                      item['rate_per_night'],
                                    ) *
                                    nights,
                              );
                              final effectiveStatus =
                                  _resolveEffectiveStatus(item);
                              final canModify = const [
                                'reserved',
                                'confirmed',
                                'booked',
                                'assigned',
                              ].contains(effectiveStatus);
                              final isInHouse = effectiveStatus == 'checked_in';
                              final isCancelled =
                                  effectiveStatus == 'cancelled';

                              final (badgeLabel, badgeVariant) =
                                  switch (effectiveStatus) {
                                'checked_in' => (
                                    'SEDANG MENGINAP',
                                    StatusBadgeVariant.readyGreen
                                  ),
                                'checked_out' => (
                                    'SELESAI MENGINAP',
                                    StatusBadgeVariant.neutralSlate
                                  ),
                                'cancelled' => (
                                    'DIBATALKAN / REFUND',
                                    StatusBadgeVariant.dangerRed
                                  ),
                                'confirmed' => (
                                    'TERKONFIRMASI',
                                    StatusBadgeVariant.readyGreen
                                  ),
                                _ => (
                                    'MENUNGGU CHECK-IN',
                                    StatusBadgeVariant.occupiedBlue
                                  ),
                              };

                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isCancelled
                                        ? AppTheme.dangerRed.withValues(
                                            alpha: 0.4,
                                          )
                                        : AppTheme.border,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showVoucherSheet(item),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: [
                                                  StatusBadge(
                                                    label: kodeRes,
                                                    variant: StatusBadgeVariant
                                                        .occupiedBlue,
                                                    small: true,
                                                  ),
                                                  StatusBadge(
                                                    label: badgeLabel,
                                                    variant: badgeVariant,
                                                    small: true,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.qr_code_rounded,
                                              color: AppTheme.primary,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          roomType +
                                              (nomorKamar.isNotEmpty
                                                  ? ' (Kamar #$nomorKamar)'
                                                  : ''),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Pemesan: $guestName · $nights Malam',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today_rounded,
                                              size: 14,
                                              color: AppTheme.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '$checkIn → $checkOut',
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 18),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  deposit > 0
                                                      ? 'Total Tagihan (Deposit: ${AppFormatters.formatRupiah(deposit)})'
                                                      : 'Total Tagihan (Bayar saat Check-In)',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppTheme.textSecondary,
                                                  ),
                                                ),
                                                Text(
                                                  AppFormatters.formatRupiah(
                                                    grandTotal,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 14.5,
                                                    fontWeight: FontWeight.w900,
                                                    color: AppTheme.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _showVoucherSheet(item),
                                              icon: const Icon(
                                                Icons.confirmation_number_outlined,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'E-Voucher',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Tombol Aksi Reschedule & Refund ala Traveloka
                                        if (canModify) ...[
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: FilledButton.tonalIcon(
                                                  onPressed: () =>
                                                      _openRescheduleSheet(item),
                                                  icon: const Icon(
                                                    Icons.event_repeat_rounded,
                                                    size: 16,
                                                  ),
                                                  label: const Text(
                                                    'Reschedule',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _openCancelRefundSheet(
                                                        item,
                                                      ),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                        foregroundColor:
                                                            AppTheme.dangerRed,
                                                        side: const BorderSide(
                                                          color: AppTheme
                                                              .dangerRed,
                                                        ),
                                                      ),
                                                  icon: const Icon(
                                                    Icons.currency_exchange_rounded,
                                                    size: 15,
                                                  ),
                                                  label: Text(
                                                    deposit > 0
                                                        ? 'Ajukan Refund'
                                                        : 'Batalkan',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else if (isInHouse) ...[
                                          const SizedBox(height: 10),
                                          SizedBox(
                                            width: double.infinity,
                                            child: FilledButton.tonalIcon(
                                              onPressed: () =>
                                                  _openExtendStaySheet(item),
                                              icon: const Icon(
                                                Icons.add_alarm_rounded,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'Perpanjang Menginap (Extend Stay)',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTabChip extends StatelessWidget {
  const _FilterTabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 1. SHEET E-VOUCHER & RINCIAN FOLIO LENGKAP
// =============================================================================
class _BookingVoucherDetailSheet extends ConsumerStatefulWidget {
  const _BookingVoucherDetailSheet({
    required this.booking,
    required this.onOpenReschedule,
    required this.onOpenCancelRefund,
    required this.onOpenExtendStay,
  });

  final Map<String, dynamic> booking;
  final VoidCallback onOpenReschedule;
  final VoidCallback onOpenCancelRefund;
  final VoidCallback onOpenExtendStay;

  @override
  ConsumerState<_BookingVoucherDetailSheet> createState() =>
      _BookingVoucherDetailSheetState();
}

class _BookingVoucherDetailSheetState
    extends ConsumerState<_BookingVoucherDetailSheet> {
  Map<String, dynamic>? _folioDetail;
  bool _isLoadingFolio = false;

  @override
  void initState() {
    super.initState();
    _loadFolio();
  }

  Future<void> _loadFolio() async {
    final kodeRes =
        AppFormatters.parseString(widget.booking['kode_reservasi']);
    final kodeFolio = AppFormatters.parseString(widget.booking['kode_folio']);
    if (kodeRes.isEmpty && kodeFolio.isEmpty) return;

    setState(() => _isLoadingFolio = true);
    try {
      final detail = await ref
          .read(reservationRepositoryProvider)
          .fetchFolioDetail(
            kodeFolio: kodeFolio.isNotEmpty ? kodeFolio : null,
            kodeReservation: kodeRes.isNotEmpty ? kodeRes : null,
          );
      if (mounted) {
        setState(() => _folioDetail = detail);
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingFolio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final kodeRes = AppFormatters.parseString(b['kode_reservasi'], '-');
    final kodeFolio = AppFormatters.parseString(b['kode_folio'], '-');
    final hotelName = AppFormatters.parseString(
      b['nama_cabang'],
      'Grand Marstech Hotel',
    );
    final guestName = AppFormatters.parseString(b['guest_name'], '-');
    final guestPhone = AppFormatters.parseString(b['guest_phone'], '-');
    final guestId = AppFormatters.parseString(b['guest_id_number'], '-');
    final roomType = AppFormatters.parseString(
      b['tipe_kamar_name'],
      'Kamar Hotel',
    );
    final nomorKamar = AppFormatters.parseString(
      b['nomor_kamar'],
      'Dialokasikan saat Check-In',
    );
    final checkIn = AppFormatters.formatDateShortId(b['check_in_date']);
    final checkOut = AppFormatters.formatDateShortId(b['check_out_date']);
    final nights = AppFormatters.parseInt(b['nights'], 1);
    final deposit = AppFormatters.parseDouble(b['deposit_amount']);
    final grandTotal = AppFormatters.parseDouble(
      b['folio_grand_total'],
      AppFormatters.parseDouble(b['rate_per_night']) * nights,
    );
    final specialReq = AppFormatters.parseString(b['special_request']);

    final resStatus = AppFormatters.parseString(b['res_status']).toLowerCase();
    final roomStatus =
        AppFormatters.parseString(b['room_status']).toLowerCase();
    final isCancelled = resStatus == 'cancelled' || roomStatus == 'cancelled';
    final isCheckedIn = roomStatus == 'checked_in' || resStatus == 'checked_in';
    final canModify = !isCancelled &&
        !isCheckedIn &&
        roomStatus != 'checked_out' &&
        resStatus != 'checked_out';

    final payments = (_folioDetail?['payments'] is List)
        ? (_folioDetail!['payments'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const <Map<String, dynamic>>[];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isCancelled
                        ? Icons.cancel_rounded
                        : Icons.verified_rounded,
                    color: isCancelled
                        ? AppTheme.dangerRed
                        : AppTheme.walkInGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCancelled
                          ? 'Detail Pembatalan & Refund'
                          : 'E-Voucher Reservasi Hotel',
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isCancelled
                      ? AppTheme.dangerRedBg
                      : AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      isCancelled
                          ? 'PESANAN TELAH DIBATALKAN'
                          : 'TUNJUKKAN KODE BOOKING INI SAAT CHECK-IN',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isCancelled
                            ? AppTheme.dangerRed
                            : AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kodeRes,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isCancelled
                            ? AppTheme.dangerRed
                            : AppTheme.primary,
                      ),
                    ),
                    Text(
                      'No. Folio: $kodeFolio',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _DetailLine(label: 'Properti Hotel', value: hotelName),
              _DetailLine(label: 'Nama Tamu', value: guestName),
              _DetailLine(label: 'No. Telepon', value: guestPhone),
              _DetailLine(label: 'No. Identitas', value: guestId),
              const Divider(height: 20),
              _DetailLine(label: 'Tipe Kamar', value: roomType),
              _DetailLine(label: 'Nomor Kamar', value: nomorKamar),
              _DetailLine(label: 'Tanggal Check-In', value: checkIn),
              _DetailLine(
                label: 'Tanggal Check-Out',
                value: '$checkOut ($nights Malam)',
              ),
              if (specialReq.isNotEmpty)
                _DetailLine(label: 'Catatan / Riwayat', value: specialReq),
              const Divider(height: 20),
              _DetailLine(
                label: 'Total Tagihan Kamar & Pajak',
                value: AppFormatters.formatRupiah(grandTotal),
                bold: true,
              ),
              _DetailLine(
                label: 'Deposit / Pembayaran Masuk',
                value: AppFormatters.formatRupiah(deposit),
              ),
              if (_isLoadingFolio)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (payments.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Riwayat Transaksi Pembayaran & Refund:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                ...payments.map((p) {
                  final amt = AppFormatters.parseDouble(p['amount']);
                  final isRefund = amt < 0;
                  final method =
                      AppFormatters.parseString(p['payment_method'], 'transfer')
                          .toUpperCase();
                  final refNo = AppFormatters.parseString(p['reference_no']);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${isRefund ? "Refund Dana" : "Pembayaran"} ($method)${refNo.isNotEmpty ? " · $refNo" : ""}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isRefund
                                  ? AppTheme.walkInGreen
                                  : AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${isRefund ? "Dikembalikan " : ""}${AppFormatters.formatRupiah(amt.abs())}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isRefund
                                ? AppTheme.walkInGreen
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              if (canModify) ...[
                const Divider(height: 22),
                const Text(
                  'Kelola Pesanan Anda (Layanan Mandiri Pelanggan)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: widget.onOpenReschedule,
                        icon: const Icon(Icons.event_repeat_rounded, size: 16),
                        label: const Text('Ubah Jadwal'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onOpenCancelRefund,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.dangerRed,
                          side: const BorderSide(color: AppTheme.dangerRed),
                        ),
                        icon: const Icon(
                          Icons.currency_exchange_rounded,
                          size: 16,
                        ),
                        label: Text(
                          deposit > 0 ? 'Ajukan Refund' : 'Batalkan',
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (isCheckedIn) ...[
                const Divider(height: 22),
                FilledButton.tonalIcon(
                  onPressed: widget.onOpenExtendStay,
                  icon: const Icon(Icons.add_alarm_rounded, size: 18),
                  label: const Text('Perpanjang Menginap (Extend Stay)'),
                ),
              ],
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 2. SHEET EASY RESCHEDULE (SIMULASI TANGGAL BARU & REKONSILIASI HARGA)
// =============================================================================
class _CustomerRescheduleBottomSheet extends ConsumerStatefulWidget {
  const _CustomerRescheduleBottomSheet({required this.booking});

  final Map<String, dynamic> booking;

  @override
  ConsumerState<_CustomerRescheduleBottomSheet> createState() =>
      _CustomerRescheduleBottomSheetState();
}

class _CustomerRescheduleBottomSheetState
    extends ConsumerState<_CustomerRescheduleBottomSheet> {
  late DateTime _newCheckIn;
  late DateTime _newCheckOut;
  final _notesController = TextEditingController();

  bool _isChecking = false;
  bool _isSubmitting = false;
  String? _error;
  Map<String, dynamic>? _simulation;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rawCin =
        DateTime.tryParse(
          AppFormatters.parseString(widget.booking['check_in_date']),
        ) ??
        today;
    final rawCout =
        DateTime.tryParse(
          AppFormatters.parseString(widget.booking['check_out_date']),
        ) ??
        rawCin.add(const Duration(days: 1));

    _newCheckIn = rawCin.isBefore(today)
        ? today.add(const Duration(days: 1))
        : rawCin.add(const Duration(days: 1));
    _newCheckOut = _newCheckIn.add(
      Duration(days: MathHelper.maxInt(1, rawCout.difference(rawCin).inDays)),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runSimulation();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isCheckIn}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = isCheckIn ? _newCheckIn : _newCheckOut;
    final first = isCheckIn ? today : _newCheckIn.add(const Duration(days: 1));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isCheckIn) {
        _newCheckIn = picked;
        if (!_newCheckOut.isAfter(_newCheckIn)) {
          _newCheckOut = _newCheckIn.add(const Duration(days: 1));
        }
      } else {
        _newCheckOut = picked;
      }
    });
    await _runSimulation();
  }

  Future<void> _runSimulation() async {
    final kodeRes =
        AppFormatters.parseString(widget.booking['kode_reservasi']);
    if (kodeRes.isEmpty) return;

    setState(() {
      _isChecking = true;
      _error = null;
    });

    try {
      final sim = await ref
          .read(reservationRepositoryProvider)
          .checkReschedule(
            kodeReservasi: kodeRes,
            newCheckInDate: AppFormatters.formatDateYmd(_newCheckIn),
            newCheckOutDate: AppFormatters.formatDateYmd(_newCheckOut),
          );
      if (mounted) {
        setState(() => _simulation = sim);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _submitReschedule() async {
    if (_isSubmitting) return;
    final kodeRes =
        AppFormatters.parseString(widget.booking['kode_reservasi']);

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final resp = await ref
          .read(reservationRepositoryProvider)
          .submitReschedule(
            kodeReservasi: kodeRes,
            newCheckInDate: AppFormatters.formatDateYmd(_newCheckIn),
            newCheckOutDate: AppFormatters.formatDateYmd(_newCheckOut),
            notes: _notesController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppFormatters.parseString(
              resp['message'],
              'Jadwal menginap berhasil diubah (Reschedule)!',
            ),
          ),
          backgroundColor: AppTheme.walkInGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final kodeRes =
        AppFormatters.parseString(widget.booking['kode_reservasi'], '-');
    final roomType = AppFormatters.parseString(
      widget.booking['tipe_kamar_name'],
      'Kamar Hotel',
    );
    final oldCin = AppFormatters.formatDateShortId(
      widget.booking['check_in_date'],
    );
    final oldCout = AppFormatters.formatDateShortId(
      widget.booking['check_out_date'],
    );

    final isAvail = AppFormatters.parseBool(_simulation?['is_available'], true);
    final oldTotal =
        AppFormatters.parseDouble(_simulation?['old_total_room_charge']);
    final newTotal =
        AppFormatters.parseDouble(_simulation?['new_total_room_charge']);
    final rawDiff = AppFormatters.parseDouble(_simulation?['raw_diff']);
    final newNights = AppFormatters.parseInt(_simulation?['new_nights'], 1);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.event_repeat_rounded,
                    color: AppTheme.bookingBlue,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Easy Reschedule (Ubah Jadwal)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '$kodeRes · $roomType',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  'Jadwal Awal: $oldCin → $oldCout',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pilih Tanggal Menginap Baru:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isCheckIn: true),
                      icon: const Icon(Icons.login_rounded, size: 16),
                      label: Text(
                        'Masuk: ${AppFormatters.formatDateShortId(_newCheckIn)}',
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
                        'Keluar: ${AppFormatters.formatDateShortId(_newCheckOut)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
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

              if (_isChecking)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_simulation != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isAvail
                        ? AppTheme.walkInGreenBg.withValues(alpha: 0.5)
                        : AppTheme.dangerRedBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isAvail ? AppTheme.walkInGreen : AppTheme.dangerRed,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isAvail
                                ? Icons.check_circle_rounded
                                : Icons.error_outline_rounded,
                            size: 18,
                            color: isAvail
                                ? AppTheme.walkInGreen
                                : AppTheme.dangerRed,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isAvail
                                  ? 'Kamar Tersedia ($newNights Malam)'
                                  : 'Kamar Penuh pada Tanggal Baru',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isAvail
                                    ? AppTheme.walkInGreen
                                    : AppTheme.dangerRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      _DetailLine(
                        label: 'Total Sewa Kamar Lama',
                        value: AppFormatters.formatRupiah(oldTotal),
                      ),
                      _DetailLine(
                        label: 'Total Sewa Kamar Baru ($newNights Malam)',
                        value: AppFormatters.formatRupiah(newTotal),
                      ),
                      _DetailLine(
                        label: rawDiff > 0
                            ? 'Selisih Tambahan Biaya'
                            : (rawDiff < 0
                                ? 'Pengurangan Tagihan (Hemat)'
                                : 'Selisih Harga'),
                        value: rawDiff == 0
                            ? 'Rp 0 (Tidak Ada Biaya Tambahan)'
                            : '${rawDiff > 0 ? "+" : "-"}${AppFormatters.formatRupiah(rawDiff.abs())}',
                        bold: true,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Alasan / Catatan Ubah Jadwal (Opsional)',
                  hintText: 'Contoh: Perubahan jadwal penerbangan / perjalanan',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: (_isChecking || _isSubmitting || !isAvail)
                      ? null
                      : _submitReschedule,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    _isSubmitting
                        ? 'Memproses Reschedule...'
                        : 'Konfirmasi Ubah Jadwal Menginap',
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

// =============================================================================
// 3. SHEET PEMBATALAN PESANAN & PENGAJUAN REFUND DANA (CANCEL & REFUND)
// =============================================================================
class _CustomerCancelRefundBottomSheet extends ConsumerStatefulWidget {
  const _CustomerCancelRefundBottomSheet({required this.booking});

  final Map<String, dynamic> booking;

  @override
  ConsumerState<_CustomerCancelRefundBottomSheet> createState() =>
      _CustomerCancelRefundBottomSheetState();
}

class _CustomerCancelRefundBottomSheetState
    extends ConsumerState<_CustomerCancelRefundBottomSheet> {
  static const List<String> _reasons = [
    'Perubahan rencana / tanggal perjalanan',
    'Ingin mengganti tipe kamar atau properti hotel',
    'Kesalahan input data pemesanan',
    'Kondisi darurat / alasan kesehatan',
    'Lainnya',
  ];

  String _selectedReason = _reasons.first;
  String _refundMethod = 'transfer'; // 'transfer' | 'qris' | 'card'
  String _selectedBank = 'BCA';
  final _accountNumberController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _accountNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Kalkulasi Kebijakan Pembatalan & Denda Berjenjang (Traveloka-like Policy)
  // ---------------------------------------------------------------------------
  ({
    int penaltyPercent,
    double penaltyAmount,
    double refundAmount,
    String policyTitle,
    String policyBadge,
    Color badgeColor,
    String policyDescription,
    bool isNonRefundablePackage,
  }) _calculateCancellationPolicy() {
    final deposit = AppFormatters.parseDouble(widget.booking['deposit_amount']);

    // 1. Cek apakah paket promo / non-refundable
    final isNonRefundable =
        AppFormatters.parseBool(widget.booking['is_non_refundable'], false) ||
        !AppFormatters.parseBool(widget.booking['is_refundable'], true) ||
        !AppFormatters.parseBool(widget.booking['bisa_refund'], true) ||
        AppFormatters.parseString(widget.booking['cancellation_policy'])
            .toLowerCase()
            .contains('non-refundable') ||
        AppFormatters.parseString(widget.booking['rate_plan_name'])
            .toLowerCase()
            .contains('non-refundable');

    if (isNonRefundable) {
      return (
        penaltyPercent: 100,
        penaltyAmount: deposit,
        refundAmount: 0.0,
        policyTitle: 'Paket Promo Non-Refundable',
        policyBadge: 'Non-Refundable (100% Denda)',
        badgeColor: AppTheme.dangerRed,
        policyDescription:
            'Paket kamar ini bertipe promo khusus non-refundable. Dana deposit tidak dapat dikembalikan saat pembatalan.',
        isNonRefundablePackage: true,
      );
    }

    if (deposit <= 0) {
      return (
        penaltyPercent: 0,
        penaltyAmount: 0.0,
        refundAmount: 0.0,
        policyTitle: 'Pembatalan Tanpa Deposit',
        policyBadge: 'Bebas Biaya (Rp 0)',
        badgeColor: AppTheme.textSecondary,
        policyDescription:
            'Reservasi ini belum memiliki pembayaran uang muka/deposit. Pembatalan bebas biaya tanpa penalti.',
        isNonRefundablePackage: false,
      );
    }

    // 2. Hitung sisa waktu kedatangan (Check-In)
    final checkInRaw =
        AppFormatters.parseString(widget.booking['check_in_date']);
    DateTime? checkIn = DateTime.tryParse(checkInRaw);
    if (checkIn != null) {
      if (checkIn.hour == 0 && checkIn.minute == 0) {
        checkIn = DateTime(checkIn.year, checkIn.month, checkIn.day, 14, 0);
      }
    }
    final now = DateTime.now();
    final difference =
        checkIn != null ? checkIn.difference(now) : const Duration(days: 99);
    final totalHours = difference.inHours;

    // a. ≥ H-3 (≥ 72 jam): Penalti 0% (Full Refund 100%)
    if (totalHours >= 72) {
      return (
        penaltyPercent: 0,
        penaltyAmount: 0.0,
        refundAmount: deposit,
        policyTitle: 'Gratis Pembatalan (Full Refund 100%)',
        policyBadge: 'Bebas Denda (≥ H-3)',
        badgeColor: AppTheme.walkInGreen,
        policyDescription:
            'Pembatalan dilakukan lebih dari 3 hari sebelum jadwal check-in. Anda berhak mendapatkan pengembalian dana 100% tanpa potongan denda.',
        isNonRefundablePackage: false,
      );
    }

    // b. H-2 s/d H-1 (24 - 72 jam): Penalti 20%, Refund 80%
    if (totalHours >= 24) {
      final penalty = (deposit * 0.20).roundToDouble();
      final refund = (deposit - penalty).clamp(0.0, deposit);
      return (
        penaltyPercent: 20,
        penaltyAmount: penalty,
        refundAmount: refund,
        policyTitle: 'Pembatalan H-2 s/d H-1 (Denda 20%)',
        policyBadge: 'Denda 20% (H-2 s/d H-1)',
        badgeColor: Colors.orange.shade800,
        policyDescription:
            'Pembatalan dilakukan antara 24 hingga 72 jam sebelum check-in. Dikenakan biaya pembatalan hotel 20% dan dana 80% dikembalikan.',
        isNonRefundablePackage: false,
      );
    }

    // c. Hari H (< 24 jam): Penalti 50%, Refund 50%
    final penalty = (deposit * 0.50).roundToDouble();
    final refund = (deposit - penalty).clamp(0.0, deposit);
    return (
      penaltyPercent: 50,
      penaltyAmount: penalty,
      refundAmount: refund,
      policyTitle: 'Pembatalan Hari H (Denda 50%)',
      policyBadge: 'Denda 50% (Hari H)',
      badgeColor: AppTheme.dangerRed,
      policyDescription:
          'Pembatalan dilakukan kurang dari 24 jam sebelum check-in. Dikenakan biaya pembatalan hotel 50% dan sisa dana 50% dikembalikan.',
      isNonRefundablePackage: false,
    );
  }

  Future<void> _submitCancelAndRefund() async {
    if (_isSubmitting) return;
    final policy = _calculateCancellationPolicy();
    final kodeRes =
        AppFormatters.parseString(widget.booking['kode_reservasi']);

    if (policy.refundAmount > 0 &&
        _accountNumberController.text.trim().isEmpty) {
      setState(() {
        _error =
            'Masukkan Nomor Rekening / Nomor E-Wallet tujuan pengembalian dana (Refund).';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final acct = _accountNumberController.text.trim();
      final extraNote = _notesController.text.trim();
      final combinedNotes = [
        if (policy.refundAmount > 0)
          'Pencairan Refund via ${_refundMethod.toUpperCase()}${_refundMethod == "transfer" ? " ($_selectedBank)" : ""}: $acct',
        if (extraNote.isNotEmpty) extraNote,
      ].join(' | ');

      final payload = <String, dynamic>{
        'kode_reservasi': kodeRes,
        'cancellation_reason': _selectedReason,
        'notes': combinedNotes,
        'refund_type':
            policy.refundAmount > 0 ? 'refund_deposit' : 'non_refundable',
        'penalty_amount': policy.penaltyAmount,
        'payment_method': policy.refundAmount > 0 ? _refundMethod : null,
        if (policy.refundAmount > 0 && _refundMethod == 'transfer')
          'bank_name': _selectedBank,
        'reference_no': acct.isNotEmpty ? acct : 'CUST-CANCEL-$kodeRes',
      };

      final resp = await ref
          .read(reservationRepositoryProvider)
          .submitCancelReservation(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppFormatters.parseString(
              resp['message'],
              policy.refundAmount > 0
                  ? 'Pesanan dibatalkan. Pengajuan refund ${AppFormatters.formatRupiah(policy.refundAmount)} berhasil diproses!'
                  : 'Pesanan berhasil dibatalkan.',
            ),
          ),
          backgroundColor: AppTheme.walkInGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final kodeRes =
        AppFormatters.parseString(widget.booking['kode_reservasi'], '-');
    final roomType = AppFormatters.parseString(
      widget.booking['tipe_kamar_name'],
      'Kamar Hotel',
    );
    final deposit = AppFormatters.parseDouble(widget.booking['deposit_amount']);
    final policy = _calculateCancellationPolicy();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    policy.refundAmount > 0
                        ? Icons.currency_exchange_rounded
                        : Icons.cancel_outlined,
                    color: policy.refundAmount > 0
                        ? AppTheme.walkInGreen
                        : AppTheme.dangerRed,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          policy.refundAmount > 0
                              ? 'Ajukan Pembatalan & Refund Dana'
                              : 'Batalkan Pesanan Kamar',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '$kodeRes · $roomType',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Kartu Rincian Kebijakan Pembatalan & Estimasi Refund
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: policy.refundAmount > 0
                      ? AppTheme.walkInGreenBg.withValues(alpha: 0.45)
                      : (deposit > 0
                          ? AppTheme.dangerRedBg.withValues(alpha: 0.35)
                          : AppTheme.surfaceMuted),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: policy.refundAmount > 0
                        ? AppTheme.walkInGreen
                        : (deposit > 0 ? AppTheme.dangerRed : AppTheme.border),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            policy.policyTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: policy.refundAmount > 0
                                  ? AppTheme.walkInGreen
                                  : (deposit > 0
                                      ? AppTheme.dangerRed
                                      : AppTheme.textPrimary),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: policy.badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: policy.badgeColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            policy.policyBadge,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: policy.badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      policy.policyDescription,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const Divider(height: 16),
                    _DetailLine(
                      label: 'Dana Deposit / Terbayar',
                      value: AppFormatters.formatRupiah(deposit),
                    ),
                    _DetailLine(
                      label:
                          'Potongan Denda Pembatalan (${policy.penaltyPercent}%)',
                      value: policy.penaltyAmount > 0
                          ? '- ${AppFormatters.formatRupiah(policy.penaltyAmount)}'
                          : 'Rp 0 (Bebas Biaya)',
                    ),
                    _DetailLine(
                      label: 'Total Estimasi Refund Kembali',
                      value: AppFormatters.formatRupiah(policy.refundAmount),
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
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

              // Pilihan Alasan Pembatalan
              DropdownButtonFormField<String>(
                key: ValueKey('reason_$_selectedReason'),
                initialValue: _selectedReason,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Pilih Alasan Pembatalan *',
                  prefixIcon: Icon(Icons.help_outline_rounded),
                ),
                items: _reasons
                    .map(
                      (r) => DropdownMenuItem<String>(
                        value: r,
                        child: Text(
                          r,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedReason = v);
                },
              ),

              if (policy.refundAmount > 0) ...[
                const SizedBox(height: 12),
                const Text(
                  'Metode Pencairan Dana Refund:',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'transfer',
                      label: Text(
                        'Transfer Bank',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ),
                    ButtonSegment(
                      value: 'qris',
                      label: Text(
                        'E-Wallet / QRIS',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ),
                    ButtonSegment(
                      value: 'card',
                      label: Text('Kartu', style: TextStyle(fontSize: 11.5)),
                    ),
                  ],
                  selected: {_refundMethod},
                  onSelectionChanged: (v) {
                    if (v.isNotEmpty) {
                      setState(() => _refundMethod = v.first);
                    }
                  },
                ),
                const SizedBox(height: 10),
                if (_refundMethod == 'transfer') ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey('ref_bank_$_selectedBank'),
                    initialValue: _selectedBank,
                    decoration: const InputDecoration(
                      labelText: 'Bank Tujuan Refund',
                      prefixIcon: Icon(Icons.account_balance_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'BCA', child: Text('Bank BCA')),
                      DropdownMenuItem(
                        value: 'Mandiri',
                        child: Text('Bank Mandiri'),
                      ),
                      DropdownMenuItem(value: 'BNI', child: Text('Bank BNI')),
                      DropdownMenuItem(value: 'BRI', child: Text('Bank BRI')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedBank = v);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: _accountNumberController,
                  decoration: InputDecoration(
                    labelText: _refundMethod == 'transfer'
                        ? 'Nomor Rekening & Nama Pemilik *'
                        : 'Nomor Akun E-Wallet / Kartu Tujuan *',
                    hintText: _refundMethod == 'transfer'
                        ? 'Contoh: 1234567890 a.n Budi Santoso'
                        : 'Contoh: 081234567890 (GoPay/OVO/Dana)',
                    prefixIcon:
                        const Icon(Icons.account_balance_wallet_outlined),
                  ),
                ),
              ] else if (deposit > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRedBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.dangerRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.dangerRed,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sesuai ketentuan, seluruh dana deposit sebesar ${AppFormatters.formatRupiah(deposit)} menjadi denda pembatalan dan tidak dapat dikembalikan.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.dangerRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Catatan Tambahan (Opsional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: policy.refundAmount > 0
                        ? AppTheme.walkInGreen
                        : AppTheme.dangerRed,
                  ),
                  onPressed: _isSubmitting ? null : _submitCancelAndRefund,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          policy.refundAmount > 0
                              ? Icons.currency_exchange_rounded
                              : Icons.cancel_outlined,
                        ),
                  label: Text(
                    _isSubmitting
                        ? 'Memproses...'
                        : (policy.refundAmount > 0
                            ? 'Konfirmasi Batalkan & Ajukan Refund'
                            : 'Konfirmasi Batalkan Pesanan'),
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
// =============================================================================
// 4. SHEET PERPANJANG MENGINAP (EXTEND STAY) SAAT TAMU SEDANG IN-HOUSE
// =============================================================================
class _CustomerExtendStayBottomSheet extends ConsumerStatefulWidget {
  const _CustomerExtendStayBottomSheet({required this.booking});

  final Map<String, dynamic> booking;

  @override
  ConsumerState<_CustomerExtendStayBottomSheet> createState() =>
      _CustomerExtendStayBottomSheetState();
}

class _CustomerExtendStayBottomSheetState
    extends ConsumerState<_CustomerExtendStayBottomSheet> {
  late DateTime _newCheckOut;
  bool _isChecking = false;
  bool _isSubmitting = false;
  String? _error;
  Map<String, dynamic>? _extendSim;

  @override
  void initState() {
    super.initState();
    final currentCout =
        DateTime.tryParse(
          AppFormatters.parseString(widget.booking['check_out_date']),
        ) ??
        DateTime.now().add(const Duration(days: 1));
    _newCheckOut = currentCout.add(const Duration(days: 1));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExtend();
    });
  }

  Future<void> _pickNewCheckOut() async {
    final currentCout =
        DateTime.tryParse(
          AppFormatters.parseString(widget.booking['check_out_date']),
        ) ??
        DateTime.now();
    final first = currentCout.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _newCheckOut.isBefore(first) ? first : _newCheckOut,
      firstDate: first,
      lastDate: first.add(const Duration(days: 60)),
    );
    if (picked != null && mounted) {
      setState(() => _newCheckOut = picked);
      await _checkExtend();
    }
  }

  Future<void> _checkExtend() async {
    final kodeRoom =
        AppFormatters.parseString(widget.booking['kode_reservasi_room']);
    if (kodeRoom.isEmpty) return;

    setState(() {
      _isChecking = true;
      _error = null;
    });

    try {
      final res = await ref
          .read(reservationRepositoryProvider)
          .checkExtendStay(
            kodeReservasiRoom: kodeRoom,
            newCheckOutDate: AppFormatters.formatDateYmd(_newCheckOut),
          );
      if (mounted) {
        setState(() => _extendSim = res);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _submitExtend() async {
    if (_isSubmitting) return;
    final kodeRoom =
        AppFormatters.parseString(widget.booking['kode_reservasi_room']);

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final resp = await ref
          .read(reservationRepositoryProvider)
          .submitExtendStay({
            'kode_reservasi_room': kodeRoom,
            'new_check_out_date': AppFormatters.formatDateYmd(_newCheckOut),
          });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppFormatters.parseString(
              resp['message'],
              'Masa menginap berhasil diperpanjang!',
            ),
          ),
          backgroundColor: AppTheme.walkInGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final oldCout = AppFormatters.formatDateShortId(
      widget.booking['check_out_date'],
    );
    final extraNights =
        AppFormatters.parseInt(_extendSim?['additional_nights'], 1);
    final extraCost =
        AppFormatters.parseDouble(_extendSim?['additional_room_charge']);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.add_alarm_rounded,
                  color: AppTheme.bookingBlue,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Perpanjang Menginap (Extend Stay)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Check-Out Saat Ini: $oldCout',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickNewCheckOut,
              icon: const Icon(Icons.calendar_month_rounded),
              label: Text(
                'Check-Out Baru: ${AppFormatters.formatDateShortId(_newCheckOut)}',
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.dangerRed,
                    fontSize: 12,
                  ),
                ),
              ),
            if (_isChecking)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_extendSim != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _DetailLine(
                      label: 'Tambahan Malam',
                      value: '+$extraNights Malam',
                    ),
                    _DetailLine(
                      label: 'Tambahan Biaya Kamar',
                      value: AppFormatters.formatRupiah(extraCost),
                      bold: true,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: (_isChecking || _isSubmitting) ? null : _submitExtend,
              icon: const Icon(Icons.check_rounded),
              label: Text(
                _isSubmitting
                    ? 'Memproses...'
                    : 'Konfirmasi Perpanjang Menginap',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MathHelper {
  static int maxInt(int a, int b) => a > b ? a : b;
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: bold ? 14 : 12.5,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                color: bold ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
