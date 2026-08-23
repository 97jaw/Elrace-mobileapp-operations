import 'package:el_race/core/drawing_studio/drawing_studio_config.dart';

/// Editable room row for Section B.
class DrawingStudioRoomDraft {
  DrawingStudioRoomDraft({
    this.roomId,
    this.name = '',
    this.nameAr = '',
    this.category = 'bedroom',
    this.floorLevel = 'ground',
    this.areaM2 = 12,
    this.hasEnsuite = false,
    this.hasBalcony = false,
    this.notes,
  });

  String? roomId;
  String name;
  String nameAr;
  String category;
  String floorLevel;
  double areaM2;
  bool hasEnsuite;
  bool hasBalcony;
  String? notes;

  factory DrawingStudioRoomDraft.fromJson(Map<String, dynamic> json) {
    return DrawingStudioRoomDraft(
      roomId: json['room_id']?.toString(),
      name: (json['name'] ?? '').toString(),
      nameAr: (json['name_ar'] ?? json['nameAr'] ?? '').toString(),
      category: (json['category'] ?? 'bedroom').toString(),
      floorLevel: (json['floor_level'] ?? json['floorLevel'] ?? 'ground')
          .toString(),
      areaM2: (json['area_m2'] is num)
          ? (json['area_m2'] as num).toDouble()
          : double.tryParse(json['area_m2']?.toString() ?? '') ?? 12,
      hasEnsuite: json['has_ensuite'] == true,
      hasBalcony: json['has_balcony'] == true,
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (roomId != null && roomId!.isNotEmpty) 'room_id': roomId,
        'name': name.trim(),
        if (nameAr.trim().isNotEmpty) 'name_ar': nameAr.trim(),
        'category': category,
        'floor_level': floorLevel,
        'area_m2': areaM2,
        'has_ensuite': hasEnsuite,
        'has_balcony': hasBalcony,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      };
}

/// In-memory form state for Build via Form → `POST /generate`.
class DrawingStudioFormDraft {
  DrawingStudioFormDraft();

  // A
  String projectName = '';
  String projectType = 'villa';
  double plotAreaM2 = 600;
  double? plotLengthM;
  double? plotWidthM;
  int numberOfFloors = 1;
  String basement = 'none';

  // B
  String spaceTemplate = '3br_standard';
  List<DrawingStudioRoomDraft> rooms = [];
  List<String> specialSpaces = [];
  bool poolEnabled = false;
  int parkingCarCount = 2;
  String parkingType = 'covered';

  // C
  String architecturalStyle = 'modern_contemporary';
  String facadePrimary = 'natural_stone';
  String facadeAccent = 'none';
  String roofType = 'flat_parapet';
  String windowFrame = 'aluminum_dark';
  String glazingType = 'clear_double';

  // D
  String flooringType = 'porcelain_large';
  String flooringTone = 'light';
  String wallFinish = 'paint_matte';
  String wallColorTone = 'warm_white';
  String ceilingType = 'gypsum_bulkhead';
  double ceilingHeightM = 3.2;

  // E
  List<String> outputs = const [
    'floor_plan_2d',
    'floor_plan_3d',
    'exterior_3d',
    'interior_3d',
  ];
  List<String> exteriorViews = const ['main_entrance', 'birds_eye'];
  List<String> interiorViews = const [
    'living_area',
    'kitchen',
    'master_bedroom',
  ];

  // F
  String customBrief = '';
  String instructions = '';

  /// Field key → error message from last 400 `issues`.
  Map<String, String> fieldErrors = {};

  void applyTemplateRooms(DrawingStudioConfig config) {
    final raw = config.templateRooms(spaceTemplate);
    if (raw.isEmpty) return;
    rooms = raw.map(DrawingStudioRoomDraft.fromJson).toList();
  }

  void ensureMinimumRooms() {
    if (rooms.length >= 3) return;
    rooms = [
      DrawingStudioRoomDraft(
        name: 'Master Bedroom',
        nameAr: 'غرفة ماستر',
        category: 'bedroom',
        areaM2: 28,
        hasEnsuite: true,
      ),
      DrawingStudioRoomDraft(
        name: 'Living Area',
        category: 'living',
        areaM2: 40,
      ),
      DrawingStudioRoomDraft(
        name: 'Bathroom',
        category: 'bathroom',
        areaM2: 6,
      ),
    ];
  }

  Map<String, dynamic> toFormJson() {
    final form = <String, dynamic>{
      'project_name': projectName.trim(),
      'project_type': projectType,
      'plot_area_m2': plotAreaM2,
      'number_of_floors': numberOfFloors,
      'basement': basement,
      'space_template': spaceTemplate,
      'rooms': rooms.map((r) => r.toJson()).toList(),
      'special_spaces': specialSpaces,
      'pool': poolEnabled
          ? <String, dynamic>{
              'size': 'medium',
              'features': ['pool_deck'],
            }
          : null,
      'parking': {
        'car_count': parkingCarCount,
        'type': parkingType,
      },
      'architectural_style': architecturalStyle,
      'facade_primary': facadePrimary,
      'facade_accent': facadeAccent,
      'roof_type': roofType,
      'window_frame': windowFrame,
      'glazing_type': glazingType,
      'flooring_type': flooringType,
      'flooring_tone': flooringTone,
      'wall_finish': wallFinish,
      'wall_color_tone': wallColorTone,
      'ceiling_type': ceilingType,
      'ceiling_height_m': ceilingHeightM,
      'outputs': outputs,
      'exterior_views': exteriorViews,
      'interior_views': interiorViews,
    };

    if (plotLengthM != null) form['plot_length_m'] = plotLengthM;
    if (plotWidthM != null) form['plot_width_m'] = plotWidthM;
    if (customBrief.trim().isNotEmpty) {
      form['custom_brief'] = customBrief.trim();
    }
    return form;
  }

  Map<String, dynamic> toGenerateBody() {
    final body = <String, dynamic>{'form': toFormJson()};
    if (instructions.trim().isNotEmpty) {
      body['instructions'] = instructions.trim();
    }
    return body;
  }

  void applyIssues(List<DrawingStudioFormIssue> issues) {
    fieldErrors = {
      for (final i in issues)
        if (i.field.isNotEmpty) i.field: i.message,
    };
  }

  String? errorFor(String field) => fieldErrors[field];
}
