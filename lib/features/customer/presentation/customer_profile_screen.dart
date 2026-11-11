import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/presentation/session_notifier.dart';
import '../../reservation/data/reservation_repository.dart';

class CustomerProfileScreen extends ConsumerStatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  ConsumerState<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends ConsumerState<CustomerProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  String _guestType = 'individual';
  String _title = 'Mr';
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String _idType = 'ktp';
  final _idNumberController = TextEditingController();
  String _gender = 'L';
  DateTime? _birthDate;
  final _nationalityController = TextEditingController(text: 'Indonesia');
  final _internalNotesController = TextEditingController();

  Map<String, dynamic>? _savedGuest;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedProfile();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idNumberController.dispose();
    _nationalityController.dispose();
    _internalNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedProfile() async {
    final guest = await ref
        .read(reservationRepositoryProvider)
        .readSavedCustomerGuest();
    if (!mounted || guest == null) return;
    setState(() {
      _savedGuest = guest;
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
    });
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

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final branchCode = ref.read(sessionProvider)?.activeKodeCabang ?? 'CAB0001';
    setState(() => _isSaving = true);

    try {
      final saved = await ref
          .read(reservationRepositoryProvider)
          .registerOrUpdateMasterGuest(
            branchCode: branchCode,
            existingKodeTamu:
                AppFormatters.parseString(_savedGuest?['kode_tamu']),
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
      setState(() => _savedGuest = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profil Identitas Tamu (${saved['kode_tamu']}) berhasil disimpan ke database.',
          ),
          backgroundColor: AppTheme.walkInGreen,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchCode =
        ref.watch(sessionProvider)?.activeKodeCabang ?? 'CAB0001';
    final branchName =
        ref.watch(sessionProvider)?.activeBranchName ?? 'Grand Marstech Hotel';
    final kodeTamu = AppFormatters.parseString(_savedGuest?['kode_tamu']);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
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
                      Icons.badge_rounded,
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
                          'Profil Identitas Tamu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          kodeTamu.isNotEmpty
                              ? 'Terdaftar di Master Tamu · Kode: $kodeTamu'
                              : 'Lengkapi identitas untuk mempercepat pemesanan kamar',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Data Master Tamu Pelanggan',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              if (kodeTamu.isNotEmpty)
                                StatusBadge(
                                  label: kodeTamu,
                                  variant: StatusBadgeVariant.readyGreen,
                                  small: true,
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 1. Tipe Tamu
                          const Text(
                            'Tipe Tamu *',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'individual',
                                label: Text(
                                  'Individual (Perorangan)',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              ButtonSegment(
                                value: 'group',
                                label: Text(
                                  'Group (Rombongan)',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                            selected: {_guestType},
                            onSelectionChanged: (v) {
                              if (v.isNotEmpty) {
                                setState(() => _guestType = v.first);
                              }
                            },
                          ),
                          const SizedBox(height: 14),

                          // 2. Cabang Hotel
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
                                    branchName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                StatusBadge(
                                  label: branchCode,
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
                                  key: ValueKey('prof_title_$_title'),
                                  initialValue: _title,
                                  decoration: const InputDecoration(
                                    labelText: 'Gelar',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Mr',
                                      child: Text('Mr'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Mrs',
                                      child: Text('Mrs'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Ms',
                                      child: Text('Ms'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Dr',
                                      child: Text('Dr'),
                                    ),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Lengkap *',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Nama lengkap wajib diisi'
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 5. Telepon / WhatsApp
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Telp / WhatsApp *',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Nomor telepon wajib diisi'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // 6. Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 7 & 8. Tipe & Nomor Identitas
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 122,
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('prof_id_$_idType'),
                                  initialValue: _idType,
                                  decoration: const InputDecoration(
                                    labelText: 'Tipe ID *',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'ktp',
                                      child: Text('KTP'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'passport',
                                      child: Text('Paspor'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'sim',
                                      child: Text('SIM'),
                                    ),
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
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
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
                                  key: ValueKey('prof_gender_$_gender'),
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
                                          ? AppFormatters.formatDateYmd(
                                              _birthDate!,
                                            )
                                          : 'Pilih Tanggal',
                                      style: const TextStyle(fontSize: 13),
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
                              prefixIcon: Icon(Icons.public_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 12. Catatan
                          TextFormField(
                            controller: _internalNotesController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Catatan / Preferensi (Opsional)',
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                          ),
                          const SizedBox(height: 18),

                          SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _isSaving ? null : _saveProfile,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _isSaving
                                    ? 'Menyimpan...'
                                    : 'Simpan Identitas Master Tamu',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

