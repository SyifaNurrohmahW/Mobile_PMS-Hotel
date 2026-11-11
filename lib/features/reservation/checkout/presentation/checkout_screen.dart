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

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _searchCtrl = TextEditingController();
  String _paymentFilter = 'all'; // 'all' | 'settled' | 'outstanding'
  String? _roomTypeFilter;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCandidates());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCandidates() async {
    final branchCode = ref.read(sessionProvider)?.activeBranchCode ?? '';
    if (branchCode.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await ref
          .read(reservationRepositoryProvider)
          .checkoutSearch(
            branchCode: branchCode,
            keyword: _searchCtrl.text.trim(),
          );
      if (!mounted) return;
      setState(() => _items = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _availableRoomTypes {
    final set = <String>{};
    for (final item in _items) {
      final t = AppFormatters.parseString(
        item['nama_tipe_kamar'] ?? item['nama_tipe'],
      );
      if (t.isNotEmpty) set.add(t);
    }
    return set.toList()..sort();
  }

  List<Map<String, dynamic>> get _filteredItems {
    return _items.where((item) {
      final balance = AppFormatters.parseDouble(item['balance']);
      if (_paymentFilter == 'settled' && balance > 0) return false;
      if (_paymentFilter == 'outstanding' && balance <= 0) return false;

      if (_roomTypeFilter != null && _roomTypeFilter!.isNotEmpty) {
        final t = AppFormatters.parseString(
          item['nama_tipe_kamar'] ?? item['nama_tipe'],
        );
        if (!t.contains(_roomTypeFilter!)) return false;
      }
      return true;
    }).toList();
  }

  void _openCheckoutSheet(Map<String, dynamic> item) {
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CheckoutSettlementSheet(
        initialItem: item,
        onRefreshRequested: _loadCandidates,
      ),
    ).then((invoiceResult) {
      if (invoiceResult != null) {
        _loadCandidates();
        ref.read(dashboardProvider.notifier).refresh();
        _showInvoiceSuccessDialog(invoiceResult);
      }
    });
  }

  void _showInvoiceSuccessDialog(Map<String, dynamic> data) {
    final invoiceNo = AppFormatters.parseString(data['invoice_number'], '-');
    final kodeFolio = AppFormatters.parseString(data['kode_folio'], '-');
    final roomsCount = AppFormatters.parseInt(data['checked_out_rooms'], 1);
    final grandTotal = AppFormatters.parseDouble(data['grand_total']);
    final totalPaid = AppFormatters.parseDouble(data['total_paid']);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.walkInGreenBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: AppTheme.walkInGreen,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Checkout & Invoice Selesai',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InvoiceRow(label: 'Nomor Invoice', value: invoiceNo, bold: true),
            _InvoiceRow(label: 'Kode Folio', value: kodeFolio),
            _InvoiceRow(label: 'Kamar Checkout', value: '$roomsCount Kamar'),
            const Divider(height: 18),
            _InvoiceRow(
              label: 'Grand Total',
              value: AppFormatters.formatRupiah(grandTotal),
              bold: true,
            ),
            _InvoiceRow(
              label: 'Total Lunas',
              value: AppFormatters.formatRupiah(totalPaid),
              valueColor: AppTheme.walkInGreen,
              bold: true,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Status kamar fisik otomatis diperbarui menjadi DIRTY dan siap dibersihkan oleh tim Housekeeping.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      final prevBranch = previous?.activeBranchCode;
      final nextBranch = next?.activeBranchCode;
      if (nextBranch != null && nextBranch != prevBranch) {
        _loadCandidates();
      }
    });

    final filtered = _filteredItems;
    final roomTypes = _availableRoomTypes;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCandidates,
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
                              color: AppTheme.checkoutOrangeBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.point_of_sale_rounded,
                              color: AppTheme.checkoutOrange,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Checkout, Inspeksi & Pelunasan',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${filtered.length} Folio In-House siap diproses checkout',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _loadCandidates,
                            tooltip: 'Muat Ulang',
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onSubmitted: (_) => _loadCandidates(),
                              decoration: InputDecoration(
                                hintText:
                                    'Cari No Kamar, Nama Tamu, atau Kode Folio...',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                ),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear_rounded,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          _loadCandidates();
                                        },
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: _loadCandidates,
                            icon: const Icon(Icons.search_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Semua'),
                              selected: _paymentFilter == 'all',
                              onSelected: (_) =>
                                  setState(() => _paymentFilter = 'all'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Lunas'),
                              selected: _paymentFilter == 'settled',
                              onSelected: (_) =>
                                  setState(() => _paymentFilter = 'settled'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Belum Lunas'),
                              selected: _paymentFilter == 'outstanding',
                              onSelected: (_) => setState(
                                () => _paymentFilter = 'outstanding',
                              ),
                            ),
                            if (roomTypes.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _roomTypeFilter,
                                  hint: const Text(
                                    'Tipe Kamar',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Semua Tipe'),
                                    ),
                                    ...roomTypes.map(
                                      (t) => DropdownMenuItem<String?>(
                                        value: t,
                                        child: Text(t),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _roomTypeFilter = v),
                                ),
                              ),
                            ],
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
                    onRetry: _loadCandidates,
                  ),
                )
              else if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: Icons.assignment_turned_in_rounded,
                    title: 'Tidak Ada Antrean Checkout',
                    subtitle:
                        'Belum ada kamar terisi yang cocok dengan pencarian atau filter.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _CheckoutCandidateCard(
                        item: item,
                        onTap: () => _openCheckoutSheet(item),
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

