import '../../../core/utils/formatters.dart';

class KpiToday {
  const KpiToday({
    required this.occupiedRooms,
    required this.readyRooms,
    required this.dirtyRooms,
    required this.maintenanceRooms,
    required this.arrivalsToday,
    required this.departuresToday,
  });

  final int occupiedRooms;
  final int readyRooms;
  final int dirtyRooms;
  final int maintenanceRooms;
  final int arrivalsToday;
  final int departuresToday;

  factory KpiToday.fromJson(Map<String, dynamic> json) {
    return KpiToday(
      occupiedRooms: AppFormatters.parseInt(
        json['occupied_rooms'] ?? json['occupied'],
      ),
      readyRooms: AppFormatters.parseInt(
        json['ready_rooms'] ?? json['ready_clean'],
      ),
      dirtyRooms: AppFormatters.parseInt(
        json['dirty_rooms'] ?? json['dirty_cleaning'],
      ),
      maintenanceRooms: AppFormatters.parseInt(
        json['maintenance_rooms'] ?? json['maintenance'],
      ),
      arrivalsToday: AppFormatters.parseInt(json['arrivals_today']),
      departuresToday: AppFormatters.parseInt(json['departures_today']),
    );
  }
}

class KpiPeriod {
  const KpiPeriod({
    required this.totalRooms,
    required this.availableRooms,
    required this.allocatedRooms,
    required this.maintenanceRooms,
    required this.occupancyRatePeriod,
  });

  final int totalRooms;
  final int availableRooms;
  final int allocatedRooms;
  final int maintenanceRooms;
  final double occupancyRatePeriod;

  factory KpiPeriod.fromJson(Map<String, dynamic> json) {
    return KpiPeriod(
      totalRooms: AppFormatters.parseInt(
        json['total_rooms'] ?? json['total_units'],
      ),
      availableRooms: AppFormatters.parseInt(
        json['available_rooms'] ?? json['available_units'],
      ),
      allocatedRooms: AppFormatters.parseInt(
        json['allocated_rooms'] ?? json['allocated_units'],
      ),
      maintenanceRooms: AppFormatters.parseInt(
        json['maintenance_rooms'] ?? json['maintenance_units'],
      ),
      occupancyRatePeriod: AppFormatters.parseDouble(
        json['occupancy_rate_period'] ?? json['occupancy_percentage'],
      ),
    );
  }
}

class ActiveStayInfo {
  const ActiveStayInfo({
    required this.guestName,
    required this.phone,
    required this.checkInDate,
    required this.checkOutDate,
    required this.kodeReservasi,
    this.kodeFolio,
  });

  final String guestName;
  final String phone;
  final String checkInDate;
  final String checkOutDate;
  final String kodeReservasi;
  final String? kodeFolio;

  factory ActiveStayInfo.fromJson(Map<String, dynamic> json) {
    return ActiveStayInfo(
      guestName: AppFormatters.parseString(json['guest_name'], 'Tamu Hotel'),
      phone: AppFormatters.parseString(json['phone'], '-'),
      checkInDate: AppFormatters.parseString(json['check_in_date'], '-'),
      checkOutDate: AppFormatters.parseString(json['check_out_date'], '-'),
      kodeReservasi: AppFormatters.parseString(json['kode_reservasi']),
      kodeFolio: json['kode_folio']?.toString(),
    );
  }
}

class RoomRackItem {
  const RoomRackItem({
    required this.kodeKamar,
    required this.nomorKamar,
    required this.namaTipe,
    required this.kodeTipeKamar,
    required this.lantai,
    required this.occupancyStatus,
    required this.housekeepingStatus,
    required this.displayStatus,
    required this.statusLabel,
    this.activeStay,
  });

  final String kodeKamar;
  final String nomorKamar;
  final String namaTipe;
  final String kodeTipeKamar;
  final String lantai;
  final String occupancyStatus;
  final String housekeepingStatus;
  final String displayStatus; // 'ready' | 'occupied' | 'dirty' | 'maintenance'
  final String statusLabel;
  final ActiveStayInfo? activeStay;

  factory RoomRackItem.fromJson(Map<String, dynamic> json) {
    final stayRaw = json['active_stay'];
    return RoomRackItem(
      kodeKamar: AppFormatters.parseString(json['kode_kamar']),
      nomorKamar: AppFormatters.parseString(json['nomor_kamar'], '-'),
      namaTipe: AppFormatters.parseString(json['nama_tipe'], 'Kamar'),
      kodeTipeKamar: AppFormatters.parseString(json['kode_tipe_kamar']),
      lantai: AppFormatters.parseString(json['lantai'], 'Lantai 1'),
      occupancyStatus:
          AppFormatters.parseString(json['occupancy_status'], 'vacant'),
      housekeepingStatus:
          AppFormatters.parseString(json['housekeeping_status'], 'clean'),
      displayStatus: AppFormatters.parseString(json['display_status'], 'ready'),
      statusLabel:
          AppFormatters.parseString(json['status_label'], 'Siap Check-In'),
      activeStay: stayRaw is Map
          ? ActiveStayInfo.fromJson(Map<String, dynamic>.from(stayRaw))
          : null,
    );
  }
}

class CatalogRoomType {
  const CatalogRoomType({
    required this.kodeTipeKamar,
    required this.namaTipe,
    required this.totalUnits,
    required this.availableUnits,
    required this.ratePerNight,
    this.fotoUrl,
  });

