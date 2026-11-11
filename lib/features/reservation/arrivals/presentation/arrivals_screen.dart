import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/front_office_header_bar.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/session_notifier.dart';
import '../../../cashier_shift/presentation/active_shift_notifier.dart';
import '../../../cashier_shift/presentation/cashier_shift_sheet.dart';
import '../../../dashboard/presentation/dashboard_notifier.dart';
import '../../data/reservation_repository.dart';

class ReservationGroup {
  ReservationGroup({
    required this.kodeReservasi,
    required this.guestName,
    required this.guestPhone,
    required this.checkInDate,
    required this.checkOutDate,
    required this.reservationStatus,
    required this.depositAmount,
    required this.folioGrandTotal,
    required this.folioTotalPaid,
    required this.waktuCheckin,
    required this.rooms,
  });

  final String kodeReservasi;
  final String guestName;
  final String guestPhone;
  final String checkInDate;
  final String checkOutDate;
  final String reservationStatus;
  final double depositAmount;
  final double folioGrandTotal;
  final double folioTotalPaid;
  final String waktuCheckin;
  final List<Map<String, dynamic>> rooms;
}

class ArrivalsScreen extends ConsumerStatefulWidget {
  const ArrivalsScreen({super.key});

  @override
  ConsumerState<ArrivalsScreen> createState() => _ArrivalsScreenState();
}

