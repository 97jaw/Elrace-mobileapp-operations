import 'package:el_race/core/drawing_studio/drawing_studio_api_client.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_config.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_form_draft.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_route_names.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/drawing_studio/widgets/drawing_studio_chrome_header.dart';
import 'package:el_race/ui/presentation/drawing_studio/widgets/drawing_studio_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Build via Form — collapsed sections open smart popups; `POST /generate`.
class DrawingStudioFormScreen extends StatefulWidget {
  const DrawingStudioFormScreen({super.key});

  @override
  State<DrawingStudioFormScreen> createState() => _DrawingStudioFormScreenState();
}

class _DrawingStudioFormScreenState extends State<DrawingStudioFormScreen> {
  final _api = DrawingStudioApiClient();
  final _draft = DrawingStudioFormDraft();

  DrawingStudioConfig? _config;
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final config = await _api.getStudioConfig();
      _draft.applyTemplateRooms(config);
      _draft.ensureMinimumRooms();
      if (!mounted) return;
      setState(() {
        _config = config;
        _loading = false;
      });
    } on DrawingStudioApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Unable to load form options.';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
      _draft.fieldErrors = {};
    });

    try {
      final accepted = await _api.generateForm(_draft.toGenerateBody());
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        DrawingStudioRouteNames.generationStatus,
        arguments: {
          'project_id': accepted.projectId,
          'title': accepted.title ?? _draft.projectName,
          'progress': accepted.progress,
        },
      );
    } on DrawingStudioValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _draft.applyIssues(e.issues);
        _submitError = e.message;
        _submitting = false;
      });
    } on DrawingStudioApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.message;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitError = 'Unable to start generation.';
        _submitting = false;
      });
    } finally {
      if (mounted && _submitting) {
        setState(() => _submitting = false);
      }
    }
  }

  bool _sectionHasError(List<String> fields) {
    for (final f in fields) {
      if (_draft.fieldErrors.containsKey(f)) return true;
    }
    return false;
  }

  Future<void> _openSectionA() async {
    final config = _config!;
    await showStudioSmartPopup(
      context: context,
      title: 'A — Project basics',
      builder: (context, close) => _SectionAEditor(
        config: config,
        draft: _draft,
        onDone: () {
          setState(() {});
          close();
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openSectionB() async {
    final config = _config!;
    await showStudioSmartPopup(
      context: context,
      title: 'B — Spaces & rooms',
      builder: (context, close) => _SectionBEditor(
        config: config,
        draft: _draft,
        onDone: () {
          setState(() {});
          close();
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openSectionC() async {
    final config = _config!;
    await showStudioSmartPopup(
      context: context,
      title: 'C — Exterior',
      builder: (context, close) => _SectionCEditor(
        config: config,
        draft: _draft,
        onDone: () {
          setState(() {});
          close();
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openSectionD() async {
    final config = _config!;
    await showStudioSmartPopup(
      context: context,
      title: 'D — Interior',
      builder: (context, close) => _SectionDEditor(
        config: config,
        draft: _draft,
        onDone: () {
          setState(() {});
          close();
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openSectionE() async {
    final config = _config!;
    await showStudioSmartPopup(
      context: context,
      title: 'E — Outputs',
      builder: (context, close) => _SectionEEditor(
        config: config,
        draft: _draft,
        onDone: () {
          setState(() {});
          close();
        },
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openSectionF() async {
    await showStudioSmartPopup(
      context: context,
      title: 'F — Custom brief',
      builder: (context, close) => _SectionFEditor(
        draft: _draft,
        onDone: () {
          setState(() {});
          close();
        },
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
        children: [
          const DrawingStudioChromeHeader(),
          const DrawingStudioHeadingCard(title: 'Build via Form'),
          Expanded(child: _buildBody()),
          if (!_loading && _config != null) _submitBar(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null || _config == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError ?? 'Config unavailable',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13.usp,
                  color: const Color(0xFF5A6A82),
                ),
              ),
              SizedBox(height: 12.uh),
              TextButton(onPressed: _loadConfig, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.uh),
      children: [
        if (_submitError != null)
          Padding(
            padding: EdgeInsets.only(bottom: 10.uh),
            child: Text(
              _submitError!,
              style: GoogleFonts.poppins(
                fontSize: 12.usp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE63946),
              ),
            ),
          ),
        Text(
          'Tap a section to fill it in.',
          style: GoogleFonts.poppins(
            fontSize: 12.usp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF7A849C),
          ),
        ),
        SizedBox(height: 12.uh),
        StudioSectionTile(
          title: 'A — Project basics',
          summary: _draft.projectName.trim().isEmpty
              ? 'Name, type, plot, floors'
              : '${_draft.projectName} · ${_draft.projectType} · '
                  '${_draft.plotAreaM2.toStringAsFixed(0)} m²',
          hasError: _sectionHasError(const [
            'project_name',
            'project_type',
            'plot_area_m2',
            'plot_length_m',
            'plot_width_m',
            'number_of_floors',
            'basement',
          ]),
          onTap: _openSectionA,
        ),
        StudioSectionTile(
          title: 'B — Spaces & rooms',
          summary:
              '${_draft.rooms.length} rooms · ${_draft.spaceTemplate} · '
              '${_draft.parkingCarCount}-car ${_draft.parkingType}',
          hasError: _sectionHasError(const [
            'space_template',
            'rooms',
            'parking',
            'special_spaces',
            'pool',
          ]),
          onTap: _openSectionB,
        ),
        StudioSectionTile(
          title: 'C — Exterior',
          summary:
              '${_draft.architecturalStyle} · ${_draft.facadePrimary}',
          hasError: _sectionHasError(const [
            'architectural_style',
            'facade_primary',
            'facade_accent',
            'roof_type',
            'window_frame',
            'glazing_type',
          ]),
          onTap: _openSectionC,
        ),
        StudioSectionTile(
          title: 'D — Interior',
          summary:
              '${_draft.flooringType} · ${_draft.wallFinish} · '
              '${_draft.ceilingHeightM} m',
          hasError: _sectionHasError(const [
            'flooring_type',
            'flooring_tone',
            'wall_finish',
            'wall_color_tone',
            'ceiling_type',
            'ceiling_height_m',
          ]),
          onTap: _openSectionD,
        ),
        StudioSectionTile(
          title: 'E — Outputs',
          summary: _draft.outputs.isEmpty
              ? 'Choose what to generate'
              : _draft.outputs.join(', '),
          hasError: _sectionHasError(const [
            'outputs',
            'exterior_views',
            'interior_views',
          ]),
          onTap: _openSectionE,
        ),
        StudioSectionTile(
          title: 'F — Custom brief',
          summary: _draft.customBrief.trim().isEmpty &&
                  _draft.instructions.trim().isEmpty
              ? 'Optional notes for the AI'
              : (_draft.customBrief.trim().isNotEmpty
                  ? _draft.customBrief
                  : _draft.instructions),
          hasError: _sectionHasError(const ['custom_brief', 'instructions']),
          onTap: _openSectionF,
        ),
      ],
    );
  }

  Widget _submitBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 8.uh, 16.w, 12.uh),
        child: SizedBox(
          width: double.infinity,
          height: 50.uh,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A2A4F),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.ur),
              ),
            ),
            child: _submitting
                ? SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Generate',
                    style: GoogleFonts.poppins(
                      fontSize: 15.usp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46.uh,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A2A4F),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.ur),
          ),
        ),
        child: const Text('Done'),
      ),
    );
  }
}

class _SectionAEditor extends StatefulWidget {
  const _SectionAEditor({
    required this.config,
    required this.draft,
    required this.onDone,
  });

  final DrawingStudioConfig config;
  final DrawingStudioFormDraft draft;
  final VoidCallback onDone;

  @override
  State<_SectionAEditor> createState() => _SectionAEditorState();
}

class _SectionAEditorState extends State<_SectionAEditor> {
  late final TextEditingController _name;
  late final TextEditingController _plotArea;
  late final TextEditingController _plotLen;
  late final TextEditingController _plotWidth;
  late final TextEditingController _floors;
  late String _type;
  late String _basement;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _name = TextEditingController(text: d.projectName);
    _plotArea = TextEditingController(text: d.plotAreaM2.toStringAsFixed(0));
    _plotLen = TextEditingController(
      text: d.plotLengthM?.toStringAsFixed(0) ?? '',
    );
    _plotWidth = TextEditingController(
      text: d.plotWidthM?.toStringAsFixed(0) ?? '',
    );
    _floors = TextEditingController(text: '${d.numberOfFloors}');
    _type = d.projectType;
    _basement = d.basement;
  }

  @override
  void dispose() {
    _name.dispose();
    _plotArea.dispose();
    _plotLen.dispose();
    _plotWidth.dispose();
    _floors.dispose();
    super.dispose();
  }

  void _save() {
    final d = widget.draft;
    d.projectName = _name.text;
    d.projectType = _type;
    d.plotAreaM2 = double.tryParse(_plotArea.text) ?? d.plotAreaM2;
    d.plotLengthM =
        _plotLen.text.trim().isEmpty ? null : double.tryParse(_plotLen.text);
    d.plotWidthM = _plotWidth.text.trim().isEmpty
        ? null
        : double.tryParse(_plotWidth.text);
    d.numberOfFloors = int.tryParse(_floors.text) ?? d.numberOfFloors;
    d.basement = _basement;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final d = widget.draft;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _name,
          decoration: studioFieldDecoration(
            label: 'Project name',
            errorText: d.errorFor('project_name'),
          ),
        ),
        SizedBox(height: 10.uh),
        StudioEnumDropdown(
          config: config,
          enumField: 'project_type',
          value: _type,
          label: 'Type',
          errorText: d.errorFor('project_type'),
          fallbackKeys: const [
            'villa',
            'townhouse',
            'apartment_building',
            'commercial',
            'mixed_use',
          ],
          onChanged: (v) => setState(() => _type = v),
        ),
        TextFormField(
          controller: _plotArea,
          keyboardType: TextInputType.number,
          decoration: studioFieldDecoration(
            label: 'Plot area m²',
            errorText: d.errorFor('plot_area_m2'),
          ),
        ),
        SizedBox(height: 10.uh),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _plotLen,
                keyboardType: TextInputType.number,
                decoration: studioFieldDecoration(
                  label: 'Length m',
                  errorText: d.errorFor('plot_length_m'),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: TextFormField(
                controller: _plotWidth,
                keyboardType: TextInputType.number,
                decoration: studioFieldDecoration(
                  label: 'Width m',
                  errorText: d.errorFor('plot_width_m'),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.uh),
        TextFormField(
          controller: _floors,
          keyboardType: TextInputType.number,
          decoration: studioFieldDecoration(
            label: 'Floors',
            errorText: d.errorFor('number_of_floors'),
          ),
        ),
        SizedBox(height: 10.uh),
        StudioEnumDropdown(
          config: config,
          enumField: 'basement',
          value: _basement,
          label: 'Basement',
          errorText: d.errorFor('basement'),
          fallbackKeys: const [
            'none',
            'storage_only',
            'full_parking',
            'full_livable',
          ],
          onChanged: (v) => setState(() => _basement = v),
        ),
        SizedBox(height: 8.uh),
        _DoneButton(onPressed: _save),
      ],
    );
  }
}

class _SectionBEditor extends StatefulWidget {
  const _SectionBEditor({
    required this.config,
    required this.draft,
    required this.onDone,
  });

  final DrawingStudioConfig config;
  final DrawingStudioFormDraft draft;
  final VoidCallback onDone;

  @override
  State<_SectionBEditor> createState() => _SectionBEditorState();
}

class _SectionBEditorState extends State<_SectionBEditor> {
  late String _template;
  late List<DrawingStudioRoomDraft> _rooms;
  late List<String> _special;
  late bool _pool;
  late final TextEditingController _parkingCount;
  late String _parkingType;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _template = d.spaceTemplate;
    _rooms = d.rooms
        .map((r) => DrawingStudioRoomDraft.fromJson(r.toJson()))
        .toList();
    _special = [...d.specialSpaces];
    _pool = d.poolEnabled;
    _parkingCount = TextEditingController(text: '${d.parkingCarCount}');
    _parkingType = d.parkingType;
  }

  @override
  void dispose() {
    _parkingCount.dispose();
    super.dispose();
  }

  Future<void> _onTemplateChanged(String id) async {
    if (_rooms.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace rooms?'),
          content: const Text(
            'Selecting this template will replace your current room list.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _template = id;
      widget.draft.spaceTemplate = id;
      widget.draft.applyTemplateRooms(widget.config);
      widget.draft.ensureMinimumRooms();
      _rooms = widget.draft.rooms
          .map((r) => DrawingStudioRoomDraft.fromJson(r.toJson()))
          .toList();
    });
  }

  Future<void> _editRoom(int? index) async {
    final existing =
        index == null ? DrawingStudioRoomDraft() : _rooms[index];
    DrawingStudioRoomDraft? edited;
    await showStudioSmartPopup(
      context: context,
      title: 'Room',
      builder: (context, close) => _RoomEditor(
        config: widget.config,
        initial: existing,
        onSave: (room) {
          edited = room;
          close();
        },
      ),
    );
    if (edited != null) {
      setState(() {
        if (index == null) {
          _rooms.add(edited!);
        } else {
          _rooms[index] = edited!;
        }
      });
    }
  }

  void _save() {
    final d = widget.draft;
    d.spaceTemplate = _template;
    d.rooms = _rooms;
    d.specialSpaces = _special;
    d.poolEnabled = _pool;
    d.parkingCarCount =
        int.tryParse(_parkingCount.text) ?? d.parkingCarCount;
    d.parkingType = _parkingType;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final keys = [
      ...config.templates.keys,
      if (!config.templates.containsKey('custom')) 'custom',
    ];
    final templateValue =
        keys.contains(_template) ? _template : keys.first;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(templateValue),
          isExpanded: true,
          initialValue: templateValue,
          decoration: studioFieldDecoration(
            label: 'Space template',
            errorText: widget.draft.errorFor('space_template'),
          ),
          selectedItemBuilder: (context) => [
            for (final key in keys)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  key == 'custom' ? 'Custom' : config.templateName(key),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          items: [
            for (final key in keys)
              DropdownMenuItem(
                value: key,
                child: Text(
                  key == 'custom' ? 'Custom' : config.templateName(key),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) _onTemplateChanged(v);
          },
        ),
        SizedBox(height: 8.uh),
        for (var i = 0; i < _rooms.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _rooms[i].name.isEmpty ? 'Untitled room' : _rooms[i].name,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13.usp,
              ),
            ),
            subtitle: Text(
              '${config.enumLabel('room_category', _rooms[i].category)} · '
              '${_rooms[i].areaM2.toStringAsFixed(0)} m²',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => setState(() => _rooms.removeAt(i)),
            ),
            onTap: () => _editRoom(i),
          ),
        TextButton.icon(
          onPressed: () => _editRoom(null),
          icon: const Icon(Icons.add),
          label: const Text('Add room'),
        ),
        SizedBox(height: 8.uh),
        Text('Special spaces', style: _label),
        SizedBox(height: 6.uh),
        StudioChipMultiSelect(
          config: config,
          enumField: 'special_spaces',
          selected: _special,
          fallbackKeys: const [
            'majlis',
            'driver_room',
            'prayer_room',
            'home_office',
            'gym',
            'outdoor_kitchen',
            'store_room',
            'home_cinema',
            'nanny_room',
          ],
          onChanged: (v) => setState(() => _special = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pool'),
          value: _pool,
          onChanged: (v) => setState(() => _pool = v),
        ),
        TextFormField(
          controller: _parkingCount,
          keyboardType: TextInputType.number,
          decoration: studioFieldDecoration(
            label: 'Parking cars',
            errorText: widget.draft.errorFor('parking'),
          ),
        ),
        SizedBox(height: 10.uh),
        StudioEnumDropdown(
          config: config,
          enumField: 'parking_type',
          value: _parkingType,
          label: 'Parking type',
          fallbackKeys: const ['open', 'covered', 'garage', 'basement'],
          onChanged: (v) => setState(() => _parkingType = v),
        ),
        _DoneButton(onPressed: _save),
      ],
    );
  }

  TextStyle get _label => GoogleFonts.poppins(
        fontSize: 12.usp,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1A2A4F),
      );
}

class _RoomEditor extends StatefulWidget {
  const _RoomEditor({
    required this.config,
    required this.initial,
    required this.onSave,
  });

  final DrawingStudioConfig config;
  final DrawingStudioRoomDraft initial;
  final ValueChanged<DrawingStudioRoomDraft> onSave;

  @override
  State<_RoomEditor> createState() => _RoomEditorState();
}

class _RoomEditorState extends State<_RoomEditor> {
  late final TextEditingController _name;
  late final TextEditingController _nameAr;
  late final TextEditingController _area;
  late String _category;
  late String _floor;
  late bool _ensuite;
  late bool _balcony;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _name = TextEditingController(text: r.name);
    _nameAr = TextEditingController(text: r.nameAr);
    _area = TextEditingController(text: r.areaM2.toStringAsFixed(0));
    _category = r.category;
    _floor = r.floorLevel;
    _ensuite = r.hasEnsuite;
    _balcony = r.hasBalcony;
  }

  @override
  void dispose() {
    _name.dispose();
    _nameAr.dispose();
    _area.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _name,
          decoration: studioFieldDecoration(label: 'Name'),
        ),
        SizedBox(height: 10.uh),
        TextFormField(
          controller: _nameAr,
          decoration: studioFieldDecoration(label: 'Name (AR)'),
        ),
        SizedBox(height: 10.uh),
        StudioEnumDropdown(
          config: widget.config,
          enumField: 'room_category',
          value: _category,
          label: 'Category',
          fallbackKeys: const [
            'bedroom',
            'bathroom',
            'living',
            'dining',
            'kitchen',
            'majlis',
            'service',
            'circulation',
            'outdoor',
            'special',
          ],
          onChanged: (v) => setState(() => _category = v),
        ),
        StudioEnumDropdown(
          config: widget.config,
          enumField: 'floor_level',
          value: _floor,
          label: 'Floor',
          fallbackKeys: const [
            'basement',
            'ground',
            'first',
            'second',
            'third',
            'roof',
          ],
          onChanged: (v) => setState(() => _floor = v),
        ),
        TextFormField(
          controller: _area,
          keyboardType: TextInputType.number,
          decoration: studioFieldDecoration(label: 'Area m²'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ensuite'),
          value: _ensuite,
          onChanged: (v) => setState(() => _ensuite = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Balcony'),
          value: _balcony,
          onChanged: (v) => setState(() => _balcony = v),
        ),
        _DoneButton(
          onPressed: () {
            widget.onSave(
              DrawingStudioRoomDraft(
                roomId: widget.initial.roomId,
                name: _name.text,
                nameAr: _nameAr.text,
                category: _category,
                floorLevel: _floor,
                areaM2: double.tryParse(_area.text) ?? 12,
                hasEnsuite: _ensuite,
                hasBalcony: _balcony,
                notes: widget.initial.notes,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SectionCEditor extends StatefulWidget {
  const _SectionCEditor({
    required this.config,
    required this.draft,
    required this.onDone,
  });

  final DrawingStudioConfig config;
  final DrawingStudioFormDraft draft;
  final VoidCallback onDone;

  @override
  State<_SectionCEditor> createState() => _SectionCEditorState();
}

class _SectionCEditorState extends State<_SectionCEditor> {
  late String _style;
  late String _primary;
  late String _accent;
  late String _roof;
  late String _window;
  late String _glazing;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _style = d.architecturalStyle;
    _primary = d.facadePrimary;
    _accent = d.facadeAccent;
    _roof = d.roofType;
    _window = d.windowFrame;
    _glazing = d.glazingType;
  }

  void _save() {
    final d = widget.draft;
    d.architecturalStyle = _style;
    d.facadePrimary = _primary;
    d.facadeAccent = _accent;
    d.roofType = _roof;
    d.windowFrame = _window;
    d.glazingType = _glazing;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StudioEnumDropdown(
          config: config,
          enumField: 'architectural_style',
          value: _style,
          label: 'Style',
          fallbackKeys: const [
            'modern_contemporary',
            'modern_arabic',
            'neo_classical',
            'minimalist',
            'mediterranean',
            'tropical_modern',
          ],
          onChanged: (v) => setState(() => _style = v),
        ),
        StudioEnumDropdown(
          config: config,
          enumField: 'facade_primary',
          value: _primary,
          label: 'Facade primary',
          fallbackKeys: const [
            'natural_stone',
            'concrete_render',
            'glass_curtain_wall',
            'composite_cladding',
            'brick',
          ],
          onChanged: (v) => setState(() => _primary = v),
        ),
        StudioEnumDropdown(
          config: config,
          enumField: 'facade_accent',
          value: _accent,
          label: 'Facade accent',
          fallbackKeys: const [
            'none',
            'wood_cladding',
            'aluminum_dark',
            'aluminum_gold',
            'mashrabiya_screen',
            'corten_steel',
          ],
          onChanged: (v) => setState(() => _accent = v),
        ),
        StudioEnumDropdown(
          config: config,
          enumField: 'roof_type',
          value: _roof,
          label: 'Roof',
          fallbackKeys: const [
            'flat_parapet',
            'flat_with_pergola',
            'pitched_tile',
            'butterfly',
            'mixed',
          ],
          onChanged: (v) => setState(() => _roof = v),
        ),
        StudioEnumDropdown(
          config: config,
          enumField: 'window_frame',
          value: _window,
          label: 'Window frame',
          fallbackKeys: const [
            'aluminum_dark',
            'aluminum_light',
            'wood',
            'upvc',
          ],
          onChanged: (v) => setState(() => _window = v),
        ),
        StudioEnumDropdown(
          config: config,
          enumField: 'glazing_type',
          value: _glazing,
          label: 'Glazing',
          fallbackKeys: const ['clear_double', 'tinted', 'low_e', 'triple'],
          onChanged: (v) => setState(() => _glazing = v),
        ),
        _DoneButton(onPressed: _save),
      ],
    );
  }
}

class _SectionDEditor extends StatefulWidget {
  const _SectionDEditor({
    required this.config,
    required this.draft,
    required this.onDone,
  });

  final DrawingStudioConfig config;
  final DrawingStudioFormDraft draft;
  final VoidCallback onDone;

  @override
  State<_SectionDEditor> createState() => _SectionDEditorState();
}

class _SectionDEditorState extends State<_SectionDEditor> {
  late String _flooring;
  late String _tone;
  late String _wall;
  late String _wallTone;
  late String _ceiling;
  late final TextEditingController _height;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _flooring = d.flooringType;
    _tone = d.flooringTone;
    _wall = d.wallFinish;
    _wallTone = d.wallColorTone;
    _ceiling = d.ceilingType;
    _height = TextEditingController(text: d.ceilingHeightM.toString());
  }

  @override
  void dispose() {
    _height.dispose();
    super.dispose();
  }

  void _save() {
    final d = widget.draft;
    d.flooringType = _flooring;
    d.flooringTone = _tone;
    d.wallFinish = _wall;
    d.wallColorTone = _wallTone;
    d.ceilingType = _ceiling;
    d.ceilingHeightM = double.tryParse(_height.text) ?? d.ceilingHeightM;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StudioEnumDropdown(
          config: config,
          enumField: 'flooring_type',
          value: _flooring,
          label: 'Flooring',
          fallbackKeys: const [
            'porcelain_large',
            'marble',
            'wood',
            'tile',
          ],
          onChanged: (v) => setState(() => _flooring = v),
        ),
        StudioEnumDropdown(
          config: config,
          enumField: 'flooring_tone',
          value: _tone,
          label: 'Flooring tone',
          fallbackKeys: const ['light', 'medium', 'dark'],
          onChanged: (v) => setState(() => _tone = v),
        ),
        StudioEnumDropdown(
          config: config,
          enumField: 'wall_finish',
          value: _wall,
          label: 'Wall finish',
          fallbackKeys: const [
            'paint_matte',
            'paint_eggshell',
            'wallpaper',
            'stone_accent',
          ],
          onChanged: (v) => setState(() => _wall = v),
        ),
        StudioEnumDropdown(
          config: config,
          enumField: 'wall_color_tone',
          value: _wallTone,
          label: 'Wall color',
          fallbackKeys: const ['warm_white', 'cool_white', 'beige', 'grey'],
          onChanged: (v) => setState(() => _wallTone = v),
        ),
        StudioEnumDropdown(
          config: config,
          enumField: 'ceiling_type',
          value: _ceiling,
          label: 'Ceiling',
          fallbackKeys: const [
            'gypsum_bulkhead',
            'flat',
            'coffered',
            'exposed',
          ],
          onChanged: (v) => setState(() => _ceiling = v),
        ),
        TextFormField(
          controller: _height,
          keyboardType: TextInputType.number,
          decoration: studioFieldDecoration(
            label: 'Ceiling height m',
            errorText: widget.draft.errorFor('ceiling_height_m'),
          ),
        ),
        SizedBox(height: 10.uh),
        _DoneButton(onPressed: _save),
      ],
    );
  }
}

class _SectionEEditor extends StatefulWidget {
  const _SectionEEditor({
    required this.config,
    required this.draft,
    required this.onDone,
  });

  final DrawingStudioConfig config;
  final DrawingStudioFormDraft draft;
  final VoidCallback onDone;

  @override
  State<_SectionEEditor> createState() => _SectionEEditorState();
}

class _SectionEEditorState extends State<_SectionEEditor> {
  late List<String> _outputs;
  late List<String> _exterior;
  late List<String> _interior;

  @override
  void initState() {
    super.initState();
    _outputs = [...widget.draft.outputs];
    _exterior = [...widget.draft.exteriorViews];
    _interior = [...widget.draft.interiorViews];
  }

  void _save() {
    widget.draft.outputs = _outputs;
    widget.draft.exteriorViews = _exterior;
    widget.draft.interiorViews = _interior;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudioChipMultiSelect(
          config: config,
          enumField: 'outputs',
          selected: _outputs,
          errorText: widget.draft.errorFor('outputs'),
          fallbackKeys: const [
            'floor_plan_2d',
            'floor_plan_3d',
            'exterior_3d',
            'interior_3d',
            'section_drawing',
            'takeoff',
          ],
          onChanged: (v) => setState(() => _outputs = v),
        ),
        if (_outputs.contains('exterior_3d')) ...[
          SizedBox(height: 12.uh),
          Text('Exterior views', style: _label),
          SizedBox(height: 6.uh),
          StudioChipMultiSelect(
            config: config,
            enumField: 'exterior_views',
            selected: _exterior,
            fallbackKeys: const [
              'main_entrance',
              'rear',
              'side',
              'birds_eye',
            ],
            onChanged: (v) => setState(() => _exterior = v),
          ),
        ],
        if (_outputs.contains('interior_3d')) ...[
          SizedBox(height: 12.uh),
          Text('Interior views', style: _label),
          SizedBox(height: 6.uh),
          StudioChipMultiSelect(
            config: config,
            enumField: 'interior_views',
            selected: _interior,
            fallbackKeys: const [
              'living_area',
              'kitchen',
              'master_bedroom',
              'majlis',
            ],
            onChanged: (v) => setState(() => _interior = v),
          ),
        ],
        for (final key in _outputs)
          if (config.costHint(key) != null)
            Padding(
              padding: EdgeInsets.only(top: 6.uh),
              child: Text(
                '${config.enumLabel('outputs', key)}: ${config.costHint(key)}',
                style: GoogleFonts.poppins(
                  fontSize: 11.usp,
                  color: const Color(0xFF7A849C),
                ),
              ),
            ),
        SizedBox(height: 12.uh),
        _DoneButton(onPressed: _save),
      ],
    );
  }

  TextStyle get _label => GoogleFonts.poppins(
        fontSize: 12.usp,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1A2A4F),
      );
}

