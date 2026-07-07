# Applies a safe AVCaptureVideoDataOutput pixel-format selection patch to
# camera_avfoundation so iOS devices do not crash on unsupported formats.
PATCH_MARKER = 'EL_RACE_CAMERA_PIXFMT_PATCH'

def patch_default_camera(swift_path)
  return unless File.exist?(swift_path)

  content = File.read(swift_path)
  return if content.include?(PATCH_MARKER)

  old_did_set = <<~'OLD'
    var videoFormat: FourCharCode = kCVPixelFormatType_32BGRA {
      didSet {
        let resolvedVideoFormat = DefaultCamera.supportedPixelFormat(videoFormat, for: captureVideoOutput.avOutput)
        captureVideoOutput.videoSettings = [
          kCVPixelBufferPixelFormatTypeKey as String: resolvedVideoFormat
        ]
      }
    }
  OLD

  old_did_set_alt = <<~'OLD'
    var videoFormat: FourCharCode = kCVPixelFormatType_32BGRA {
      didSet {
        captureVideoOutput.videoSettings = [
          kCVPixelBufferPixelFormatTypeKey as String: videoFormat
        ]
      }
    }
  OLD

  new_did_set = <<~'NEW'
    var videoFormat: FourCharCode = kCVPixelFormatType_32BGRA {
      didSet {
        _ = DefaultCamera.configureVideoOutput(
          captureVideoOutput.avOutput,
          preferredFormat: videoFormat
        )
      }
    }
  NEW

  old_helper = <<~'OLD'
    private static func supportedPixelFormat(
      _ requestedFormat: FourCharCode,
      for captureVideoOutput: AVCaptureVideoDataOutput
    ) -> FourCharCode {
      let availableFormats = captureVideoOutput.availableVideoPixelFormatTypes
      let flutterSupportedFormats: [FourCharCode] = [
        kCVPixelFormatType_32BGRA,
        kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
      ]

      if flutterSupportedFormats.contains(requestedFormat),
         availableFormats.contains(requestedFormat) {
        return requestedFormat
      }

      for format in flutterSupportedFormats where availableFormats.contains(format) {
        return format
      }

      return requestedFormat
    }
  OLD

  new_helper = <<~'NEW'
    // EL_RACE_CAMERA_PIXFMT_PATCH
    private static func configureVideoOutput(
      _ captureVideoOutput: AVCaptureVideoDataOutput,
      preferredFormat: FourCharCode
    ) -> FourCharCode {
      let flutterSupportedFormats: [FourCharCode] = [
        kCVPixelFormatType_32BGRA,
        kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
      ]
      let availableFormats = captureVideoOutput.availableVideoPixelFormatTypes
      let candidates = [preferredFormat] + flutterSupportedFormats.filter { $0 != preferredFormat }

      if let resolved = candidates.first(where: { availableFormats.contains($0) }) {
        captureVideoOutput.videoSettings = [
          kCVPixelBufferPixelFormatTypeKey as String: resolved
        ]
        return resolved
      }

      captureVideoOutput.videoSettings = [:]
      return preferredFormat
    }
  NEW

  old_create = <<~'OLD'
        let captureVideoOutput = AVCaptureVideoDataOutput()
        let resolvedVideoFormat = supportedPixelFormat(videoFormat, for: captureVideoOutput)
        captureVideoOutput.videoSettings = [
          kCVPixelBufferPixelFormatTypeKey as String: resolvedVideoFormat
        ]
  OLD

  new_create = <<~'NEW'
        let captureVideoOutput = AVCaptureVideoDataOutput()
        _ = configureVideoOutput(captureVideoOutput, preferredFormat: videoFormat)
  NEW

  replacements = [
    [old_did_set, new_did_set],
    [old_did_set_alt, new_did_set],
    [old_helper, new_helper],
    [old_create, new_create],
  ]

  replacements.each do |old, new|
    next unless content.include?(old)
    content = content.sub(old, new)
  end

  unless content.include?(PATCH_MARKER)
    raise "camera_avfoundation patch failed: expected block not found in #{swift_path}"
  end

  File.write(swift_path, content)
end

def camera_avfoundation_default_camera_paths(installer)
  pod_root = File.dirname(File.realpath(__FILE__))
  ios_root = File.expand_path('..', pod_root)
  paths = []

  [
    File.join(ios_root, '.symlinks', 'plugins', 'camera_avfoundation', 'ios', 'camera_avfoundation', 'Sources', 'camera_avfoundation', 'DefaultCamera.swift'),
    File.join(ios_root, 'Pods', '**', 'DefaultCamera.swift'),
    File.join(Dir.home, '.pub-cache', 'hosted', 'pub.dev', 'camera_avfoundation-*', 'ios', 'camera_avfoundation', 'Sources', 'camera_avfoundation', 'DefaultCamera.swift'),
  ].each do |pattern|
    if pattern.include?('*')
      paths.concat(Dir.glob(pattern))
    elsif File.exist?(pattern)
      paths << pattern
    end
  end

  if installer.respond_to?(:sandbox) && installer.sandbox.respond_to?(:root)
    paths.concat(
      Dir.glob(
        File.join(
          installer.sandbox.root,
          '**',
          'camera_avfoundation',
          '**',
          'DefaultCamera.swift'
        )
      )
    )
  end

  paths.uniq.select { File.exist?(_1) }
end

if __FILE__ == $PROGRAM_NAME
  camera_avfoundation_default_camera_paths(nil).each do |swift_path|
    patch_default_camera(swift_path)
    puts "Patched #{swift_path}"
  end
end
