import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../utils/formatters.dart';

typedef PaymentSelectionState = PaymentSelectionData;

class PaymentSelectionData {
  const PaymentSelectionData({
    required this.paymentMethod,
    this.bankName = '',
    this.cardType = '',
    required this.referenceNo,
  });

  final String paymentMethod; // 'cash' | 'card' | 'qris' | 'transfer'
  final String bankName;
  final String cardType; // 'debit' | 'credit'
  final String referenceNo;

  PaymentSelectionData copyWith({
    String? paymentMethod,
    String? bankName,
    String? cardType,
    String? referenceNo,
  }) {
    return PaymentSelectionData(
      paymentMethod: paymentMethod ?? this.paymentMethod,
      bankName: bankName ?? this.bankName,
      cardType: cardType ?? this.cardType,
      referenceNo: referenceNo ?? this.referenceNo,
    );
  }
}

class PaymentMethodSelector extends StatefulWidget {
  const PaymentMethodSelector({
    this.value,
    this.state,
    this.title,
    required this.onChanged,
    this.activeShiftCode,
    this.onOpenShiftRequested,
    this.requireShiftForAllMethods = false,
    super.key,
  }) : assert(value != null || state != null);

  final PaymentSelectionData? value;
  final PaymentSelectionData? state;
  final String? title;
  final ValueChanged<PaymentSelectionData> onChanged;
  final String? activeShiftCode;
  final VoidCallback? onOpenShiftRequested;
  final bool requireShiftForAllMethods;

  PaymentSelectionData get currentValue =>
      value ??
      state ??
      const PaymentSelectionData(paymentMethod: 'cash', referenceNo: '');

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  static const List<String> _banks = [
    'BCA',
    'Mandiri',
    'BNI',
    'BRI',
    'CIMB Niaga',
    'Permata',
    'BSI',
    'Lainnya',
  ];

  late final TextEditingController _refController;

  @override
  void initState() {
    super.initState();
    _refController = TextEditingController(
      text: widget.currentValue.referenceNo,
    );
  }

  @override
  void didUpdateWidget(covariant PaymentMethodSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentValue.referenceNo !=
            widget.currentValue.referenceNo &&
        _refController.text != widget.currentValue.referenceNo) {
      _refController.text = widget.currentValue.referenceNo;
    }
  }

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  void _selectMethod(String method) {
    final defaultBank = (method == 'card' || method == 'transfer')
        ? (widget.currentValue.bankName.isNotEmpty
            ? widget.currentValue.bankName
            : 'BCA')
        : '';
    final defaultCardType = method == 'card'
        ? (widget.currentValue.cardType.isNotEmpty
            ? widget.currentValue.cardType
            : 'debit')
        : '';
    final newRef = AppFormatters.generatePaymentRefNo(
      method,
      bankName: defaultBank,
      cardType: defaultCardType,
    );
    _refController.text = newRef;
    widget.onChanged(
      PaymentSelectionData(
        paymentMethod: method,
        bankName: defaultBank,
        cardType: defaultCardType,
        referenceNo: newRef,
      ),
    );
  }

  void _updateBank(String? bank) {
    if (bank == null) return;
    final newRef = AppFormatters.generatePaymentRefNo(
      widget.currentValue.paymentMethod,
      bankName: bank,
      cardType: widget.currentValue.cardType,
    );
    _refController.text = newRef;
    widget.onChanged(
      widget.currentValue.copyWith(
        bankName: bank,
        referenceNo: newRef,
      ),
    );
  }

  void _updateCardType(String type) {
    final newRef = AppFormatters.generatePaymentRefNo(
      widget.currentValue.paymentMethod,
      bankName: widget.currentValue.bankName,
      cardType: type,
    );
    _refController.text = newRef;
    widget.onChanged(
      widget.currentValue.copyWith(
        cardType: type,
        referenceNo: newRef,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final method = widget.currentValue.paymentMethod;
    final hasActiveShift =
        widget.activeShiftCode != null && widget.activeShiftCode!.isNotEmpty;
    final needsShiftWarning = !hasActiveShift &&
        (widget.requireShiftForAllMethods || method == 'cash');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title ?? 'Metode Pembayaran',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.9,
          children: [
            _MethodTile(
              label: 'Tunai (Cash)',
              icon: Icons.payments_outlined,
              selected: method == 'cash',
              onTap: () => _selectMethod('cash'),
            ),
            _MethodTile(
              label: 'Kartu (EDC)',
              icon: Icons.credit_card_outlined,
              selected: method == 'card',
              onTap: () => _selectMethod('card'),
            ),
            _MethodTile(
              label: 'QRIS',
              icon: Icons.qr_code_2_outlined,
              selected: method == 'qris',
              onTap: () => _selectMethod('qris'),
            ),
            _MethodTile(
              label: 'Transfer Bank',
              icon: Icons.account_balance_outlined,
              selected: method == 'transfer',
              onTap: () => _selectMethod('transfer'),
            ),
          ],
        ),
        if (needsShiftWarning) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.checkoutOrangeBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.checkoutOrange.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.checkoutOrange,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Shift kasir belum dibuka. Transaksi finansial memerlukan sesi shift kasir aktif.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.checkoutOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.onOpenShiftRequested != null) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: widget.onOpenShiftRequested,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.checkoutOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Buka Shift',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (method == 'card') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Kartu Debit'),
                  selected: (widget.currentValue.cardType.isNotEmpty
                          ? widget.currentValue.cardType
                          : 'debit') ==
                      'debit',
                  onSelected: (_) => _updateCardType('debit'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Kartu Kredit'),
                  selected: widget.currentValue.cardType == 'credit',
                  onSelected: (_) => _updateCardType('credit'),
                ),
              ),
            ],
          ),
        ],
        if (method == 'card' || method == 'transfer') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _banks.contains(widget.currentValue.bankName)
                ? widget.currentValue.bankName
                : _banks.first,
            decoration: const InputDecoration(
              labelText: 'Pilih Bank / EDC',
              prefixIcon: Icon(Icons.account_balance_outlined, size: 18),
            ),
            items: _banks
                .map(
                  (b) => DropdownMenuItem<String>(
                    value: b,
                    child: Text(b),
                  ),
                )
                .toList(),
            onChanged: _updateBank,
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: _refController,
          decoration: InputDecoration(
            labelText: 'Nomor Referensi / Bukti Transaksi',
            prefixIcon: const Icon(Icons.tag, size: 18),
            suffixIcon: IconButton(
              tooltip: 'Generate nomor referensi otomatis',
              icon: const Icon(Icons.autorenew, size: 18),
              onPressed: () {
                final generated = AppFormatters.generatePaymentRefNo(
                  widget.currentValue.paymentMethod,
                  bankName: widget.currentValue.bankName,
                  cardType: widget.currentValue.cardType,
                );
                _refController.text = generated;
                widget.onChanged(
                  widget.currentValue.copyWith(referenceNo: generated),
                );
              },
            ),
          ),
          onChanged: (val) => widget.onChanged(
            widget.currentValue.copyWith(referenceNo: val.trim()),
          ),
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryLight : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppTheme.primary : AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

