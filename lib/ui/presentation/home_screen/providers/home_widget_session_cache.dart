/// Raw API payloads cached for home category widgets (5-minute TTL).
class HomeWidgetSessionCache {
  HomeWidgetSessionCache._();

  static Map<String, dynamic>? attendanceRaw;
  static Map<String, dynamic>? hrmsRaw;
  static Map<String, dynamic>? timesheetRaw;
  static Map<String, dynamic>? myProjectsRaw;
  static Map<String, dynamic>? siteManagementRaw;
  static Map<String, dynamic>? myReportsRaw;
  static Map<String, dynamic>? lpoRaw;
  static Map<String, dynamic>? notesRaw;
  static Map<String, dynamic>? taskManagementRaw;
  static Map<String, dynamic>? ticketsRaw;
  static Map<String, dynamic>? pettyCashRaw;
  static Map<String, dynamic>? myDocumentsRaw;
  static Map<String, dynamic>? mediaRaw;
  static Map<String, dynamic>? prayerTimesRaw;
  static DateTime? fetchedAt;

  static const ttl = Duration(minutes: 5);

  static bool get isFresh {
    if (fetchedAt == null) return false;
    return DateTime.now().difference(fetchedAt!) < ttl;
  }

  static void markFetched() {
    fetchedAt = DateTime.now();
  }

  static void store({
    Map<String, dynamic>? attendanceRaw,
    Map<String, dynamic>? hrmsRaw,
    Map<String, dynamic>? timesheetRaw,
    Map<String, dynamic>? myProjectsRaw,
    Map<String, dynamic>? siteManagementRaw,
    Map<String, dynamic>? myReportsRaw,
    Map<String, dynamic>? lpoRaw,
    Map<String, dynamic>? notesRaw,
    Map<String, dynamic>? taskManagementRaw,
    Map<String, dynamic>? ticketsRaw,
    Map<String, dynamic>? pettyCashRaw,
    Map<String, dynamic>? myDocumentsRaw,
    Map<String, dynamic>? mediaRaw,
    Map<String, dynamic>? prayerTimesRaw,
  }) {
    if (attendanceRaw != null) {
      HomeWidgetSessionCache.attendanceRaw = attendanceRaw;
    }
    if (hrmsRaw != null) {
      HomeWidgetSessionCache.hrmsRaw = hrmsRaw;
    }
    if (timesheetRaw != null) {
      HomeWidgetSessionCache.timesheetRaw = timesheetRaw;
    }
    if (myProjectsRaw != null) {
      HomeWidgetSessionCache.myProjectsRaw = myProjectsRaw;
    }
    if (siteManagementRaw != null) {
      HomeWidgetSessionCache.siteManagementRaw = siteManagementRaw;
    }
    if (myReportsRaw != null) {
      HomeWidgetSessionCache.myReportsRaw = myReportsRaw;
    }
    if (lpoRaw != null) {
      HomeWidgetSessionCache.lpoRaw = lpoRaw;
    }
    if (notesRaw != null) {
      HomeWidgetSessionCache.notesRaw = notesRaw;
    }
    if (taskManagementRaw != null) {
      HomeWidgetSessionCache.taskManagementRaw = taskManagementRaw;
    }
    if (ticketsRaw != null) {
      HomeWidgetSessionCache.ticketsRaw = ticketsRaw;
    }
    if (pettyCashRaw != null) {
      HomeWidgetSessionCache.pettyCashRaw = pettyCashRaw;
    }
    if (myDocumentsRaw != null) {
      HomeWidgetSessionCache.myDocumentsRaw = myDocumentsRaw;
    }
    if (mediaRaw != null) {
      HomeWidgetSessionCache.mediaRaw = mediaRaw;
    }
    if (prayerTimesRaw != null) {
      HomeWidgetSessionCache.prayerTimesRaw = prayerTimesRaw;
    }
    fetchedAt = DateTime.now();
  }

  static void clear() {
    attendanceRaw = null;
    hrmsRaw = null;
    timesheetRaw = null;
    myProjectsRaw = null;
    siteManagementRaw = null;
    myReportsRaw = null;
    lpoRaw = null;
    notesRaw = null;
    taskManagementRaw = null;
    ticketsRaw = null;
    pettyCashRaw = null;
    myDocumentsRaw = null;
    mediaRaw = null;
    prayerTimesRaw = null;
    fetchedAt = null;
  }
}
