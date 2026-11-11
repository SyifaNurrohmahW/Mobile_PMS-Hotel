import 'dart:convert';
import '../../../core/utils/formatters.dart';

class AllowedBranch {
  const AllowedBranch({
    required this.id,
    required this.kodeCabang,
    required this.namaHotel,
    this.alamat,
    this.timezone,
  });

  final int id;
  final String kodeCabang;
  final String namaHotel;
  final String? alamat;
  final String? timezone;

  factory AllowedBranch.fromJson(Map<String, dynamic> json) {
    return AllowedBranch(
      id: AppFormatters.parseInt(json['id']),
      kodeCabang: AppFormatters.parseString(json['kode_cabang']),
      namaHotel: AppFormatters.parseString(
        json['nama_hotel'] ?? json['branch_name'],
        json['kode_cabang']?.toString() ?? 'Cabang',
      ),
      alamat: json['alamat']?.toString(),
      timezone: json['timezone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kode_cabang': kodeCabang,
        'nama_hotel': namaHotel,
        'alamat': alamat,
        'timezone': timezone,
      };
}

class UserSession {
  const UserSession({
    required this.userId,
    required this.userCode,
    required this.username,
    required this.fullname,
    required this.role,
    required this.activeBranchId,
    required this.activeKodeCabang,
    required this.activeBranchName,
    required this.defaultKodeCabang,
    required this.defaultBranchName,
    required this.canSwitchBranch,
    required this.allowedBranches,
  });

  final int userId;
  final String userCode;
  final String username;
  final String fullname;
  final String role;
  final int activeBranchId;
  final String activeKodeCabang;
  final String activeBranchName;
  final String defaultKodeCabang;
  final String defaultBranchName;
  final bool canSwitchBranch;
  final List<AllowedBranch> allowedBranches;

  String get activeBranchCode => activeKodeCabang;

  String get branchBadgeLabel {
    if (activeBranchName.isEmpty || activeBranchName == activeKodeCabang) {
      return activeKodeCabang;
    }
    return '$activeKodeCabang - $activeBranchName';
  }

  String get roleDisplayLabel {
    final normalized = role.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return 'Staf Front Office';
    return normalized
        .split(' ')
        .map(
          (w) => w.isEmpty
              ? ''
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  UserSession copyWith({
    int? activeBranchId,
    String? activeKodeCabang,
    String? activeBranchName,
    bool? canSwitchBranch,
    List<AllowedBranch>? allowedBranches,
  }) {
    return UserSession(
      userId: userId,
      userCode: userCode,
      username: username,
      fullname: fullname,
      role: role,
      activeBranchId: activeBranchId ?? this.activeBranchId,
      activeKodeCabang: activeKodeCabang ?? this.activeKodeCabang,
      activeBranchName: activeBranchName ?? this.activeBranchName,
      defaultKodeCabang: defaultKodeCabang,
      defaultBranchName: defaultBranchName,
      canSwitchBranch: canSwitchBranch ?? this.canSwitchBranch,
      allowedBranches: allowedBranches ?? this.allowedBranches,
    );
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final branchesRaw = json['allowed_branches'];
    final allowedBranches = branchesRaw is List
        ? branchesRaw
            .whereType<Map>()
            .map((e) => AllowedBranch.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <AllowedBranch>[];

    final activeKode = AppFormatters.parseString(
      json['active_kode_cabang'] ?? json['default_kode_cabang'],
    );
    final activeName = AppFormatters.parseString(
      json['active_branch_name'] ?? json['default_branch_name'],
      activeKode,
    );

    return UserSession(
      userId: AppFormatters.parseInt(json['user_id'] ?? json['id']),
      userCode: AppFormatters.parseString(json['user_code']),
      username: AppFormatters.parseString(json['username']),
      fullname: AppFormatters.parseString(
        json['fullname'],
        AppFormatters.parseString(json['username'], 'Front Office'),
      ),
      role: AppFormatters.parseString(json['role'], 'frontdesk'),
      activeBranchId: AppFormatters.parseInt(
        json['active_branch_id'] ?? json['default_branch_id'],
      ),
      activeKodeCabang: activeKode,
      activeBranchName: activeName,
      defaultKodeCabang: AppFormatters.parseString(
        json['default_kode_cabang'],
        activeKode,
      ),
      defaultBranchName: AppFormatters.parseString(
        json['default_branch_name'],
        activeName,
      ),
      canSwitchBranch: AppFormatters.parseBool(json['can_switch_branch']),
      allowedBranches: allowedBranches,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_code': userCode,
        'username': username,
        'fullname': fullname,
        'role': role,
        'active_branch_id': activeBranchId,
        'active_kode_cabang': activeKodeCabang,
        'active_branch_name': activeBranchName,
        'default_kode_cabang': defaultKodeCabang,
        'default_branch_name': defaultBranchName,
        'can_switch_branch': canSwitchBranch,
        'allowed_branches': allowedBranches.map((e) => e.toJson()).toList(),
      };

  String toEncodedJson() => jsonEncode(toJson());

  static UserSession? tryFromEncodedJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return UserSession.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }
}