  final String kodeTipeKamar;
  final String namaTipe;
  final int totalUnits;
  final int availableUnits;
  final double ratePerNight;
  final String? fotoUrl;

  factory CatalogRoomType.fromJson(Map<String, dynamic> json) {
    return CatalogRoomType(
      kodeTipeKamar: AppFormatters.parseString(json['kode_tipe_kamar']),
      namaTipe: AppFormatters.parseString(json['nama_tipe'], 'Tipe Kamar'),
      totalUnits: AppFormatters.parseInt(json['total_units']),
      availableUnits: AppFormatters.parseInt(json['available_units']),
      ratePerNight: AppFormatters.parseDouble(json['rate_per_night']),
      fotoUrl: json['foto_url']?.toString(),
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.kpiToday,
    required this.kpiPeriod,
    required this.roomRack,
    required this.catalog,
  });

  final KpiToday kpiToday;
  final KpiPeriod kpiPeriod;
  final List<RoomRackItem> roomRack;
  final List<CatalogRoomType> catalog;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final kpiTodayMap = json['kpi_today'] is Map
        ? Map<String, dynamic>.from(json['kpi_today'] as Map)
        : (json['today_operations'] is Map
            ? Map<String, dynamic>.from(json['today_operations'] as Map)
            : <String, dynamic>{});
    final kpiPeriodMap = json['kpi_period'] is Map
        ? Map<String, dynamic>.from(json['kpi_period'] as Map)
        : (json['period_metrics'] is Map
            ? Map<String, dynamic>.from(json['period_metrics'] as Map)
            : <String, dynamic>{});

    final rackRaw = json['room_rack'];
    final roomRack = rackRaw is List
        ? rackRaw
            .whereType<Map>()
            .map((e) => RoomRackItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <RoomRackItem>[];

    final catalogRaw = json['catalog'];
    final catalog = catalogRaw is List
        ? catalogRaw
            .whereType<Map>()
            .map((e) => CatalogRoomType.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <CatalogRoomType>[];

    return DashboardSummary(
      kpiToday: KpiToday.fromJson(kpiTodayMap),
      kpiPeriod: KpiPeriod.fromJson(kpiPeriodMap),
      roomRack: roomRack,
      catalog: catalog,
    );
  }
}

class MonitoringDateColumn {
  const MonitoringDateColumn({
    required this.date,
    required this.dayName,
    required this.formatted,
    required this.isToday,
  });

  final String date;
  final String dayName;
  final String formatted;
  final bool isToday;

  factory MonitoringDateColumn.fromJson(Map<String, dynamic> json) {
    return MonitoringDateColumn(
      date: AppFormatters.parseString(json['date']),
      dayName: AppFormatters.parseString(json['day_name']),
      formatted: AppFormatters.parseString(json['formatted']),
      isToday: AppFormatters.parseBool(json['is_today']),
    );
  }
}

class MonitoringCellStatus {
  const MonitoringCellStatus({
    required this.isOccupied,
    required this.status,
    required this.label,
    this.guestName,
  });

  final bool isOccupied;
  final String status; // 'ready' | 'inhouse' | 'booked' | 'dirty'
  final String label;
  final String? guestName;

  factory MonitoringCellStatus.fromJson(Map<String, dynamic> json) {
    final res = json['reservation'];
    return MonitoringCellStatus(
      isOccupied: AppFormatters.parseBool(json['is_occupied']),
      status: AppFormatters.parseString(json['status'], 'ready'),
      label: AppFormatters.parseString(json['label'], 'Ready'),
      guestName: res is Map ? res['guest_name']?.toString() : null,
    );
  }
}

class MonitoringRoomRow {
  const MonitoringRoomRow({
    required this.kodeKamar,
    required this.nomorKamar,
    required this.namaTipe,
    required this.cellsByDate,
  });

  final String kodeKamar;
  final String nomorKamar;
  final String namaTipe;
  final Map<String, MonitoringCellStatus> cellsByDate;

  factory MonitoringRoomRow.fromJson(Map<String, dynamic> json) {
    final datesRaw = json['dates'];
    final map = <String, MonitoringCellStatus>{};
    if (datesRaw is Map) {
      for (final entry in datesRaw.entries) {
        if (entry.value is Map) {
          map[entry.key.toString()] = MonitoringCellStatus.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    return MonitoringRoomRow(
      kodeKamar: AppFormatters.parseString(json['kode_kamar']),
      nomorKamar: AppFormatters.parseString(json['nomor_kamar']),
      namaTipe: AppFormatters.parseString(json['nama_tipe']),
      cellsByDate: map,
    );
  }
}

class RoomMonitoringMatrix {
  const RoomMonitoringMatrix({
    required this.dates,
    required this.rooms,
  });

  final List<MonitoringDateColumn> dates;
  final List<MonitoringRoomRow> rooms;

  factory RoomMonitoringMatrix.fromJson(Map<String, dynamic> json) {
    final datesRaw = json['dates'];
    final roomsRaw = json['rooms'];
    return RoomMonitoringMatrix(
      dates: datesRaw is List
          ? datesRaw
              .whereType<Map>()
              .map(
                (e) =>
                    MonitoringDateColumn.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
          : const [],
      rooms: roomsRaw is List
          ? roomsRaw
              .whereType<Map>()
              .map(
                (e) => MonitoringRoomRow.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
          : const [],
    );
  }
}