class _ArrivalsScreenState extends ConsumerState<ArrivalsScreen> {
  final _searchCtrl = TextEditingController();
  String _dateFilterMode = 'today'; // 'today' | 'tomorrow' | 'custom' | 'all'
  DateTime _selectedDate = DateTime.now();

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rawItems = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadArrivals());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String? get _effectiveCheckInDate {
    final now = DateTime.now();
    switch (_dateFilterMode) {
      case 'today':
        return AppFormatters.apiDate(now);
      case 'tomorrow':
        return AppFormatters.apiDate(now.add(const Duration(days: 1)));
      case 'custom':
        return AppFormatters.apiDate(_selectedDate);
      case 'all':
      default:
        return null;
    }
  }

  Future<void> _loadArrivals() async {
    final branchCode = ref.read(sessionProvider)?.activeBranchCode ?? '';
    if (branchCode.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await ref.read(reservationRepositoryProvider).arrivals(
            branchCode: branchCode,
            checkInDate: _effectiveCheckInDate,
          );
      if (!mounted) return;
      setState(() => _rawItems = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  List<ReservationGroup> get _groupedReservations {
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _rawItems.where((row) {
      if (query.isEmpty) return true;
      final kodeRes =
          AppFormatters.parseString(row['kode_reservasi']).toLowerCase();
      final guest = AppFormatters.parseString(row['guest_name']).toLowerCase();
      final phone = AppFormatters.parseString(row['guest_phone']).toLowerCase();
      final roomNo =
          AppFormatters.parseString(row['nomor_kamar']).toLowerCase();
      return kodeRes.contains(query) ||
          guest.contains(query) ||
          phone.contains(query) ||
          roomNo.contains(query);
    }).toList();

    final map = <String, List<Map<String, dynamic>>>{};
    for (final row in filtered) {
      final key = AppFormatters.parseString(row['kode_reservasi'], 'RES');
      map.putIfAbsent(key, () => []).add(row);
    }

    return map.entries.map((entry) {
      final first = entry.value.first;
      return ReservationGroup(
        kodeReservasi: entry.key,
        guestName: AppFormatters.parseString(first['guest_name'], 'Tamu'),
        guestPhone: AppFormatters.parseString(first['guest_phone'], '-'),
        checkInDate: AppFormatters.parseString(first['check_in_date']),
        checkOutDate: AppFormatters.parseString(first['check_out_date']),
        reservationStatus:
            AppFormatters.parseString(first['reservation_status'], 'confirmed'),
        depositAmount: AppFormatters.parseDouble(first['deposit_amount']),
        folioGrandTotal: AppFormatters.parseDouble(first['folio_grand_total']),
        folioTotalPaid: AppFormatters.parseDouble(first['folio_total_paid']),
        waktuCheckin:
            AppFormatters.parseString(first['waktu_checkin'], '14:00:00'),
        rooms: entry.value,
      );
    }).toList();
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateFilterMode = 'custom';
      });
      await _loadArrivals();
    }
  }

  void _openCheckInSheet({
    required ReservationGroup group,
    Map<String, dynamic>? singleRoom,
  }) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CheckInBottomSheet(
        group: group,
        singleRoom: singleRoom,
      ),
    ).then((updated) {
      if (updated == true) {
        _loadArrivals();
        ref.read(dashboardProvider.notifier).refresh();
      }
    });
  }

  void _openRescheduleSheet(ReservationGroup group) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RescheduleBottomSheet(group: group),
    ).then((updated) {
      if (updated == true) {
        _loadArrivals();
        ref.read(dashboardProvider.notifier).refresh();
      }
    });
  }

  void _openCancelSheet({
    required ReservationGroup group,
    Map<String, dynamic>? singleRoom,
  }) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CancelBottomSheet(
        group: group,
        singleRoom: singleRoom,
      ),
    ).then((updated) {
      if (updated == true) {
        _loadArrivals();
        ref.read(dashboardProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      final prevBranch = previous?.activeBranchCode;
      final nextBranch = next?.activeBranchCode;
      if (nextBranch != null && nextBranch != prevBranch) {
        _loadArrivals();
      }
    });

    final groups = _groupedReservations;
    final totalRoomsCount =
        groups.fold<int>(0, (sum, g) => sum + g.rooms.length);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadArrivals,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(
                child: FrontOfficeHeaderBar(compact: true),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.arrivalsTealBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.flight_land_rounded,
                              color: AppTheme.arrivalsTeal,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Kedatangan & Check-In Tamu',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${groups.length} Reservasi ($totalRoomsCount Kamar) siap diproses',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _loadArrivals,
                            tooltip: 'Muat Ulang',
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText:
                              'Cari Kode Reservasi, Nama Tamu, HP, No Kamar...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Hari Ini'),
                              selected: _dateFilterMode == 'today',
                              onSelected: (_) {
                                setState(() => _dateFilterMode = 'today');
                                _loadArrivals();
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Besok'),
                              selected: _dateFilterMode == 'tomorrow',
                              onSelected: (_) {
                                setState(() => _dateFilterMode = 'tomorrow');
                                _loadArrivals();
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text(
                                _dateFilterMode == 'custom'
                                    ? 'Tgl: ${AppFormatters.shortDate(_selectedDate)}'
                                    : 'Pilih Tanggal',
                              ),
                              selected: _dateFilterMode == 'custom',
                              onSelected: (_) => _pickCustomDate(),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Semua Jadwal'),
                              selected: _dateFilterMode == 'all',
                              onSelected: (_) {
                                setState(() => _dateFilterMode = 'all');
                                _loadArrivals();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppErrorState(
                    message: _error!,
                    onRetry: _loadArrivals,
                  ),
                )
              else if (groups.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: Icons.event_available_rounded,
                    title: 'Tidak Ada Jadwal Kedatangan',
                    subtitle:
                        'Belum ada reservasi berstatus Reserved/Confirmed pada filter tanggal ini.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return _ReservationGroupCard(
                        group: group,
                        onCheckInRoom: (room) => _openCheckInSheet(
                          group: group,
                          singleRoom: room,
                        ),
                        onCheckInAll: () => _openCheckInSheet(group: group),
                        onReschedule: () => _openRescheduleSheet(group),
                        onCancelReservation: () =>
                            _openCancelSheet(group: group),
                        onCancelRoom: (room) => _openCancelSheet(
                          group: group,
                          singleRoom: room,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservationGroupCard extends StatelessWidget {
  const _ReservationGroupCard({
    required this.group,
    required this.onCheckInRoom,
    required this.onCheckInAll,
    required this.onReschedule,
    required this.onCancelReservation,
    required this.onCancelRoom,
  });

  final ReservationGroup group;
  final ValueChanged<Map<String, dynamic>> onCheckInRoom;
  final VoidCallback onCheckInAll;
  final VoidCallback onReschedule;
  final VoidCallback onCancelReservation;
  final ValueChanged<Map<String, dynamic>> onCancelRoom;

  @override
  Widget build(BuildContext context) {
    final nights = AppFormatters.calculateNights(
      DateTime.tryParse(group.checkInDate) ?? DateTime.now(),
      DateTime.tryParse(group.checkOutDate) ??
          DateTime.now().add(const Duration(days: 1)),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.fromLTRB(14, 10, 12, 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.arrivalsTealBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      group.kodeReservasi,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.arrivalsTeal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  StatusBadge.fromStatus(group.reservationStatus, small: true),
                ],
              ),
              Text(
                '${group.rooms.length} Kamar • $nights Mlm',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.guestName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'HP: ${group.guestPhone}  •  Check-In: ${AppFormatters.shortDate(group.checkInDate)} → ${AppFormatters.shortDate(group.checkOutDate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Total Folio: ${AppFormatters.formatRupiah(group.folioGrandTotal)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      'Deposit Masuk: ${AppFormatters.formatRupiah(group.depositAmount)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.walkInGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          children: [
            const Divider(height: 16),
            ...group.rooms.map((room) {
              final kodeResRoom =
                  AppFormatters.parseString(room['kode_reservasi_room']);
              final nomorKamar = AppFormatters.parseString(room['nomor_kamar']);
              final tipeKamar =
                  AppFormatters.parseString(room['nama_tipe_kamar'], 'Kamar');
              final ratePlan =
                  AppFormatters.parseString(room['nama_rate_plan'], 'Standard');
              final subtotal =
                  AppFormatters.parseDouble(room['subtotal_kamar']);
              final hasAssignedRoom = nomorKamar.isNotEmpty;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: hasAssignedRoom
                                ? AppTheme.bookingBlueBg
                                : AppTheme.checkoutOrangeBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            hasAssignedRoom
                                ? 'Kamar #$nomorKamar'
                                : 'Belum Alokasi Kamar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: hasAssignedRoom
                                  ? AppTheme.bookingBlue
                                  : AppTheme.checkoutOrange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$tipeKamar ($ratePlan)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          AppFormatters.formatRupiah(subtotal),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'ID: $kodeResRoom',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (group.rooms.length > 1)
                              TextButton.icon(
                                onPressed: () => onCancelRoom(room),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.dangerRed,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  size: 15,
                                ),
                                label: const Text(
                                  'Batal',
                                  style: TextStyle(fontSize: 11.5),
                                ),
                              ),
                            const SizedBox(width: 4),
                            FilledButton.tonalIcon(
                              onPressed: () => onCheckInRoom(room),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.arrivalsTealBg,
                                foregroundColor: AppTheme.arrivalsTeal,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                              ),
                              icon: const Icon(Icons.login_rounded, size: 15),
                              label: const Text(
                                'Check-In',
                                style: TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: onReschedule,
                  icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                  label: const Text('Reschedule'),
                ),
                OutlinedButton.icon(
                  onPressed: onCancelReservation,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.dangerRed,
                  ),
                  icon: const Icon(Icons.cancel_rounded, size: 16),
                  label: const Text('Batal Reservasi'),
                ),
                if (group.rooms.length > 1)
                  FilledButton.icon(
                    onPressed: onCheckInAll,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.arrivalsTeal,
                    ),
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: Text('Check-In Semua (${group.rooms.length})'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 1. CHECK-IN MODAL BOTTOM SHEET
// =============================================================================

class _CheckInBottomSheet extends ConsumerStatefulWidget {
  const _CheckInBottomSheet({
    required this.group,
    this.singleRoom,
  });

  final ReservationGroup group;
  final Map<String, dynamic>? singleRoom;

  @override
  ConsumerState<_CheckInBottomSheet> createState() =>
      _CheckInBottomSheetState();
}

class _CheckInBottomSheetState extends ConsumerState<_CheckInBottomSheet> {
  final Map<String, String> _selectedPhysicalRooms = {};
  final Map<String, List<Map<String, dynamic>>> _availableRoomsByResRoom = {};
  bool _loadingRooms = false;

  bool _isEarlyCheckIn = false;
  bool _applyEarlyFee = false;
  final _earlyFeeCtrl = TextEditingController(text: '150000');

  bool _addDeposit = false;
  final _depositCtrl = TextEditingController(text: '0');
  PaymentSelectionState _paymentState = PaymentSelectionState(
    paymentMethod: 'cash',
    referenceNo: AppFormatters.generatePaymentRefNo('DP'),
  );

  bool _submitting = false;
  String? _error;

  List<Map<String, dynamic>> get _targetRooms =>
      widget.singleRoom != null ? [widget.singleRoom!] : widget.group.rooms;

  @override
  void initState() {
    super.initState();
    _detectEarlyCheckIn();
    for (final room in _targetRooms) {
      final resRoomCode =
          AppFormatters.parseString(room['kode_reservasi_room']);
      final currentRoomCode = AppFormatters.parseString(room['kode_kamar']);
      if (currentRoomCode.isNotEmpty) {
        _selectedPhysicalRooms[resRoomCode] = currentRoomCode;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAvailableRooms());
  }

  @override
  void dispose() {
    _earlyFeeCtrl.dispose();
    _depositCtrl.dispose();
    super.dispose();
  }

  void _detectEarlyCheckIn() {
    final now = DateTime.now();
    final todayStr = AppFormatters.apiDate(now);
    final checkInDateStr = widget.group.checkInDate.length >= 10
        ? widget.group.checkInDate.substring(0, 10)
        : widget.group.checkInDate;

    if (todayStr == checkInDateStr) {
      final parts = widget.group.waktuCheckin.split(':');
      final stdHour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 14) : 14;
      final stdMinute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      if (now.hour < stdHour ||
          (now.hour == stdHour && now.minute < stdMinute)) {
        _isEarlyCheckIn = true;
      }
    }
  }

  Future<void> _loadAvailableRooms() async {
    final branchCode = ref.read(sessionProvider)?.activeBranchCode ?? '';
    if (branchCode.isEmpty) return;

    setState(() => _loadingRooms = true);
    try {
      for (final room in _targetRooms) {
        final resRoomCode =
            AppFormatters.parseString(room['kode_reservasi_room']);
        final roomTypeCode =
            AppFormatters.parseString(room['kode_tipe_kamar']);
        final ratePlanCode =
            AppFormatters.parseString(room['kode_rate_plan']);
        final checkIn = AppFormatters.parseString(
          room['check_in_date'],
          widget.group.checkInDate,
        );
        final checkOut = AppFormatters.parseString(
          room['check_out_date'],
          widget.group.checkOutDate,
        );

        final available = await ref
            .read(reservationRepositoryProvider)
            .checkAvailablePhysicalRooms(
              branchCode: branchCode,
              roomTypeCode: roomTypeCode,
              ratePlanCode: ratePlanCode,
              checkInDate:
                  checkIn.length >= 10 ? checkIn.substring(0, 10) : checkIn,
              checkOutDate:
                  checkOut.length >= 10 ? checkOut.substring(0, 10) : checkOut,
            );
        _availableRoomsByResRoom[resRoomCode] = available;
        if ((_selectedPhysicalRooms[resRoomCode] ?? '').isEmpty &&
            available.isNotEmpty) {
          _selectedPhysicalRooms[resRoomCode] =
              AppFormatters.parseString(available.first['kode_kamar']);
        }
      }
    } catch (_) {
      // Ignore individual availability lookup errors
    } finally {
      if (mounted) setState(() => _loadingRooms = false);
    }
  }

  Future<void> _submitCheckIn() async {
    for (final room in _targetRooms) {
      final resRoomCode =
          AppFormatters.parseString(room['kode_reservasi_room']);
      final selectedKamar = _selectedPhysicalRooms[resRoomCode] ?? '';
      if (selectedKamar.isEmpty) {
        setState(() {
          _error =
              'Pilih nomor kamar fisik terlebih dahulu untuk kamar $resRoomCode.';
        });
        return;
      }
    }

    final depositAmount =
        _addDeposit ? AppFormatters.parseDouble(_depositCtrl.text) : 0.0;
    final earlyFeeAmount =
        (_isEarlyCheckIn && _applyEarlyFee)
            ? AppFormatters.parseDouble(_earlyFeeCtrl.text)
            : 0.0;
    final needsShift = depositAmount > 0 || earlyFeeAmount > 0;

    final activeShift = ref.read(activeShiftProvider).value;
    if (needsShift && (activeShift == null || !activeShift.hasActiveShift)) {
      setState(() {
        _error =
            'Sesi Shift Kasir wajib dibuka untuk memproses deposit atau biaya Early Check-In.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      for (int i = 0; i < _targetRooms.length; i++) {
        final room = _targetRooms[i];
        final resRoomCode =
            AppFormatters.parseString(room['kode_reservasi_room']);
        final selectedKamar = _selectedPhysicalRooms[resRoomCode]!;

        // Only attach deposit to the first room in a batch check-in so it isn't duplicated
        final roomDeposit = i == 0 ? depositAmount : 0.0;

        final payload = <String, dynamic>{
          'kode_reservasi_room': resRoomCode,
          'kode_kamar': selectedKamar,
          'is_early_checkin': _isEarlyCheckIn,
          'apply_early_checkin_fee': _isEarlyCheckIn && _applyEarlyFee,
          'early_checkin_amount': earlyFeeAmount,
          'early_checkin_fee_amount': earlyFeeAmount,
          'deposit_amount': roomDeposit,
          if (roomDeposit > 0) ...{
            'payment_method': _paymentState.paymentMethod,
            if (_paymentState.bankName.isNotEmpty)
              'bank_name': _paymentState.bankName,
            if (_paymentState.referenceNo.isNotEmpty)
              'reference_no': _paymentState.referenceNo,
          },
          if (activeShift?.kodeCashierShift != null)
            'kode_cashier_shift': activeShift!.kodeCashierShift,
        };

        await ref.read(reservationRepositoryProvider).submitCheckIn(payload);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Check-In berhasil diproses (${_targetRooms.length} kamar).',
          ),
          backgroundColor: AppTheme.walkInGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeShift = ref.watch(activeShiftProvider).value;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.login_rounded, color: AppTheme.arrivalsTeal),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Konfirmasi Check-In (${widget.group.kodeReservasi})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              'Tamu: ${widget.group.guestName} (${widget.group.guestPhone})',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const Divider(height: 24),
            if (_error != null) ...[
              Container(
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
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.dangerRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              '1. Alokasi Kamar Fisik Ready',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_loadingRooms)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ..._targetRooms.map((room) {
                final resRoomCode =
                    AppFormatters.parseString(room['kode_reservasi_room']);
                final currentKamar =
                    AppFormatters.parseString(room['kode_kamar']);
                final currentNomor =
                    AppFormatters.parseString(room['nomor_kamar']);
                final tipeName =
                    AppFormatters.parseString(room['nama_tipe_kamar']);
                final availableList =
                    _availableRoomsByResRoom[resRoomCode] ?? const [];

                final options = <Map<String, String>>[];
                if (currentKamar.isNotEmpty) {
                  options.add({
                    'kode_kamar': currentKamar,
                    'label':
                        'Kamar #${currentNomor.isNotEmpty ? currentNomor : currentKamar} (Terpilih)',
                  });
                }
                for (final item in availableList) {
                  final code = AppFormatters.parseString(item['kode_kamar']);
                  final no = AppFormatters.parseString(item['nomor_kamar']);
                  final lantai = AppFormatters.parseString(item['lantai'], '-');
                  if (code.isNotEmpty &&
                      !options.any((o) => o['kode_kamar'] == code)) {
                    options.add({
                      'kode_kamar': code,
                      'label': 'Kamar #$no (Lantai $lantai) - Ready',
                    });
                  }
                }

                final selectedVal = _selectedPhysicalRooms[resRoomCode];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<String>(
                    initialValue: options.any(
                            (o) => o['kode_kamar'] == selectedVal)
                        ? selectedVal
                        : null,
                    decoration: InputDecoration(
                      labelText: '$tipeName ($resRoomCode)',
                    ),
                    items: options
                        .map(
                          (o) => DropdownMenuItem<String>(
                            value: o['kode_kamar'],
                            child: Text(o['label']!),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedPhysicalRooms[resRoomCode] = val);
                      }
                    },
                  ),
                );
              }),
            const SizedBox(height: 8),
            // Early check-in section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isEarlyCheckIn
                    ? AppTheme.checkoutOrangeBg
                    : AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isEarlyCheckIn
                      ? AppTheme.checkoutOrange.withValues(alpha: 0.4)
                      : AppTheme.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Early Check-In (Sebelum Jam Standar)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Jam Check-In standar cabang: ${widget.group.waktuCheckin}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    value: _isEarlyCheckIn,
                    onChanged: (v) => setState(() => _isEarlyCheckIn = v),
                  ),
                  if (_isEarlyCheckIn) ...[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Kenakan Biaya Early Check-In ke Folio',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      value: _applyEarlyFee,
                      onChanged: (v) =>
                          setState(() => _applyEarlyFee = v ?? false),
                    ),
                    if (_applyEarlyFee)
                      TextField(
                        controller: _earlyFeeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Nominal Biaya Early Check-In (Rp)',
                          prefixText: 'Rp ',
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Additional deposit section
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Tambah Deposit / Pembayaran Saat Check-In',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Deposit saat ini: ${AppFormatters.formatRupiah(widget.group.depositAmount)}',
                style: const TextStyle(fontSize: 12),
              ),
              value: _addDeposit,
              onChanged: (v) => setState(() => _addDeposit = v),
            ),
            if (_addDeposit) ...[
              TextField(
                controller: _depositCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal Deposit Tambahan (Rp)',
                  prefixText: 'Rp ',
                ),
              ),
              const SizedBox(height: 12),
              PaymentMethodSelector(
                state: _paymentState,
                onChanged: (next) => setState(() => _paymentState = next),
              ),
            ],
            if ((_addDeposit || (_isEarlyCheckIn && _applyEarlyFee)) &&
                (activeShift == null || !activeShift.hasActiveShift)) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => CashierShiftSheet.show(context),
                icon: const Icon(Icons.point_of_sale_rounded),
                label: const Text('Buka Shift Kasir Terlebih Dahulu'),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submitCheckIn,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.arrivalsTeal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  _submitting
                      ? 'Memproses Check-In...'
                      : 'Konfirmasi Check-In Sekarang',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 2. RESCHEDULE MODAL BOTTOM SHEET
// =============================================================================

class _RescheduleBottomSheet extends ConsumerStatefulWidget {
  const _RescheduleBottomSheet({required this.group});

  final ReservationGroup group;

  @override
  ConsumerState<_RescheduleBottomSheet> createState() =>
      _RescheduleBottomSheetState();
}

class _RescheduleBottomSheetState
    extends ConsumerState<_RescheduleBottomSheet> {
  late DateTime _newCheckIn;
  late DateTime _newCheckOut;
  final _notesCtrl = TextEditingController();

  bool _checking = false;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _simulation;
  final Map<String, String> _replacementRooms = {};

  @override
  void initState() {
    super.initState();
    _newCheckIn =
        DateTime.tryParse(widget.group.checkInDate) ?? DateTime.now();
    _newCheckOut = DateTime.tryParse(widget.group.checkOutDate) ??
        _newCheckIn.add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _newCheckIn, end: _newCheckOut),
    );
    if (picked != null) {
      setState(() {
        _newCheckIn = picked.start;
        _newCheckOut = picked.end.isAfter(picked.start)
            ? picked.end
            : picked.start.add(const Duration(days: 1));
        _simulation = null;
      });
    }
  }

  Future<void> _runCheck() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final result =
          await ref.read(reservationRepositoryProvider).checkReschedule(
                kodeReservasi: widget.group.kodeReservasi,
                newCheckInDate: AppFormatters.apiDate(_newCheckIn),
                newCheckOutDate: AppFormatters.apiDate(_newCheckOut),
              );
      if (!mounted) return;
      setState(() => _simulation = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submitReschedule() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final assignments = _replacementRooms.entries
          .map((e) => {
                'kode_reservasi_room': e.key,
                'kode_kamar': e.value,
              })
          .toList();

      await ref.read(reservationRepositoryProvider).submitReschedule(
            kodeReservasi: widget.group.kodeReservasi,
            newCheckInDate: AppFormatters.apiDate(_newCheckIn),
            newCheckOutDate: AppFormatters.apiDate(_newCheckOut),
            notes: _notesCtrl.text.trim(),
            roomAssignments: assignments.isEmpty ? null : assignments,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jadwal reservasi berhasil diperbarui.'),
          backgroundColor: AppTheme.walkInGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sim = _simulation;
    final canReschedule =
        sim != null && AppFormatters.parseBool(sim['can_reschedule']);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.edit_calendar_rounded,
                  color: AppTheme.bookingBlue,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reschedule Reservasi (${widget.group.kodeReservasi})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(height: 20),
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
                    fontSize: 12,
                    color: AppTheme.dangerRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: _pickDates,
              icon: const Icon(Icons.date_range_rounded),
              label: Text(
                'Jadwal Baru: ${AppFormatters.shortDate(_newCheckIn)} → ${AppFormatters.shortDate(_newCheckOut)} (${AppFormatters.calculateNights(_newCheckIn, _newCheckOut)} Malam)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan Perubahan Jadwal (Opsional)',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _checking ? null : _runCheck,
                icon: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics_outlined),
                label: const Text('Cek Ketersediaan & Simulasi Selisih Harga'),
              ),
            ),
            if (sim != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hasil Simulasi (${sim['old_nights']} Malam → ${sim['new_nights']} Malam)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total Kamar Lama: ${AppFormatters.formatRupiah(sim['old_room_total'])}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Total Kamar Baru: ${AppFormatters.formatRupiah(sim['new_room_total'])}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Selisih Tarif: ${AppFormatters.formatRupiah(sim['diff_amount'])} (${AppFormatters.parseString(sim['status_diff']).toUpperCase()})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppFormatters.parseDouble(sim['diff_amount']) > 0
                            ? AppTheme.checkoutOrange
                            : AppTheme.walkInGreen,
                      ),
                    ),
                    if (sim['rooms'] is List) ...[
                      const Divider(height: 16),
                      ...(sim['rooms'] as List).whereType<Map>().map((r) {
                        final resRoomCode = AppFormatters.parseString(
                          r['kode_reservasi_room'],
                        );
                        final conflict =
                            AppFormatters.parseBool(r['room_conflict']);
                        final availableOpts = (r['available_options'] is List)
                            ? (r['available_options'] as List)
                                .whereType<Map>()
                                .toList()
                            : const <Map>[];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r['nama_tipe']} • ${conflict ? "Kamar Bentrok (Pilih Pengganti)" : "Tersedia"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: conflict
                                      ? AppTheme.dangerRed
                                      : AppTheme.walkInGreen,
                                ),
                              ),
                              if (conflict && availableOpts.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: DropdownButtonFormField<String>(
                                    initialValue:
                                        _replacementRooms[resRoomCode],
                                    decoration: const InputDecoration(
                                      labelText: 'Pilih Kamar Pengganti',
                                    ),
                                    items: availableOpts
                                        .map(
                                          (opt) => DropdownMenuItem<String>(
                                            value: AppFormatters.parseString(
                                              opt['kode_kamar'],
                                            ),
                                            child: Text(
                                              'Kamar #${opt['nomor_kamar']} (Lantai ${opt['lantai']})',
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(
                                          () => _replacementRooms[resRoomCode] =
                                              v,
                                        );
                                      }
                                    },
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (!canReschedule || _submitting)
                      ? null
                      : _submitReschedule,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(
                    _submitting
                        ? 'Menyimpan...'
                        : 'Simpan Perubahan Jadwal',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 3. CANCEL & REFUND MODAL BOTTOM SHEET
// =============================================================================

class _CancelBottomSheet extends ConsumerStatefulWidget {
  const _CancelBottomSheet({
    required this.group,
    this.singleRoom,
  });

  final ReservationGroup group;
  final Map<String, dynamic>? singleRoom;

  @override
  ConsumerState<_CancelBottomSheet> createState() => _CancelBottomSheetState();
}

class _CancelBottomSheetState extends ConsumerState<_CancelBottomSheet> {
  final _reasonCtrl = TextEditingController(
    text: 'Permintaan pembatalan dari tamu',
  );
  final _notesCtrl = TextEditingController();
  String _refundType = 'non_refundable'; // 'refund_deposit' | 'non_refundable'
  final _penaltyCtrl = TextEditingController(text: '0');
  PaymentSelectionState _paymentState = PaymentSelectionState(
    paymentMethod: 'cash',
    referenceNo: AppFormatters.generatePaymentRefNo('RF'),
  );

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _notesCtrl.dispose();
    _penaltyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitCancel() async {
    if (_reasonCtrl.text.trim().length < 3) {
      setState(() => _error = 'Alasan pembatalan wajib diisi (minimal 3 karakter).');
      return;
    }

    final activeShift = ref.read(activeShiftProvider).value;
    final penalty = AppFormatters.parseDouble(_penaltyCtrl.text);
    final isRefund = _refundType == 'refund_deposit' &&
        widget.group.depositAmount > penalty;

    if (isRefund && (activeShift == null || !activeShift.hasActiveShift)) {
      setState(() {
        _error =
            'Sesi Shift Kasir wajib aktif untuk memproses pengembalian (refund) deposit.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final payload = <String, dynamic>{
        'kode_reservasi': widget.group.kodeReservasi,
        if (widget.singleRoom != null)
          'kode_reservasi_room': AppFormatters.parseString(
            widget.singleRoom!['kode_reservasi_room'],
          ),
        'cancellation_reason': _reasonCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
        'refund_type': _refundType,
        'penalty_amount': penalty,
        if (_refundType == 'refund_deposit') ...{
          'payment_method': _paymentState.paymentMethod,
          if (_paymentState.bankName.isNotEmpty)
            'bank_name': _paymentState.bankName,
          if (_paymentState.referenceNo.isNotEmpty)
            'reference_no': _paymentState.referenceNo,
        },
        if (activeShift?.kodeCashierShift != null)
          'kode_cashier_shift': activeShift!.kodeCashierShift,
      };

      await ref
          .read(reservationRepositoryProvider)
          .submitCancelReservation(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembatalan reservasi berhasil diproses.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPartial = widget.singleRoom != null;
    final roomCode = isPartial
        ? AppFormatters.parseString(widget.singleRoom!['kode_reservasi_room'])
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel_rounded, color: AppTheme.dangerRed),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isPartial
                        ? 'Batalkan Kamar ($roomCode)'
                        : 'Batalkan Reservasi (${widget.group.kodeReservasi})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Divider(height: 20),
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
                    fontSize: 12,
                    color: AppTheme.dangerRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Alasan Pembatalan *',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan Tambahan (Opsional)',
              ),
            ),
            if (!isPartial && widget.group.depositAmount > 0) ...[
              const SizedBox(height: 14),
              Text(
                'Kebijakan Deposit (${AppFormatters.formatRupiah(widget.group.depositAmount)})',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'non_refundable',
                    label: Text('Hangus (Non-Refund)'),
                  ),
                  ButtonSegment(
                    value: 'refund_deposit',
                    label: Text('Refund Deposit'),
                  ),
                ],
                selected: {_refundType},
                onSelectionChanged: (s) =>
                    setState(() => _refundType = s.first),
              ),
              if (_refundType == 'refund_deposit') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _penaltyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Potongan Penalti Pembatalan (Rp)',
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 10),
                PaymentMethodSelector(
                  state: _paymentState,
                  onChanged: (next) => setState(() => _paymentState = next),
                ),
              ],
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submitCancel,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.dangerRed,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.delete_forever_rounded),
                label: Text(
                  _submitting
                      ? 'Memproses Pembatalan...'
                      : 'Konfirmasi Pembatalan',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
