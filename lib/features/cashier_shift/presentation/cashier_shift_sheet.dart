import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/session_notifier.dart';
import '../data/cashier_shift_repository.dart';
import '../domain/cashier_shift_models.dart';
import 'active_shift_notifier.dart';

class CashierShiftSheet extends ConsumerStatefulWidget {
  const CashierShiftSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CashierShiftSheet(),
    );
  }

  @override
  ConsumerState<CashierShiftSheet> createState() => _CashierShiftSheetState();
}

class _CashierShiftSheetState extends ConsumerState<CashierShiftSheet> {
  // Open shift state
  List<CashierCounter> _counters = [];
  List<MasterShiftOption> _shifts = [];
  CashierCounter? _selectedCounter;
  MasterShiftOption? _selectedShift;
  final _openingCashController = TextEditingController(text: '500000');

  // Detail & Close shift state
  CashierShiftDetail? _shiftDetail;
  bool _showCloseForm = false;
  final _closingCashController = TextEditingController();
  final _handoverNotesController = TextEditingController();

  bool _isLoadingInit = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _openingCashController.dispose();
    _closingCashController.dispose();
    _handoverNotesController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      _isLoadingInit = true;
      _errorMessage = null;
    });

    try {
      final currentShift =
          await ref.read(activeShiftProvider.notifier).refreshShift();
      final repo = ref.read(cashierShiftRepositoryProvider);
      final branchCode = ref.read(sessionProvider)?.activeKodeCabang ?? '';

      if (currentShift != null) {
        final detail =
            await repo.getShiftDetail(currentShift.kodeCashierShift);
        if (mounted) {
          setState(() {
            _shiftDetail = detail;
            _closingCashController.text =
                detail.summary.systemCash.round().toString();
          });
        }
      } else if (branchCode.isNotEmpty) {
        final results = await Future.wait([
          repo.getCounters(branchCode: branchCode),
          repo.getShiftDropdown(branchCode: branchCode),
        ]);
        final counters = results[0] as List<CashierCounter>;
        final shifts = results[1] as List<MasterShiftOption>;
        final availableCounters =
            counters.where((c) => !c.isInUse && c.isActive).toList();

        if (mounted) {
          setState(() {
            _counters = counters;
            _shifts = shifts;
            _selectedCounter = availableCounters.isNotEmpty
                ? availableCounters.first
                : (counters.isNotEmpty ? counters.first : null);
            _selectedShift = shifts.isNotEmpty ? shifts.first : null;
            if (_selectedShift != null &&
                _selectedShift!.defaultOpeningCash > 0) {
              _openingCashController.text =
                  _selectedShift!.defaultOpeningCash.round().toString();
            }
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingInit = false);
      }
    }
  }

  Future<void> _submitOpenShift() async {
    if (_isSubmitting) return;
    final branchCode = ref.read(sessionProvider)?.activeKodeCabang ?? '';
    final counter = _selectedCounter;
    if (branchCode.isEmpty) {
      setState(() => _errorMessage = 'Cabang aktif tidak ditemukan.');
      return;
    }
    if (counter == null) {
      setState(() => _errorMessage = 'Pilih loket kasir terlebih dahulu.');
      return;
    }
    if (counter.isInUse) {
      setState(
        () => _errorMessage =
            'Loket ${counter.name} sedang digunakan oleh ${counter.activeUser ?? 'kasir lain'}.',
      );
      return;
    }

    final openingCash = AppFormatters.parseDouble(_openingCashController.text);

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(activeShiftProvider.notifier).openShift(
            branchCode: branchCode,
            counterCode: counter.kodeCounter,
            openingCash: openingCash,
            sesi: _selectedShift?.kodeShift,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift kasir berhasil dibuka.'),
            backgroundColor: AppTheme.walkInGreen,
          ),
        );
        Navigator.pop(context, true);
      }
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

  Future<void> _submitCloseShift(CashierShift activeShift) async {
    if (_isSubmitting) return;
    final closingCash = AppFormatters.parseDouble(_closingCashController.text);

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(activeShiftProvider.notifier).closeShift(
            shiftCode: activeShift.kodeCashierShift,
            closingCash: closingCash,
            catatanHandover: _handoverNotesController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shift kasir berhasil ditutup.'),
            backgroundColor: AppTheme.walkInGreen,
          ),
        );
        Navigator.pop(context, true);
      }
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

  @override
  Widget build(BuildContext context) {
    final shiftAsync = ref.watch(activeShiftProvider);
    final activeShift = shiftAsync.value;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
        child: _isLoadingInit
            ? const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: activeShift == null
                    ? _buildOpenShiftForm()
                    : _buildActiveShiftView(activeShift),
              ),
      ),
    );
  }

  Widget _buildOpenShiftForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.walkInGreenBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                color: AppTheme.walkInGreen,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buka Shift Kasir Baru',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Wajib dibuka sebelum memproses transaksi pembayaran/deposit',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: _errorMessage!),
        ],
        const SizedBox(height: 18),
        DropdownButtonFormField<CashierCounter>(
          initialValue: _selectedCounter,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Pilih Loket / Counter Kasir',
            prefixIcon: Icon(Icons.storefront_outlined),
          ),
          items: _counters.map((counter) {
            final label = counter.isInUse
                ? '${counter.name} (${counter.statusKeterangan})'
                : '${counter.name} (Tersedia)';
            return DropdownMenuItem<CashierCounter>(
              value: counter,
              enabled: !counter.isInUse,
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: counter.isInUse
                      ? AppTheme.textSecondary
                      : AppTheme.textPrimary,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedCounter = value),
        ),
        const SizedBox(height: 14),
        if (_shifts.isNotEmpty) ...[
          DropdownButtonFormField<MasterShiftOption>(
            initialValue: _selectedShift,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Sesi Shift Operasional',
              prefixIcon: Icon(Icons.schedule_outlined),
            ),
            items: _shifts
                .map(
                  (s) => DropdownMenuItem<MasterShiftOption>(
                    value: s,
                    child: Text(s.timeRangeLabel),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedShift = value;
                if (value != null && value.defaultOpeningCash > 0) {
                  _openingCashController.text =
                      value.defaultOpeningCash.round().toString();
                }
              });
            },
          ),
          const SizedBox(height: 14),
        ],
        TextFormField(
          controller: _openingCashController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Saldo Kas Awal (Opening Balance Rp)',
            prefixIcon: Icon(Icons.payments_outlined),
            helperText: 'Uang tunai modal kembalian di laci kasir saat buka shift',
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [0, 300000, 500000, 1000000].map((preset) {
            return ActionChip(
              label: Text(AppFormatters.formatRupiah(preset)),
              onPressed: () {
                setState(() => _openingCashController.text = preset.toString());
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _isSubmitting ? null : _submitOpenShift,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.walkInGreen,
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock_open_rounded),
            label: Text(
              _isSubmitting ? 'Membuka Shift...' : 'Konfirmasi Buka Shift Kasir',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveShiftView(CashierShift activeShift) {
    final stats = _shiftDetail?.summary ?? activeShift.stats;
    final paySummary = _shiftDetail?.paymentSummary ?? const {};
    final systemCash = stats?.systemCash ?? activeShift.openingCash;
    final closingInput =
        AppFormatters.parseDouble(_closingCashController.text, systemCash);
    final diff = closingInput - systemCash;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.walkInGreenBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.point_of_sale_rounded,
                color: AppTheme.walkInGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          activeShift.namaCounter,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const StatusBadge(
                        label: 'SHIFT AKTIF',
                        variant: StatusBadgeVariant.readyGreen,
                        small: true,
                      ),
                    ],
                  ),
                  Text(
                    '${activeShift.kodeCashierShift} · Sesi ${activeShift.namaShift}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Muat ulang',
              onPressed: _initialize,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: _errorMessage!),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              _MetricRow(
                label: 'Kasir Bertugas',
                value: activeShift.cashierName,
              ),
              const SizedBox(height: 6),
              _MetricRow(
                label: 'Waktu Buka Shift',
                value: AppFormatters.formatDateTimeId(activeShift.openedAt),
              ),
              const Divider(height: 18),
              _MetricRow(
                label: 'Saldo Awal (Opening Cash)',
                value: AppFormatters.formatRupiah(activeShift.openingCash),
              ),
              const SizedBox(height: 6),
              _MetricRow(
                label: 'Penerimaan Tunai (Cash In)',
                value: AppFormatters.formatRupiah(stats?.totalCashIn ?? 0),
                valueColor: AppTheme.walkInGreen,
              ),
              const SizedBox(height: 6),
              _MetricRow(
                label: 'Penerimaan Non-Tunai (EDC/QRIS/Transfer)',
                value: AppFormatters.formatRupiah(stats?.totalNonCashIn ?? 0),
                valueColor: AppTheme.bookingBlue,
              ),
              const Divider(height: 18),
              _MetricRow(
                label: 'Estimasi Kas Sistem di Laci',
                value: AppFormatters.formatRupiah(systemCash),
                bold: true,
                valueColor: AppTheme.primary,
              ),
            ],
          ),
        ),
        if (stats != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStatBox(
                  label: 'Check-In',
                  value: '${stats.totalCheckinKamar} Kamar',
                  sub: '${stats.totalCheckinPax} Tamu',
                  color: AppTheme.arrivalsTeal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStatBox(
                  label: 'Checkout',
                  value: '${stats.totalCheckoutKamar} Kamar',
                  sub: '${stats.totalCheckoutPax} Tamu',
                  color: AppTheme.checkoutOrange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStatBox(
                  label: 'Add-On',
                  value: '${stats.totalFasilitasItem} Item',
                  sub: AppFormatters.formatRupiah(stats.totalFasilitasAmount),
                  color: AppTheme.inHouseIndigo,
                ),
              ),
            ],
          ),
        ],
        if (paySummary.isNotEmpty && !_showCloseForm) ...[
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.border),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.border),
            ),
            title: const Text(
              'Rincian Pembayaran per Metode & Jurnal',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            children: [
              _MetricRow(
                label: 'Tunai (Cash)',
                value: AppFormatters.formatRupiah(paySummary['cash'] ?? 0),
              ),
              const SizedBox(height: 4),
              _MetricRow(
                label: 'Kartu Debit/Kredit (EDC)',
                value: AppFormatters.formatRupiah(paySummary['card'] ?? 0),
              ),
              const SizedBox(height: 4),
              _MetricRow(
                label: 'QRIS',
                value: AppFormatters.formatRupiah(paySummary['qris'] ?? 0),
              ),
              const SizedBox(height: 4),
              _MetricRow(
                label: 'Transfer Bank',
                value: AppFormatters.formatRupiah(paySummary['transfer'] ?? 0),
              ),
              if ((_shiftDetail?.payments ?? const []).isNotEmpty) ...[
                const Divider(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Transaksi Terakhir Shift Ini:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                ...(_shiftDetail!.payments.reversed.take(5)).map((pay) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${pay['nama_tamu'] ?? 'Tamu'} (${(pay['payment_method'] ?? 'cash').toString().toUpperCase()})',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          AppFormatters.formatRupiah(pay['amount']),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (!_showCloseForm)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Tutup Panel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => setState(() => _showCloseForm = true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.dangerRed,
                  ),
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Tutup Shift Kasir'),
                ),
              ),
            ],
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.dangerRedBg.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.dangerRed.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Form Penutupan Shift Kasir (Handover)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.dangerRed,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _closingCashController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Uang Tunai Fisik Aktual di Laci (Closing Cash)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Selisih Kas (Aktual vs Sistem):',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      diff == 0
                          ? 'Sesuai (Rp 0)'
                          : '${diff > 0 ? '+' : ''}${AppFormatters.formatRupiah(diff)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: diff == 0
                            ? AppTheme.walkInGreen
                            : AppTheme.dangerRed,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _handoverNotesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Handover Shift (Opsional)',
                    hintText: 'Catatan serah terima untuk shift berikutnya',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => setState(() => _showCloseForm = false),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => _submitCloseShift(activeShift),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.dangerRed,
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          _isSubmitting ? 'Menutup...' : 'Konfirmasi Tutup',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerRedBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppTheme.dangerRed,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
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
            fontSize: bold ? 14 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MiniStatBox extends StatelessWidget {
  const _MiniStatBox({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppTheme.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

