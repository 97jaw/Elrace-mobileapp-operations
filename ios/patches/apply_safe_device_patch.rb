# Fixes safe_device compile error on Xcode 16+:
# "Initializer element is not a compile-time constant" for static NSArray literals.
PATCH_MARKER = 'EL_RACE_SAFE_DEVICE_CONST_PATCH'

def patch_safe_device_jailbreak_detection(m_path)
  return unless File.exist?(m_path)

  content = File.read(m_path)
  return if content.include?(PATCH_MARKER)

  old_block = <<~'OLD'
    /// Paths under /var or /private/var check literally
    static NSArray<NSString *> * const jailbreakVarPaths = @[
        @"/private/var/lib/apt",
        @"/private/var/tmp/cydia.log",
        @"/private/var/lib/dpkg",
        @"/var/cache/apt",
        @"/var/lib/cydia",
        @"/var/log/syslog",
        @"/var/lib/dpkg/status",
        // Palera1n rootless jailbreak indicators
        @"/var/jb/.installed_palera1n",
        @"/var/jb/usr/bin/su",
        @"/var/jb/usr/lib/apt"
    ];

    /// Paths checked literally and with /var/jb prefix
    static NSArray<NSString *> * const jailbreakNonVarPaths = @[
        // Cydia and package managers
        @"/Applications/Cydia.app",
        @"/Applications/RockApp.app",
        @"/Applications/Icy.app",
        @"/Applications/WinterBoard.app",
        @"/Applications/SBSettings.app",
        @"/Applications/blackra1n.app",
        @"/Applications/IntelliScreen.app",
        @"/Applications/Snoop-itConfig.app",
        
        // System binaries commonly found on jailbroken devices
        // Note: /bin/sh is intentionally excluded — it exists on stock iOS 16+ devices
        @"/bin/bash",
        @"/usr/sbin/sshd",
        @"/usr/libexec/sftp-server",
        @"/usr/libexec/ssh-keysign",
        
        // MobileSubstrate and related files
        @"/Library/MobileSubstrate/MobileSubstrate.dylib",
        @"/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
        @"/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
        
        // APT package manager
        @"/etc/apt",
        
        // Launch daemons
        @"/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
        @"/System/Library/LaunchDaemons/com.ikey.bbot.plist",
        
        // Additional common jailbreak paths
        @"/usr/sbin/frida-server",
        @"/usr/bin/cycript",
        @"/usr/local/bin/cycript",
        @"/usr/lib/libcycript.dylib",
        @"/etc/ssh/sshd_config",
        @"/Applications/Terminal.app",
        @"/Applications/iFile.app",
        @"/Applications/Filza.app",
        @"/usr/bin/dpkg",
        @"/usr/sbin/dpkg"
    ];

    /// Common jailbreak tool and application paths
    + (NSArray<NSString *> *)jailbreakPaths {
        static NSArray<NSString *> *paths = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSMutableArray<NSString *> *expanded = [NSMutableArray array];
            [expanded addObjectsFromArray:jailbreakVarPaths];
            for (NSString *path in jailbreakNonVarPaths) {
                [expanded addObject:path];
                [expanded addObject:[@"/var/jb" stringByAppendingString:path]];
            }
            paths = [expanded copy];
        });
        return paths;
    }
  OLD

  new_block = <<~'NEW'
    // EL_RACE_SAFE_DEVICE_CONST_PATCH — file-scope NSArray literals are not compile-time constants on Xcode 16+.
    /// Common jailbreak tool and application paths
    + (NSArray<NSString *> *)jailbreakPaths {
        static NSArray<NSString *> *paths = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSArray<NSString *> *jailbreakVarPaths = @[
                @"/private/var/lib/apt",
                @"/private/var/tmp/cydia.log",
                @"/private/var/lib/dpkg",
                @"/var/cache/apt",
                @"/var/lib/cydia",
                @"/var/log/syslog",
                @"/var/lib/dpkg/status",
                @"/var/jb/.installed_palera1n",
                @"/var/jb/usr/bin/su",
                @"/var/jb/usr/lib/apt"
            ];
            NSArray<NSString *> *jailbreakNonVarPaths = @[
                @"/Applications/Cydia.app",
                @"/Applications/RockApp.app",
                @"/Applications/Icy.app",
                @"/Applications/WinterBoard.app",
                @"/Applications/SBSettings.app",
                @"/Applications/blackra1n.app",
                @"/Applications/IntelliScreen.app",
                @"/Applications/Snoop-itConfig.app",
                @"/bin/bash",
                @"/usr/sbin/sshd",
                @"/usr/libexec/sftp-server",
                @"/usr/libexec/ssh-keysign",
                @"/Library/MobileSubstrate/MobileSubstrate.dylib",
                @"/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
                @"/Library/MobileSubstrate/DynamicLibraries/Veency.plist",
                @"/etc/apt",
                @"/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
                @"/System/Library/LaunchDaemons/com.ikey.bbot.plist",
                @"/usr/sbin/frida-server",
                @"/usr/bin/cycript",
                @"/usr/local/bin/cycript",
                @"/usr/lib/libcycript.dylib",
                @"/etc/ssh/sshd_config",
                @"/Applications/Terminal.app",
                @"/Applications/iFile.app",
                @"/Applications/Filza.app",
                @"/usr/bin/dpkg",
                @"/usr/sbin/dpkg"
            ];
            NSMutableArray<NSString *> *expanded = [NSMutableArray array];
            [expanded addObjectsFromArray:jailbreakVarPaths];
            for (NSString *path in jailbreakNonVarPaths) {
                [expanded addObject:path];
                [expanded addObject:[@"/var/jb" stringByAppendingString:path]];
            }
            paths = [expanded copy];
        });
        return paths;
    }
  NEW

  unless content.include?(old_block)
    raise "safe_device patch failed: expected block not found in #{m_path}"
  end

  File.write(m_path, content.sub(old_block, new_block))
end

def safe_device_jailbreak_detection_paths(installer)
  pod_root = File.dirname(File.realpath(__FILE__))
  ios_root = File.expand_path('..', pod_root)
  paths = []

  [
    File.join(ios_root, '.symlinks', 'plugins', 'safe_device', 'ios', 'Classes', 'SafeDeviceJailbreakDetection.m'),
    File.join(ios_root, 'Pods', '**', 'SafeDeviceJailbreakDetection.m'),
    File.join(Dir.home, '.pub-cache', 'hosted', 'pub.dev', 'safe_device-*', 'ios', 'Classes', 'SafeDeviceJailbreakDetection.m'),
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
          'SafeDeviceJailbreakDetection.m'
        )
      )
    )
  end

  paths.uniq.select { File.exist?(_1) }
end

if __FILE__ == $PROGRAM_NAME
  safe_device_jailbreak_detection_paths(nil).each do |m_path|
    patch_safe_device_jailbreak_detection(m_path)
    puts "Patched #{m_path}"
  end
end
