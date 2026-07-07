# Guard Pods-Runner-frameworks.sh so a not-yet-built framework does not abort
# the embed phase with: `source: unbound variable` (bash set -u).
FRAMEWORKS_SCRIPT_MARKER = 'EL_RACE_SKIP_MISSING_FRAMEWORK'

def patch_pods_runner_frameworks_script(installer)
  script_path = File.join(
    installer.sandbox.root,
    'Target Support Files',
    'Pods-Runner',
    'Pods-Runner-frameworks.sh'
  )
  patch_pods_frameworks_script_file(script_path)
end

def patch_pods_frameworks_script_file(script_path)
  return unless File.exist?(script_path)

  content = File.read(script_path)
  return if content.include?(FRAMEWORKS_SCRIPT_MARKER)

  needle = <<'NEEDLE'.chomp
  elif [ -r "$1" ]; then
    local source="$1"
  fi

  local destination="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
NEEDLE

  replacement = <<'REPL'.chomp
  elif [ -r "$1" ]; then
    local source="$1"
  fi

  # EL_RACE_SKIP_MISSING_FRAMEWORK
  if [ -z "${source:-}" ]; then
    echo "warning: [CP] Skip missing framework '$1'"
    return 0
  fi

  local destination="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
REPL

  unless content.include?(needle)
    puts "Podfile: Pods-Runner-frameworks.sh pattern missing — skip patch"
    return
  end

  File.write(script_path, content.sub(needle, replacement))
  puts 'Podfile: patched Pods-Runner-frameworks.sh (missing framework guard)'
end
