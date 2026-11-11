import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_routes.dart';
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

class InHouseScreen extends ConsumerStatefulWidget {
  const InHouseScreen({super.key});

  @override
  ConsumerState<InHouseScreen> createState() => _InHouseScreenState();
}

class _InHouseScreenState extends ConsumerState<InHouseScreen> {
  final _searchCtrl = TextEditingController();
  String _billingFilter = 'all'; // 'all' | 'settled' | 'outstanding'
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInHouse());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInHouse() async {
    final branchCode = ref.read(sessionProvider)?.activeBranchCode ?? '';
    if (branchCode.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await ref.read(reservationRepositoryProvider).inHouse(
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

  List<Map<String, dynamic>> get _filteredItems {
    return _items.where((item) {
      if (_billingFilter == 'all') return true;
      final status =
          AppFormatters.parseString(item['billing_status']).toLowerCase();
      return status == _billingFilter;
    }).toList();
  }

  void _openFolioSheet(Map<String, dynamic> item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FolioDetailSheet(item: item),
    );
  }

  void _openAddFacilitySheet(Map<String, dynamic> item) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddFacilitySheet(item: item),
    ).then((updated) {
      if (updated == true) {
        _loadInHouse();
      }
    });
  }

  void _openExtendStaySheet(Map<String, dynamic> item) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ExtendStaySheet(item: item),
    ).then((updated) {
      if (updated == true) {
        _loadInHouse();
        ref.read(dashboardProvider.notifier).refresh();
      }
    });
  }

  void _openHousekeepingSheet(Map<String, dynamic> item) {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _HousekeepingRequestSheet(item: item),
    ).then((updated) {
      if (updated == true) {
        _loadInHouse();
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
        _loadInHouse();
      }
    });

    final totalOccupied = _items.fold<int>(
      0,
      (sum, e) => sum + AppFormatters.parseInt(e['total_rooms'], 1),
    );
    final settledCount = _items
        .where(
          (e) =>
              AppFormatters.parseString(e['billing_status']).toLowerCase() ==
              'settled',
        )
        .length;
    final outstandingCount = _items.length - settledCount;
    final totalReceivable = _items.fold<double>(
      0,
      (sum, e) => sum + AppFormatters.parseDouble(e['balance']),
    );

    final filtered = _filteredItems;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadInHouse,
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
                      // 4 Mini KPI Banner (Multi-device adaptive grid)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cols = constraints.maxWidth >= 640 ? 4 : 2;
                          final kpis = [
                            _MiniKpiCard(
                              label: 'Kamar Terisi',
                              value: '$totalOccupied Kamar',
                              color: AppTheme.inHouseIndigo,
                              bgColor: AppTheme.inHouseIndigoBg,
                              icon: Icons.hotel_rounded,
                            ),
                            _MiniKpiCard(
                              label: 'Tagihan Lunas',
                              value: '$settledCount Folio',
                              color: AppTheme.walkInGreen,
                              bgColor: AppTheme.walkInGreenBg,
                              icon: Icons.verified_rounded,
                            ),
                            _MiniKpiCard(
                              label: 'Ada Tagihan',
                              value: '$outstandingCount Folio',
                              color: AppTheme.dangerRed,
                              bgColor: AppTheme.dangerRedBg,
                              icon: Icons.warning_amber_rounded,
                            ),
                            _MiniKpiCard(
                              label: 'Total Piutang',
                              value:
                                  AppFormatters.formatRupiah(totalReceivable),
                              color: AppTheme.checkoutOrange,
                              bgColor: AppTheme.checkoutOrangeBg,
                              icon: Icons.account_balance_wallet_rounded,
                            ),
                          ];
                          return GridView.builder(
                            itemCount: kpis.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cols,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              mainAxisExtent: 66,
                            ),
                            itemBuilder: (_, idx) => kpis[idx],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onSubmitted: (_) => _loadInHouse(),
                              decoration: InputDecoration(
                                hintText:
                                    'Cari No Kamar, Nama Tamu, Kode Folio...',
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
                                          _loadInHouse();
                                        },
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: _loadInHouse,
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
                              label: Text('Semua (${_items.length})'),
                              selected: _billingFilter == 'all',
                              onSelected: (_) =>
                                  setState(() => _billingFilter = 'all'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text('Lunas ($settledCount)'),
                              selected: _billingFilter == 'settled',
                              onSelected: (_) =>
                                  setState(() => _billingFilter = 'settled'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text('Ada Tagihan ($outstandingCount)'),
                              selected: _billingFilter == 'outstanding',
                              onSelected: (_) => setState(
                                () => _billingFilter = 'outstanding',
                              ),
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
                    onRetry: _loadInHouse,
                  ),
                )
              else if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: Icons.hotel_class_outlined,
                    title: 'Tidak Ada Tamu Menginap',
                    subtitle:
                        'Belum ada kamar aktif (In-House) yang sesuai dengan filter.',
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
                      return _InHouseCard(
                        item: item,
                        onFolioDetail: () => _openFolioSheet(item),
                        onAddFacility: () => _openAddFacilitySheet(item),
                        onExtendStay: () => _openExtendStaySheet(item),
                        onRequestHk: () => _openHousekeepingSheet(item),
                        onCheckout: () => context.go(AppRoutes.checkout),
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

class _MiniKpiCard extends StatelessWidget {
  const _MiniKpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InHouseCard extends StatelessWidget {
  const _InHouseCard({
    required this.item,
    required this.onFolioDetail,
    required this.onAddFacility,
    required this.onExtendStay,
    required this.onRequestHk,
    required this.onCheckout,
  });

  final Map<String, dynamic> item;
  final VoidCallback onFolioDetail;
  final VoidCallback onAddFacility;
  final VoidCallback onExtendStay;
  final VoidCallback onRequestHk;
  final VoidCallback onCheckout;

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
    final nights = AppFormatters.parseInt(item['nights'], 1);
    final grandTotal = AppFormatters.parseDouble(item['grand_total']);
    final totalPaid = AppFormatters.parseDouble(item['total_paid']);
    final balance = AppFormatters.parseDouble(item['balance']);
    final billingStatus =
        AppFormatters.parseString(item['billing_status'], 'settled');
    final hkStatus =
        AppFormatters.parseString(item['housekeeping_status'], 'clean');
    final taskStatus = AppFormatters.parseString(item['task_status']);

    return Card(
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
                          color: AppTheme.inHouseIndigoBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Kamar #$nomorKamar',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.inHouseIndigo,
                          ),
                        ),
                      ),
                      StatusBadge.fromStatus(
                        taskStatus.isNotEmpty && taskStatus != 'completed'
                            ? taskStatus
                            : hkStatus,
                        small: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                StatusBadge.fromStatus(billingStatus, small: true),
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
              'Menginap: ${AppFormatters.shortDate(checkIn)} → ${AppFormatters.shortDate(checkOut)} ($nights Malam)',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
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
                    child: _AmountColumn(
                      label: 'Grand Total',
                      amount: grandTotal,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _AmountColumn(
                      label: 'Terbayar',
                      amount: totalPaid,
                      color: AppTheme.walkInGreen,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _AmountColumn(
                      label: 'Sisa Tagihan',
                      amount: balance,
                      color: balance > 0
                          ? AppTheme.dangerRed
                          : AppTheme.walkInGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.receipt_long_rounded, size: 15),
                  label: const Text(
                    'Rincian Folio',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  onPressed: onFolioDetail,
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.room_service_rounded, size: 15),
                  label: const Text(
                    '+ Fasilitas',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  onPressed: onAddFacility,
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.more_time_rounded, size: 15),
                  label: const Text(
                    'Extend Stay',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  onPressed: onExtendStay,
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(
                    Icons.cleaning_services_rounded,
                    size: 15,
                  ),
                  label: const Text(
                    'Request HK',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  onPressed: onRequestHk,
                ),
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppTheme.checkoutOrangeBg,
                  avatar: const Icon(
                    Icons.logout_rounded,
                    size: 15,
                    color: AppTheme.checkoutOrange,
                  ),
                  label: const Text(
                    'Checkout',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.checkoutOrange,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: onCheckout,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountColumn extends StatelessWidget {
  const _AmountColumn({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
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
          style: const TextStyle(
            fontSize: 10.5,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            AppFormatters.formatRupiah(amount),
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
// 1. FOLIO DETAIL BOTTOM SHEET
// =============================================================================

class _FolioDetailSheet extends ConsumerStatefulWidget {
  const _FolioDetailSheet({required this.item});

  final Map<String, dynamic> item;

  @override
  ConsumerState<_FolioDetailSheet> createState() => _FolioDetailSheetState();
}

class _FolioDetailSheetState extends ConsumerState<_FolioDetailSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _folioData;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await ref.read(reservationRepositoryProvider).fetchFolioDetail(
                kodeFolio: AppFormatters.parseString(widget.item['kode_folio']),
                kodeReservation: AppFormatters.parseString(
                  widget.item['kode_reservation'],
                ),
                kodeReservasiRoom: AppFormatters.parseString(
                  widget.item['kode_reservasi_room'],
                ),
              );
      if (!mounted) return;
      setState(() => _folioData = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final folio = _folioData?['folio'] is Map
        ? Map<String, dynamic>.from(_folioData!['folio'] as Map)
        : widget.item;
    final items = (_folioData?['items'] is List)
        ? (_folioData!['items'] as List).whereType<Map>().toList()
        : const <Map>[];
    final payments = (_folioData?['payments'] is List)
        ? (_folioData!['payments'] as List).whereType<Map>().toList()
        : const <Map>[];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: AppTheme.inHouseIndigo,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rincian Folio (${folio['kode_folio'] ?? '-'})',
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
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              AppErrorState(message: _error!, onRetry: _loadDetail)
            else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    _FolioRow(
                      label: 'Total Kamar',
                      value: AppFormatters.formatRupiah(folio['room_total']),
                    ),
                    _FolioRow(
                      label: 'Layanan & Fasilitas Tambahan',
                      value: AppFormatters.formatRupiah(folio['service_total']),
                    ),
                    _FolioRow(
                      label: 'Pajak & Service',
                      value: AppFormatters.formatRupiah(folio['tax_amount']),
                    ),
                    const Divider(height: 14),
                    _FolioRow(
                      label: 'Grand Total',
                      value: AppFormatters.formatRupiah(folio['grand_total']),
                      bold: true,
                    ),
                    _FolioRow(
                      label: 'Total Terbayar',
                      value: AppFormatters.formatRupiah(folio['total_paid']),
                      valueColor: AppTheme.walkInGreen,
                    ),
                    _FolioRow(
                      label: 'Sisa Tagihan (Balance)',
                      value: AppFormatters.formatRupiah(folio['balance']),
                      bold: true,
                      valueColor:
                          AppFormatters.parseDouble(folio['balance']) > 0
                              ? AppTheme.dangerRed
                              : AppTheme.walkInGreen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Daftar Transaksi / Komponen Tagihan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Text(
                  'Belum ada item tambahan.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                )
              else
                ...items.map((it) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      AppFormatters.parseString(it['description'], 'Item'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${it['charge_type']} • Qty ${it['qty']}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Text(
                      AppFormatters.formatRupiah(it['total_price']),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 12),
              const Text(
                'Riwayat Pembayaran Masuk',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (payments.isEmpty)
                const Text(
                  'Belum ada riwayat pembayaran.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                )
              else
                ...payments.map((pay) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${AppFormatters.parseString(pay['payment_type']).toUpperCase()} • ${AppFormatters.parseString(pay['payment_method']).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      'Ref: ${AppFormatters.parseString(pay['reference_no'], '-')} • ${AppFormatters.shortDateTime(pay['paid_at'])}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Text(
                      AppFormatters.formatRupiah(pay['amount']),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.walkInGreen,
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}

class _FolioRow extends StatelessWidget {
  const _FolioRow({
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

// =============================================================================
// 2. ADD FACILITY BOTTOM SHEET
// =============================================================================

class _AddFacilitySheet extends ConsumerStatefulWidget {
  const _AddFacilitySheet({required this.item});

  final Map<String, dynamic> item;

  @override
  ConsumerState<_AddFacilitySheet> createState() => _AddFacilitySheetState();
}

class _AddFacilitySheetState extends ConsumerState<_AddFacilitySheet> {
  List<ExtraFacilityCatalogItem> _catalog = const [];
  ExtraFacilityCatalogItem? _selectedCatalog;
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');
  final _qtyCtrl = TextEditingController(text: '1');
  String _chargeType = 'other';
  bool _isPaidNow = false;
  PaymentSelectionState _paymentState = PaymentSelectionState(
    paymentMethod: 'cash',
    referenceNo: AppFormatters.generatePaymentRefNo('ADD'),
  );
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final branchCode = ref.read(sessionProvider)?.activeBranchCode ?? '';
    if (branchCode.isEmpty) return;
    final items = await ref
        .read(reservationRepositoryProvider)
        .fetchExtraFacilitiesCatalog(branchCode: branchCode);
    if (!mounted) return;
    setState(() {
      _catalog = items;
      if (items.isNotEmpty) {
        _selectedCatalog = items.first;
        _descCtrl.text = items.first.nama;
        _priceCtrl.text = items.first.harga.toStringAsFixed(0);
        _chargeType = items.first.chargeType;
      }
    });
  }

  Future<void> _submit() async {
    final desc = _descCtrl.text.trim();
    final price = AppFormatters.parseDouble(_priceCtrl.text);
    final qty = AppFormatters.parseInt(_qtyCtrl.text, 1);

    if (desc.length < 3 || price <= 0 || qty <= 0) {
      setState(() {
        _error = 'Nama layanan, harga (> 0), dan qty wajib diisi dengan benar.';
      });
      return;
    }

    final activeShift = ref.read(activeShiftProvider).value;
    if (_isPaidNow && (activeShift == null || !activeShift.hasActiveShift)) {
      setState(() {
        _error = 'Sesi Shift Kasir wajib dibuka untuk pembayaran langsung.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final payload = <String, dynamic>{
        'kode_folio': AppFormatters.parseString(widget.item['kode_folio']),
        'kode_reservasi_room': AppFormatters.parseString(
          widget.item['kode_reservasi_room'],
        ),
        'charge_type': _chargeType,
        'description': desc,
        'qty': qty,
        'unit_price': price,
        'is_paid_now': _isPaidNow,
        if (_isPaidNow) ...{
          'payment_method': _paymentState.paymentMethod,
          if (_paymentState.bankName.isNotEmpty)
            'bank_name': _paymentState.bankName,
          if (_paymentState.cardType.isNotEmpty)
            'card_type': _paymentState.cardType,
          if (_paymentState.referenceNo.isNotEmpty)
            'reference_no': _paymentState.referenceNo,
          if (activeShift?.kodeCashierShift != null)
            'kode_cashier_shift': activeShift!.kodeCashierShift,
        },
      };

      await ref.read(reservationRepositoryProvider).addInHouseFacility(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fasilitas tambahan berhasil dicatat ke folio.'),
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
                const Icon(
                  Icons.room_service_rounded,
                  color: AppTheme.inHouseIndigo,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tambah Fasilitas / Layanan (Kamar #${widget.item['nomor_kamar']})',
                    style: const TextStyle(
                      fontSize: 16,
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
            if (_catalog.isNotEmpty) ...[
              DropdownButtonFormField<ExtraFacilityCatalogItem>(
                initialValue: _selectedCatalog,
                decoration: const InputDecoration(
                  labelText: 'Pilih dari Katalog Fasilitas & Amenity',
                ),
                items: _catalog
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          '${c.nama} (${AppFormatters.formatRupiah(c.harga)})',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCatalog = val;
                      _descCtrl.text = val.nama;
                      _priceCtrl.text = val.harga.toStringAsFixed(0);
                      _chargeType = val.chargeType;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Fasilitas / Layanan *',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga Satuan (Rp) *',
                      prefixText: 'Rp ',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Qty *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Bayar Langsung Sekarang (Lunas)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Matikan opsi ini jika ingin dimasukkan ke Tagihan Kamar (Charge to Room)',
                style: TextStyle(fontSize: 11),
              ),
              value: _isPaidNow,
              onChanged: (v) => setState(() => _isPaidNow = v),
            ),
            if (_isPaidNow) ...[
              PaymentMethodSelector(
                state: _paymentState,
                onChanged: (next) => setState(() => _paymentState = next),
              ),
              if (activeShift == null || !activeShift.hasActiveShift) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => CashierShiftSheet.show(context),
                  icon: const Icon(Icons.point_of_sale_rounded),
                  label: const Text('Buka Shift Kasir Terlebih Dahulu'),
                ),
              ],
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.add_task_rounded),
                label: Text(
                  _submitting ? 'Menyimpan...' : 'Simpan Fasilitas ke Folio',
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
// 3. EXTEND STAY BOTTOM SHEET
// =============================================================================

class _ExtendStaySheet extends ConsumerStatefulWidget {
  const _ExtendStaySheet({required this.item});

  final Map<String, dynamic> item;

  @override
  ConsumerState<_ExtendStaySheet> createState() => _ExtendStaySheetState();
}

class _ExtendStaySheetState extends ConsumerState<_ExtendStaySheet> {
  late DateTime _currentCheckout;
  late DateTime _newCheckout;
  bool _checking = false;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _checkResult;

  bool _payNow = false;
  PaymentSelectionState _paymentState = PaymentSelectionState(
    paymentMethod: 'cash',
    referenceNo: AppFormatters.generatePaymentRefNo('EXT'),
  );

  @override
  void initState() {
    super.initState();
    _currentCheckout =
        DateTime.tryParse(
          AppFormatters.parseString(widget.item['check_out_date']),
        ) ??
        DateTime.now();
    _newCheckout = _currentCheckout.add(const Duration(days: 1));
    WidgetsBinding.instance.addPostFrameCallback((_) => _runExtendCheck());
  }

  Future<void> _pickNewCheckout() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newCheckout,
      firstDate: _currentCheckout.add(const Duration(days: 1)),
      lastDate: _currentCheckout.add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _newCheckout = picked);
      await _runExtendCheck();
    }
  }

  Future<void> _runExtendCheck() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(reservationRepositoryProvider)
          .checkExtendStay(
            kodeReservasiRoom: AppFormatters.parseString(
              widget.item['kode_reservasi_room'],
            ),
            newCheckOutDate: AppFormatters.apiDate(_newCheckout),
          );
      if (!mounted) return;
      setState(() => _checkResult = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submitExtend() async {
    final activeShift = ref.read(activeShiftProvider).value;
    if (_payNow && (activeShift == null || !activeShift.hasActiveShift)) {
      setState(() {
        _error = 'Sesi Shift Kasir wajib dibuka untuk pembayaran langsung.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final addTotal =
          AppFormatters.parseDouble(_checkResult?['additional_grand_total']);
      final payload = <String, dynamic>{
        'kode_reservasi_room': AppFormatters.parseString(
          widget.item['kode_reservasi_room'],
        ),
        'new_check_out_date': AppFormatters.apiDate(_newCheckout),
        if (_payNow && addTotal > 0) ...{
          'payment_amount': addTotal,
          'payment_method': _paymentState.paymentMethod,
          if (_paymentState.bankName.isNotEmpty)
            'bank_name': _paymentState.bankName,
          if (_paymentState.cardType.isNotEmpty)
            'card_type': _paymentState.cardType,
          if (_paymentState.referenceNo.isNotEmpty)
            'reference_no': _paymentState.referenceNo,
          if (activeShift?.kodeCashierShift != null)
            'kode_cashier_shift': activeShift!.kodeCashierShift,
        },
      };

      await ref.read(reservationRepositoryProvider).submitExtendStay(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perpanjangan masa menginap (Extend Stay) berhasil!'),
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
    final res = _checkResult;
    final canExtend = res != null && AppFormatters.parseBool(res['can_extend']);

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
                  Icons.more_time_rounded,
                  color: AppTheme.inHouseIndigo,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Extend Stay (Kamar #${widget.item['nomor_kamar']})',
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
              onPressed: _pickNewCheckout,
              icon: const Icon(Icons.event_rounded),
              label: Text(
                'Checkout Baru: ${AppFormatters.shortDate(_newCheckout)}',
              ),
            ),
            const SizedBox(height: 12),
            if (_checking)
              const Center(child: CircularProgressIndicator())
            else if (res != null) ...[
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
                      'Tambahan Malam: +${res['additional_nights']} Malam',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Subtotal Kamar Tambahan: ${AppFormatters.formatRupiah(res['additional_subtotal'])}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Pajak Tambahan: ${AppFormatters.formatRupiah(res['additional_tax'])}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Divider(height: 14),
                    Text(
                      'Total Biaya Extend: ${AppFormatters.formatRupiah(res['additional_grand_total'])}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                    if (!canExtend)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Kamar telah dipesan tamu lain pada tanggal tersebut.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.dangerRed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Bayar Biaya Extend Sekarang',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                value: _payNow,
                onChanged: (v) => setState(() => _payNow = v),
              ),
              if (_payNow)
                PaymentMethodSelector(
                  state: _paymentState,
                  onChanged: (next) => setState(() => _paymentState = next),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (!canExtend || _submitting) ? null : _submitExtend,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text(
                    _submitting
                        ? 'Memproses Extend...'
                        : 'Konfirmasi Extend Stay',
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
// 4. HOUSEKEEPING REQUEST BOTTOM SHEET
// =============================================================================

class _HousekeepingRequestSheet extends ConsumerStatefulWidget {
  const _HousekeepingRequestSheet({required this.item});

  final Map<String, dynamic> item;

  @override
  ConsumerState<_HousekeepingRequestSheet> createState() =>
      _HousekeepingRequestSheetState();
}

class _HousekeepingRequestSheetState
    extends ConsumerState<_HousekeepingRequestSheet> {
  String _taskType = 'cleaning';
  String _priority = 'normal';
  final _notesCtrl = TextEditingController(
    text: 'Permintaan pembersihan kamar menginap (Make Up Room)',
  );
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final branchCode = ref.read(sessionProvider)?.activeBranchCode ?? '';
    final kodeKamar = AppFormatters.parseString(widget.item['kode_kamar']);
    if (kodeKamar.isEmpty) {
      setState(() => _error = 'Kode kamar fisik tidak ditemukan.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(reservationRepositoryProvider).requestHousekeepingTask(
            kodeKamar: kodeKamar,
            branchCode: branchCode,
            kodeReservasiRoom: AppFormatters.parseString(
              widget.item['kode_reservasi_room'],
            ),
            taskType: _taskType,
            priority: _priority,
            notes: _notesCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tugas Housekeeping berhasil dikirim ke staf HK.'),
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
                  Icons.cleaning_services_rounded,
                  color: AppTheme.inHouseIndigo,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Request Housekeeping (Kamar #${widget.item['nomor_kamar']})',
                    style: const TextStyle(
                      fontSize: 16,
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
            DropdownButtonFormField<String>(
              initialValue: _taskType,
              decoration: const InputDecoration(labelText: 'Jenis Tugas HK'),
              items: const [
                DropdownMenuItem(
                  value: 'cleaning',
                  child: Text('Stayover Cleaning / Make Up Room'),
                ),
                DropdownMenuItem(
                  value: 'inspection',
                  child: Text('Inspeksi Kondisi Kamar'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _taskType = v);
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Prioritas'),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'high', child: Text('Tinggi (High)')),
                DropdownMenuItem(
                  value: 'urgent',
                  child: Text('Mendesak (Urgent)'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _priority = v);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan untuk Petugas Housekeeping',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.send_rounded),
                label: Text(
                  _submitting ? 'Mengirim Tugas...' : 'Kirim Tugas Housekeeping',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
