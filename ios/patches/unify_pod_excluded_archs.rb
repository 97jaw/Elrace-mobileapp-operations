# Unify EXCLUDED_ARCHS[sdk=iphonesimulator*] across Flutter plugin podspecs so
# CocoaPods can merge Pods-Runner xcconfigs (ML Kit = arm64, many plugins = i386).
PATCH_MARKER = 'EL_RACE_UNIFIED_SIM_ARCHS'
ARCH_KEY = 'EXCLUDED_ARCHS[sdk=iphonesimulator*]'

def patch_spec_xcconfigs!(spec, value)
  return unless spec.respond_to?(:attributes_hash)

  %w[pod_target_xcconfig user_target_xcconfig].each do |key|
    existing = spec.attributes_hash[key]
    next unless existing.is_a?(Hash)
    next unless existing.key?(ARCH_KEY)

    existing[ARCH_KEY] = value
  end

  spec.subspecs.each { |sub| patch_spec_xcconfigs!(sub, value) } if spec.respond_to?(:subspecs)
end

def unify_simulator_excluded_archs(value = 'arm64')
  ios_root = File.expand_path('..', __dir__)
  patched_files = []

  globs = [
    File.join(ios_root, '.symlinks', 'plugins', '**', '*.podspec'),
    File.join(ios_root, 'Pods', 'Local Podspecs', '*.json'),
  ]

  globs.each do |pattern|
    Dir.glob(pattern).each do |path|
      content = File.read(path)
      next unless content.include?('EXCLUDED_ARCHS[sdk=iphonesimulator*]')

      patched = content.gsub(
        /EXCLUDED_ARCHS\[sdk=iphonesimulator\*\](?:'|")?\s*=>\s*(?:'|")[^'"]+(?:'|")/,
        "EXCLUDED_ARCHS[sdk=iphonesimulator*]' => '#{value}'"
      )
      patched = patched.gsub(
        /"EXCLUDED_ARCHS\[sdk=iphonesimulator\*\]": "[^"]*"/,
        %("EXCLUDED_ARCHS[sdk=iphonesimulator*]": "#{value}")
      )
      next if patched == content

      File.write(path, patched)
      patched_files << path
    end
  end

  patched_files
end

def patch_pod_targets_excluded_archs!(installer, value = 'arm64')
  return unless installer.respond_to?(:pod_targets)

  installer.pod_targets.each do |pod_target|
    pod_target.specs.each { |spec| patch_spec_xcconfigs!(spec, value) }
  end
end

def patch_generated_pod_xcconfigs(installer, value = 'arm64')
  return unless installer.respond_to?(:sandbox)

  Dir.glob(
    File.join(installer.sandbox.root, 'Target Support Files', '**', '*.xcconfig')
  ).each do |path|
    content = File.read(path)
    next unless content.include?('EXCLUDED_ARCHS[sdk=iphonesimulator*]')

    patched = content.gsub(
      /EXCLUDED_ARCHS\[sdk=iphonesimulator\*\] = .*/,
      "EXCLUDED_ARCHS[sdk=iphonesimulator*] = #{value}"
    )
    File.write(path, patched) if patched != content
  end
end
