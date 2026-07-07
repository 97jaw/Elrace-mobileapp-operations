import 'package:flutter/foundation.dart';

/// Collapses the projects agreements panel from outside (e.g. backdrop tap).
class AgreementsPanelController {
  VoidCallback? _collapse;

  void bind(void Function() collapse) => _collapse = collapse;

  void unbind() => _collapse = null;

  void collapse() => _collapse?.call();
}