class _SectionFEditor extends StatefulWidget {
  const _SectionFEditor({
    required this.draft,
    required this.onDone,
  });

  final DrawingStudioFormDraft draft;
  final VoidCallback onDone;

  @override
  State<_SectionFEditor> createState() => _SectionFEditorState();
}

class _SectionFEditorState extends State<_SectionFEditor> {
  late final TextEditingController _brief;
  late final TextEditingController _instructions;

  @override
  void initState() {
    super.initState();
    _brief = TextEditingController(text: widget.draft.customBrief);
    _instructions = TextEditingController(text: widget.draft.instructions);
  }

  @override
  void dispose() {
    _brief.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _save() {
    widget.draft.customBrief = _brief.text;
    widget.draft.instructions = _instructions.text;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: _brief,
          maxLines: 4,
          maxLength: 2000,
          decoration: studioFieldDecoration(
            label: 'Custom brief (optional)',
            errorText: widget.draft.errorFor('custom_brief'),
          ),
        ),
        SizedBox(height: 8.uh),
        TextFormField(
          controller: _instructions,
          maxLines: 2,
          decoration: studioFieldDecoration(
            label: 'Extra instructions (optional)',
          ),
        ),
        SizedBox(height: 10.uh),
        _DoneButton(onPressed: _save),
      ],
    );
  }
}
