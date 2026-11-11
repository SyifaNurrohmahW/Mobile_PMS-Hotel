import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/storage/secure_storage_service.dart';
import '../data/reservation_repository.dart';

enum OperationalListType { arrivals, inHouse, checkout }

class OperationalListScreen extends ConsumerStatefulWidget {
  const OperationalListScreen({required this.type, super.key});

  final OperationalListType type;

  @override
  ConsumerState<OperationalListScreen> createState() => _OperationalListScreenState();
}

class _OperationalListScreenState extends ConsumerState<OperationalListScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  String get _title => switch (widget.type) {
        OperationalListType.arrivals => 'Check-in',
        OperationalListType.inHouse => 'Tamu Menginap',
        OperationalListType.checkout => 'Checkout',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final branchCode = await const SecureStorageService().read('active_branch_code');
      if (branchCode == null || branchCode.isEmpty) {
        throw StateError('Cabang aktif tidak tersedia. Silakan login kembali.');
      }
      final repository = ref.read(reservationRepositoryProvider);
      final items = switch (widget.type) {
        OperationalListType.arrivals => await repository.arrivals(
            branchCode: branchCode,
            checkInDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          ),
        OperationalListType.inHouse => await repository.inHouse(branchCode: branchCode),
        OperationalListType.checkout => await repository.checkoutSearch(branchCode: branchCode),
      };
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIn(Map<String, dynamic> item) async {
    final confirmed = await _confirm(
      title: 'Proses check-in?',
      message: 'Check-in ${item['guest_name'] ?? 'tamu'} untuk reservasi ${item['kode_reservasi_room'] ?? ''}?',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(reservationRepositoryProvider).checkIn(
            item['kode_reservasi_room'].toString(),
          );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    }
  }

  Future<void> _checkout(Map<String, dynamic> item) async {
    final confirmed = await _confirm(
      title: 'Konfirmasi checkout?',
      message: 'Folio ${item['kode_folio'] ?? ''} telah lunas. Proses checkout kamar ${item['nomor_kamar'] ?? ''}?',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(reservationRepositoryProvider).checkout({
        'kode_folio': item['kode_folio'],
      });
      await _load();
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    }
  }

  Future<bool> _confirm({required String title, required String message}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Konfirmasi')),
            ],
          ),
        ) ??
        false;
  }

  String _primaryLabel(Map<String, dynamic> item) => switch (widget.type) {
        OperationalListType.arrivals => item['guest_name']?.toString() ?? 'Tamu',
        OperationalListType.inHouse => item['guest_name']?.toString() ?? 'Tamu',
        OperationalListType.checkout => item['guest_name']?.toString() ?? 'Tamu',
      };

  String _detailLabel(Map<String, dynamic> item) => switch (widget.type) {
        OperationalListType.arrivals => '${item['nomor_kamar'] ?? 'Belum dialokasikan'} · ${item['tipe_kamar_name'] ?? ''} · ${item['check_in_date'] ?? ''}',
        OperationalListType.inHouse => 'Kamar ${item['nomor_kamar'] ?? '-'} · Checkout ${item['check_out_date'] ?? '-'} · Saldo ${item['balance'] ?? 0}',
        OperationalListType.checkout => 'Kamar ${item['nomor_kamar'] ?? '-'} · Saldo ${item['balance'] ?? 0} · Inspeksi ${item['inspection_status'] ?? 'belum diminta'}',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(onPressed: _isLoading ? null : _load, tooltip: 'Muat ulang', icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _MessageState(
                  icon: Icons.cloud_off_outlined,
                  message: _errorMessage!,
                  action: FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
                )
              : _items.isEmpty
                  ? _MessageState(
                      icon: Icons.inbox_outlined,
                      message: 'Belum ada data ${_title.toLowerCase()}.',
                      action: OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Muat ulang')),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final canCheckIn = widget.type == OperationalListType.arrivals;
                          final canCheckout = widget.type == OperationalListType.checkout && item['is_settled'] == true;
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(child: Icon(canCheckIn ? Icons.login : widget.type == OperationalListType.checkout ? Icons.receipt_long : Icons.hotel)),
                              title: Text(_primaryLabel(item)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('${_detailLabel(item)}\n${item['guest_phone'] ?? ''}'),
                              ),
                              isThreeLine: true,
                              trailing: canCheckIn
                                  ? IconButton.filledTonal(
                                      tooltip: 'Check-in',
                                      onPressed: () => _checkIn(item),
                                      icon: const Icon(Icons.login),
                                    )
                                  : canCheckout
                                      ? IconButton.filledTonal(
                                          tooltip: 'Checkout',
                                          onPressed: () => _checkout(item),
                                          icon: const Icon(Icons.check),
                                        )
                                      : null,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message, required this.action});

  final IconData icon;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            action,
          ],
        ),
      ),
    );
  }
}