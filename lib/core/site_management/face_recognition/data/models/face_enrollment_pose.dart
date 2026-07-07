/// Odoo `register_face_images` multipart field names (Phase C).
enum FaceEnrollmentPose {
  front('front_image'),
  left('left_image'),
  right('right_image'),
  up('up_image'),
  down('down_image');

  const FaceEnrollmentPose(this.multipartField);

  final String multipartField;

  static const int minimumRequired = 4;

  static const List<FaceEnrollmentPose> captureOrder = [
    FaceEnrollmentPose.front,
    FaceEnrollmentPose.left,
    FaceEnrollmentPose.right,
    FaceEnrollmentPose.up,
  ];

  String get instruction => switch (this) {
        FaceEnrollmentPose.front => 'Look straight at the camera',
        FaceEnrollmentPose.left => 'Turn your head slowly to the left',
        FaceEnrollmentPose.right => 'Turn your head slowly to the right',
        FaceEnrollmentPose.up => 'Tilt your head slightly up',
        FaceEnrollmentPose.down => 'Tilt your head slightly down',
      };

  String get shortLabel => switch (this) {
        FaceEnrollmentPose.front => 'Front',
        FaceEnrollmentPose.left => 'Left',
        FaceEnrollmentPose.right => 'Right',
        FaceEnrollmentPose.up => 'Up',
        FaceEnrollmentPose.down => 'Down',
      };

  /// [yaw] / [pitch] from ML Kit head euler angles (degrees).
  /// [frontCamera] — selfie preview mirrors yaw; accept both sign conventions.
  bool matchesHeadAngles({
    required double yaw,
    required double pitch,
    bool frontCamera = false,
  }) {
    return switch (this) {
      FaceEnrollmentPose.front =>
        yaw.abs() <= 15 && pitch.abs() <= 15,
      FaceEnrollmentPose.left =>
        yaw <= -6 || (frontCamera && yaw >= 6),
      FaceEnrollmentPose.right =>
        yaw >= 6 || (frontCamera && yaw <= -6),
      FaceEnrollmentPose.up => pitch >= 6,
      FaceEnrollmentPose.down => pitch <= -6,
    };
  }

  String poseHint({required double yaw, required double pitch, bool frontCamera = false}) {
    if (matchesHeadAngles(yaw: yaw, pitch: pitch, frontCamera: frontCamera)) {
      return instruction;
    }
    return switch (this) {
      FaceEnrollmentPose.front => 'Look straight at the camera',
      FaceEnrollmentPose.left => 'Turn a little more to your left',
      FaceEnrollmentPose.right => 'Turn a little more to your right',
      FaceEnrollmentPose.up => 'Tilt your head up a little more',
      FaceEnrollmentPose.down => 'Tilt your head down a little more',
    };
  }
}
