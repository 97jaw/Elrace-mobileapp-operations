import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_photo_cache.dart';
import 'package:flutter/material.dart';

/// List-row avatar: list payload → partner/employee id → detail `form_view`.
class ApprovalListAvatar extends StatefulWidget {
  const ApprovalListAvatar({
    super.key,
    required this.item,
    required this.kind,
    required this.size,
    this.initials,
    this.lazyLoadCategory,
  });

  final Map<dynamic, dynamic> item;
  final ApprovalAvatarKind kind;
  final double size;
  final String? initials;

  /// When set, loads the same photo used in the detail form if list API omitted it.
  final ApprovalListCategory? lazyLoadCategory;

  @override
  State<ApprovalListAvatar> createState() => _ApprovalListAvatarState();
}

class _ApprovalListAvatarState extends State<ApprovalListAvatar> {
  String _imageData = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _syncFromItem();
  }

  @override
  void didUpdateWidget(covariant ApprovalListAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item ||
        oldWidget.kind != widget.kind ||
        oldWidget.lazyLoadCategory != widget.lazyLoadCategory) {
      _syncFromItem();
    }
  }

  void _syncFromItem() {
    final next = ApprovalDisplayHelpers.pickImageUrl(widget.item, widget.kind);
    setState(() => _imageData = next);
    if (_imageData.isEmpty && widget.lazyLoadCategory != null) {
      _loadDetailPhoto();
    }
  }

  Future<void> _loadDetailPhoto() async {
    if (_loading || widget.lazyLoadCategory == null || !mounted) return;
    setState(() => _loading = true);

    final resolved = await ApprovalPhotoCache.resolve(
      widget.lazyLoadCategory!,
      widget.item,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (resolved.isNotEmpty) {
        _imageData = resolved;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    var imageData = _imageData;
    if (imageData.isEmpty && widget.lazyLoadCategory != null) {
      final cached = ApprovalPhotoCache.cachedPhoto(
        widget.lazyLoadCategory!,
        widget.item,
      );
      if (cached.isNotEmpty) {
        imageData = cached;
      }
    }

    return ApprovalDisplayHelpers.buildCircleAvatar(
      imageData: imageData,
      size: widget.size,
      initials: widget.initials,
    );
  }
}