class _CheckoutCandidateCard extends StatelessWidget {
  const _CheckoutCandidateCard({
    required this.item,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nomorKamar = AppFormatters.parseString(item['nomor_kamar'], '-');
    final tipeKamar = AppFormatters.parseString(
      item['nama_tipe_kamar'] ?? item['nama_tipe'],
      'Standard Room',
    );
    final guestName = AppFormatters.parseString(item['guest_name'], 'Tamu');
    final guestPhone = AppFormatters.parseString(item['guest_phone'], '-');
    final kodeFolio = AppFormatters.parseString(item['kode_folio'], '-');
    final checkIn = AppFormatters.parseString(item['check_in_date']);
    final checkOut = AppFormatters.parseString(item['check_out_date']);
    final grandTotal = AppFormatters.parseDouble(item['grand_total']);
    final totalPaid = AppFormatters.parseDouble(item['total_paid']);
    final balance = AppFormatters.parseDouble(item['balance']);
    final inspectionStatus = AppFormatters.parseString(
      item['inspection_status'],
      'not_requested',
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.checkoutOrangeBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Kamar #$nomorKamar',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.checkoutOrange,
                            ),
                          ),
                        ),
                        StatusBadge.fromStatus(inspectionStatus, small: true),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  StatusBadge.fromStatus(
                    balance <= 0 ? 'settled' : 'outstanding',
                    small: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                guestName,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$tipeKamar  •  HP: $guestPhone  •  Folio: $kodeFolio',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Jadwal: ${AppFormatters.shortDate(checkIn)} → ${AppFormatters.shortDate(checkOut)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ColStat(
                        label: 'Grand Total',
                        value: AppFormatters.formatRupiah(grandTotal),
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _ColStat(
                        label: 'Terbayar',
                        value: AppFormatters.formatRupiah(totalPaid),
                        color: AppTheme.walkInGreen,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _ColStat(
                        label: 'Kurang Bayar',
                        value: AppFormatters.formatRupiah(balance),
                        color: balance > 0
                            ? AppTheme.dangerRed
                            : AppTheme.walkInGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.checkoutOrange,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 17),
                  label: const Text('Proses Checkout & Pelunasan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColStat extends StatelessWidget {
  const _ColStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// DUAL-PATH CHECKOUT & SETTLEMENT BOTTOM SHEET
// =============================================================================

class _CheckoutSettlementSheet extends ConsumerStatefulWidget {
  const _CheckoutSettlementSheet({
    required this.initialItem,
    required this.onRefreshRequested,
  });

  final Map<String, dynamic> initialItem;
  final Future<void> Function() onRefreshRequested;

  @override
  ConsumerState<_CheckoutSettlementSheet> createState() =>
      _CheckoutSettlementSheetState();
}

class _CheckoutSettlementSheetState
    extends ConsumerState<_CheckoutSettlementSheet> {
  late Map<String, dynamic> _item;
  final Set<String> _selectedResRooms = {};
  String _inspectionMode = 'with_inspection'; // 'with_inspection' | 'skipped'
  final _inspectionNotesCtrl = TextEditingController(
    text: 'Mohon cek kondisi fisik kamar & minibar sebelum tamu checkout.',
  );

  PaymentSelectionState _paymentState = PaymentSelectionState(
    paymentMethod: 'cash',
    referenceNo: AppFormatters.generatePaymentRefNo('OUT'),
  );

  bool _busyInspection = false;
  bool _submittingCheckout = false;
  String? _error;

  List<Map<String, dynamic>> get _roomsList {
    final raw = _item['rooms'];
    if (raw is List && raw.isNotEmpty) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [_item];
  }

  @override
  void initState() {
    super.initState();
    _item = Map<String, dynamic>.from(widget.initialItem);
    for (final r in _roomsList) {
      final code = AppFormatters.parseString(r['kode_reservasi_room']);
      if (code.isNotEmpty) _selectedResRooms.add(code);
    }
    final inspStatus = AppFormatters.parseString(_item['inspection_status']);
    if (inspStatus == 'not_requested') {
      _inspectionMode = 'skipped';
    }
  }

  @override
  void dispose() {
    _inspectionNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _reloadCurrentItem() async {
    final branchCode = ref.read(sessionProvider)?.activeBranchCode ?? '';
    final kodeFolio = AppFormatters.parseString(_item['kode_folio']);
    if (branchCode.isEmpty || kodeFolio.isEmpty) return;

    final list = await ref
        .read(reservationRepositoryProvider)
        .checkoutSearch(branchCode: branchCode, keyword: kodeFolio);
    final match = list.firstWhere(
      (e) => AppFormatters.parseString(e['kode_folio']) == kodeFolio,
      orElse: () => _item,
    );
    if (mounted) {
      setState(() => _item = match);
    }
  }

  Future<void> _requestInspection(Map<String, dynamic> room) async {
    final branchCode = ref.read(sessionProvider)?.activeBranchCode ?? '';
    final kodeKamar = AppFormatters.parseString(room['kode_kamar']);
    final kodeResRoom = AppFormatters.parseString(room['kode_reservasi_room']);

    setState(() {
      _busyInspection = true;
      _error = null;
    });

    try {
      await ref
          .read(reservationRepositoryProvider)
          .requestCheckoutInspection(
            kodeKamar: kodeKamar,
            kodeReservasiRoom: kodeResRoom,
            branchCode: branchCode,
            priority: 'urgent',
            notes: _inspectionNotesCtrl.text.trim(),
          );
      await _reloadCurrentItem();
      await widget.onRefreshRequested();
      if (!mounted) return;
      setState(() => _inspectionMode = 'with_inspection');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permintaan inspeksi kamar (Urgent) telah dikirim.'),
          backgroundColor: AppTheme.walkInGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busyInspection = false);
    }
  }

  Future<void> _cancelInspection(Map<String, dynamic> room) async {
    final taskCode = AppFormatters.parseString(room['inspection_task_code']);
    final kodeKamar = AppFormatters.parseString(room['kode_kamar']);

    setState(() {
      _busyInspection = true;
      _error = null;
    });

    try {
      await ref.read(reservationRepositoryProvider).cancelCheckoutInspection(
            kodeHousekeepingTask: taskCode.isNotEmpty ? taskCode : null,
            kodeKamar: kodeKamar,
          );
      await _reloadCurrentItem();
      await widget.onRefreshRequested();
      if (!mounted) return;
      setState(() => _inspectionMode = 'skipped');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inspeksi dibatalkan (Express Checkout Override).'),
          backgroundColor: AppTheme.checkoutOrange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busyInspection = false);
    }
  }

  Future<void> _submitCheckout() async {
    if (_selectedResRooms.isEmpty) {
      setState(() => _error = 'Pilih minimal 1 kamar yang akan di-checkout.');
      return;
    }

    final branchCode = ref.read(sessionProvider)?.activeBranchCode ?? '';
    final balance = AppFormatters.parseDouble(_item['balance']);
    final activeShift = ref.read(activeShiftProvider).value;

    if (balance > 0 &&
        _paymentState.paymentMethod == 'cash' &&
        (activeShift == null || !activeShift.hasActiveShift)) {
      setState(() {
        _error =
            'Sesi Shift Kasir wajib aktif untuk menerima pelunasan tunai (Cash).';
      });
      return;
    }

    setState(() {
      _submittingCheckout = true;
      _error = null;
    });

    try {
      final selectedList = _selectedResRooms.toList();
      final payload = <String, dynamic>{
        'kode_folio': AppFormatters.parseString(_item['kode_folio']),
        'kode_reservasi_rooms': selectedList,
        'kode_reservasi_room': selectedList.first,
        'kode_cabang': branchCode,
        'inspection_mode': _inspectionMode,
        if (activeShift?.kodeCashierShift != null)
          'kode_cashier_shift': activeShift!.kodeCashierShift,
        if (balance > 0)
          'payment': [
            {
              'payment_method': _paymentState.paymentMethod,
              if (_paymentState.bankName.isNotEmpty)
                'bank_name': _paymentState.bankName,
              if (_paymentState.cardType.isNotEmpty)
                'card_type': _paymentState.cardType,
              'amount': balance,
              if (activeShift?.kodeCashierShift != null)
                'kode_cashier_shift': activeShift!.kodeCashierShift,
              if (_paymentState.referenceNo.isNotEmpty)
                'reference_no': _paymentState.referenceNo,
            },
          ],
      };

      final result =
          await ref.read(reservationRepositoryProvider).checkout(payload);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submittingCheckout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _roomsList;
    final balance = AppFormatters.parseDouble(_item['balance']);
    final grandTotal = AppFormatters.parseDouble(_item['grand_total']);
    final totalPaid = AppFormatters.parseDouble(_item['total_paid']);
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
                const Icon(
                  Icons.point_of_sale_rounded,
                  color: AppTheme.checkoutOrange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Checkout & Settlement (${_item['kode_folio'] ?? '-'})',
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
              'Tamu: ${_item['guest_name'] ?? '-'} • Kamar #${_item['nomor_kamar'] ?? '-'}',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const Divider(height: 22),
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
            // JALUR 1: INSPEKSI HOUSEKEEPING
            const Text(
              'Jalur 1 — Inspeksi Fisik Kamar (Housekeeping)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...rooms.map((r) {
              final noKamar = AppFormatters.parseString(r['nomor_kamar'], '-');
              final inspStatus = AppFormatters.parseString(
                r['inspection_status'],
                'not_requested',
              );
              final isInProgress = inspStatus == 'in_progress';

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
                        Text(
                          'Kamar #$noKamar',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge.fromStatus(inspStatus),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (inspStatus == 'not_requested')
                          FilledButton.tonalIcon(
                            onPressed: _busyInspection
                                ? null
                                : () => _requestInspection(r),
                            icon: const Icon(
                              Icons.fact_check_outlined,
                              size: 16,
                            ),
                            label: const Text('Minta Cek Kamar (Urgent)'),
                          ),
                        if (isInProgress)
                          OutlinedButton.icon(
                            onPressed: _busyInspection
                                ? null
                                : () => _cancelInspection(r),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.checkoutOrange,
                            ),
                            icon: const Icon(Icons.bolt_rounded, size: 16),
                            label: const Text(
                              'Batalkan Inspeksi (Express Override)',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'with_inspection',
                  label: Text('Dengan Inspeksi'),
                  icon: Icon(Icons.verified_user_outlined, size: 16),
                ),
                ButtonSegment(
                  value: 'skipped',
                  label: Text('Express Checkout (Lewati)'),
                  icon: Icon(Icons.flash_on_rounded, size: 16),
                ),
              ],
              selected: {_inspectionMode},
              onSelectionChanged: (s) =>
                  setState(() => _inspectionMode = s.first),
            ),
            const Divider(height: 24),
            // JALUR 2: PILIH KAMAR & PELUNASAN TAGIHAN
            const Text(
              'Jalur 2 — Pilih Kamar & Pelunasan Tagihan (Settlement)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (rooms.length > 1)
              ...rooms.map((r) {
                final resRoomCode =
                    AppFormatters.parseString(r['kode_reservasi_room']);
                final noKamar =
                    AppFormatters.parseString(r['nomor_kamar'], '-');
                final tipe =
                    AppFormatters.parseString(r['nama_tipe_kamar'], 'Kamar');
                final checked = _selectedResRooms.contains(resRoomCode);

                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: checked,
                  title: Text(
                    'Kamar #$noKamar — $tipe ($resRoomCode)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedResRooms.add(resRoomCode);
                      } else {
                        _selectedResRooms.remove(resRoomCode);
                      }
                    });
                  },
                );
              }),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _InvoiceRow(
                    label: 'Grand Total Tagihan',
                    value: AppFormatters.formatRupiah(grandTotal),
                  ),
                  _InvoiceRow(
                    label: 'Deposit & Pembayaran Masuk',
                    value: AppFormatters.formatRupiah(totalPaid),
                    valueColor: AppTheme.walkInGreen,
                  ),
                  const Divider(height: 14),
                  _InvoiceRow(
                    label: 'Sisa Tagihan (Harus Dilunasi)',
                    value: AppFormatters.formatRupiah(balance),
                    bold: true,
                    valueColor: balance > 0
                        ? AppTheme.dangerRed
                        : AppTheme.walkInGreen,
                  ),
                ],
              ),
            ),
            if (balance > 0) ...[
              const SizedBox(height: 14),
              PaymentMethodSelector(
                title:
                    'Metode Pelunasan (${AppFormatters.formatRupiah(balance)})',
                state: _paymentState,
                onChanged: (next) => setState(() => _paymentState = next),
              ),
              if (_paymentState.paymentMethod == 'cash' &&
                  (activeShift == null || !activeShift.hasActiveShift)) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => CashierShiftSheet.show(context),
                  icon: const Icon(Icons.point_of_sale_rounded),
                  label: const Text('Buka Shift Kasir Terlebih Dahulu'),
                ),
              ],
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submittingCheckout ? null : _submitCheckout,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.checkoutOrange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _submittingCheckout
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.receipt_long_rounded),
                label: Text(
                  _submittingCheckout
                      ? 'Memproses Checkout & Invoice...'
                      : (balance > 0
                          ? 'Lunasi ${AppFormatters.formatRupiah(balance)} & Checkout'
                          : 'Konfirmasi Checkout & Terbitkan Invoice'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
