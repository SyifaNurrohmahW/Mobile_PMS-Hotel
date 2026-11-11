import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../domain/dashboard_models.dart';
import 'room_detail_sheet.dart';

class RoomRackGrid extends StatefulWidget {
  const RoomRackGrid({
    required this.rooms,
    this.monitoring,
    super.key,
  });

  final List<RoomRackItem> rooms;
  final RoomMonitoringMatrix? monitoring;

  @override
  State<RoomRackGrid> createState() => _RoomRackGridState();
}

class _RoomRackGridState extends State<RoomRackGrid> {
  String _statusFilter = 'all'; // 'all' | 'ready' | 'occupied' | 'dirty' | 'maintenance'
  String _selectedFloor = 'ALL';
  String _searchQuery = '';
  bool _showMonitoringMatrix = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _floors {
    final set = <String>{};
    for (final rm in widget.rooms) {
      if (rm.lantai.isNotEmpty) set.add(rm.lantai);
    }
    final sorted = set.toList()..sort();
    return ['ALL', ...sorted];
  }

  List<RoomRackItem> get _filteredRooms {
    final q = _searchQuery.trim().toLowerCase();
    return widget.rooms.where((rm) {
      if (_statusFilter != 'all' && rm.displayStatus != _statusFilter) {
        return false;
      }
      if (_selectedFloor != 'ALL' && rm.lantai != _selectedFloor) {
        return false;
      }
      if (q.isNotEmpty) {
        final matchNo = rm.nomorKamar.toLowerCase().contains(q);
        final matchType = rm.namaTipe.toLowerCase().contains(q);
        final matchGuest =
            (rm.activeStay?.guestName ?? '').toLowerCase().contains(q);
        return matchNo || matchType || matchGuest;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final floors = _floors;
    if (!floors.contains(_selectedFloor)) {
      _selectedFloor = 'ALL';
    }
    final filtered = _filteredRooms;
    final hasMonitoring =
        widget.monitoring != null && widget.monitoring!.dates.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Rak Kamar Front Desk',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (hasMonitoring) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => setState(
                  () => _showMonitoringMatrix = !_showMonitoringMatrix,
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  _showMonitoringMatrix
                      ? Icons.grid_view_rounded
                      : Icons.calendar_view_week_rounded,
                  size: 15,
                ),
                label: Text(
                  _showMonitoringMatrix ? 'Rak Kamar' : 'Matriks 7 Hari',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (_showMonitoringMatrix && hasMonitoring)
          _MonitoringMatrixTable(matrix: widget.monitoring!)
        else ...[
          // Filter ChoiceChips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChipItem(
                  label: 'Semua (${widget.rooms.length})',
                  selected: _statusFilter == 'all',
                  onSelected: () => setState(() => _statusFilter = 'all'),
                ),
                const SizedBox(width: 6),
                _FilterChipItem(
                  label:
                      'Siap Huni (${widget.rooms.where((r) => r.displayStatus == 'ready').length})',
                  selected: _statusFilter == 'ready',
                  color: AppTheme.walkInGreen,
                  onSelected: () => setState(() => _statusFilter = 'ready'),
                ),
                const SizedBox(width: 6),
                _FilterChipItem(
                  label:
                      'Terisi (${widget.rooms.where((r) => r.displayStatus == 'occupied').length})',
                  selected: _statusFilter == 'occupied',
                  color: AppTheme.bookingBlue,
                  onSelected: () => setState(() => _statusFilter = 'occupied'),
                ),
                const SizedBox(width: 6),
                _FilterChipItem(
                  label:
                      'Kotor (${widget.rooms.where((r) => r.displayStatus == 'dirty').length})',
                  selected: _statusFilter == 'dirty',
                  color: AppTheme.dangerRed,
                  onSelected: () => setState(() => _statusFilter = 'dirty'),
                ),
                const SizedBox(width: 6),
                _FilterChipItem(
                  label:
                      'Perawatan (${widget.rooms.where((r) => r.displayStatus == 'maintenance').length})',
                  selected: _statusFilter == 'maintenance',
                  color: AppTheme.neutralSlate,
                  onSelected: () =>
                      setState(() => _statusFilter = 'maintenance'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Floor dropdown + Search input
          Row(
            children: [
              SizedBox(
                width: 132,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedFloor,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  items: floors
                      .map(
                        (f) => DropdownMenuItem<String>(
                          value: f,
                          child: Text(
                            f == 'ALL' ? 'Semua Lantai' : f,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedFloor = val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Cari no. kamar / nama tamu...',
                    hintStyle: const TextStyle(fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.clear, size: 16),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const AppEmptyState(
              icon: Icons.meeting_room_outlined,
              title: 'Tidak Ada Kamar Sesuai Filter',
              subtitle:
                  'Coba ubah filter status kamar, lantai, atau kata kunci pencarian.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = constraints.maxWidth >= 900
                    ? 4
                    : (constraints.maxWidth >= 560 ? 3 : 2);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 126,
                  ),
                  itemBuilder: (context, index) {
                    final room = filtered[index];
                    return _RoomRackCard(
                      room: room,
                      onTap: () => RoomDetailSheet.show(context, room),
                    );
                  },
                );
              },
            ),
        ],
      ],
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppTheme.primary;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: activeColor.withValues(alpha: 0.16),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? activeColor : AppTheme.textSecondary,
      ),
      side: BorderSide(
        color: selected ? activeColor : AppTheme.border,
      ),
    );
  }
}

class _RoomRackCard extends StatelessWidget {
  const _RoomRackCard({
    required this.room,
    required this.onTap,
  });

  final RoomRackItem room;
  final VoidCallback onTap;

  (Color fg, Color bg, String shortBadge) get _style =>
      switch (room.displayStatus) {
        'ready' => (
            AppTheme.walkInGreen,
            AppTheme.walkInGreenBg,
            'SIAP HUNI',
          ),
        'occupied' => (
            AppTheme.bookingBlue,
            AppTheme.bookingBlueBg,
            'TERISI',
          ),
        'dirty' => (
            AppTheme.dangerRed,
            AppTheme.dangerRedBg,
            'KOTOR',
          ),
        _ => (
            AppTheme.neutralSlate,
            AppTheme.neutralSlateBg,
            'PERAWATAN',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (fg, bg, badgeText) = _style;
    final stay = room.activeStay;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: fg.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  room.nomorKamar,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: fg,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              room.namaTipe,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              room.lantai,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            if (stay != null)
              Row(
                children: [
                  const Icon(
                    Icons.person_rounded,
                    size: 13,
                    color: AppTheme.bookingBlue,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${stay.guestName} (CO: ${stay.checkOutDate})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.bookingBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(
                    room.displayStatus == 'ready'
                        ? Icons.touch_app_outlined
                        : Icons.cleaning_services_outlined,
                    size: 13,
                    color: fg,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      room.displayStatus == 'ready'
                          ? 'Ketuk untuk Walk-In / Booking'
                          : room.statusLabel,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: fg,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MonitoringMatrixTable extends StatelessWidget {
  const _MonitoringMatrixTable({required this.matrix});

  final RoomMonitoringMatrix matrix;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: DataTable(
          headingRowHeight: 42,
          dataRowMinHeight: 38,
          dataRowMaxHeight: 44,
          columnSpacing: 14,
          columns: [
            const DataColumn(
              label: Text(
                'Kamar',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
            ...matrix.dates.map(
              (d) => DataColumn(
                label: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      d.dayName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: d.isToday
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      d.formatted,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color:
                            d.isToday ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          rows: matrix.rooms.take(25).map((rm) {
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    '${rm.nomorKamar} (${rm.namaTipe})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                ...matrix.dates.map((d) {
                  final cell = rm.cellsByDate[d.date];
                  final status = cell?.status ?? 'ready';
                  final (fg, bg) = switch (status) {
                    'inhouse' => (AppTheme.bookingBlue, AppTheme.bookingBlueBg),
                    'booked' => (
                        AppTheme.arrivalsTeal,
                        AppTheme.arrivalsTealBg
                      ),
                    'dirty' => (AppTheme.dangerRed, AppTheme.dangerRedBg),
                    _ => (AppTheme.walkInGreen, AppTheme.walkInGreenBg),
                  };
                  return DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cell?.guestName ?? cell?.label ?? 'Ready',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

