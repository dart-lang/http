// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ffi' show Abi;
import 'dart:io';

/// The hardware architectures the Dart VM runs on.
class Architecture {
  /// This architecture as used in [Platform.version].
  final String dartPlatform;

  const Architecture._(this.dartPlatform);

  /// The architecture corresponding the substring of [Platform.version]
  /// describing the architecture.
  ///
  /// The [Platform.version] strings are formatted as follows:
  /// `<version> (<date>) on "<OS>_<Architecture>"`.
  factory Architecture.fromDartPlatform(String dartPlatform) =>
      values.where((element) => element.dartPlatform == dartPlatform).first;

  factory Architecture.fromAbi(Abi abi) => _abiToArch[abi]!;

  static const Architecture arm = Architecture._('arm');
  static const Architecture arm64 = Architecture._('arm64');
  static const Architecture ia32 = Architecture._('ia32');
  static const Architecture x64 = Architecture._('x64');

  /// Known values for [Architecture].
  static const List<Architecture> values = [
    arm,
    arm64,
    ia32,
    x64,
  ];

  static const _abiToArch = {
    Abi.androidArm: Architecture.arm,
    Abi.androidArm64: Architecture.arm64,
    Abi.androidIA32: Architecture.ia32,
    Abi.androidX64: Architecture.x64,
    Abi.fuchsiaArm64: Architecture.arm64,
    Abi.fuchsiaX64: Architecture.x64,
    Abi.iosArm: Architecture.arm,
    Abi.iosArm64: Architecture.arm64,
    Abi.iosX64: Architecture.x64,
    Abi.linuxArm: Architecture.arm,
    Abi.linuxArm64: Architecture.arm64,
    Abi.linuxIA32: Architecture.ia32,
    Abi.linuxX64: Architecture.x64,
    Abi.macosArm64: Architecture.arm64,
    Abi.macosX64: Architecture.x64,
    Abi.windowsArm64: Architecture.arm64,
    Abi.windowsIA32: Architecture.ia32,
    Abi.windowsX64: Architecture.x64,
  };

  /// The `CMAKE_ANDROID_ARCH_ABI` argument value for this [Architecture].
  String get cmakeAndroid => _architectureStringsCMakeAndroid[this]!;

  static const _architectureStringsCMakeAndroid = {
    Architecture.arm: "armeabi-v7a",
    Architecture.arm64: "arm64-v8a",
    Architecture.ia32: "x86",
    Architecture.x64: "x86_64",
  };

  /// The `CMAKE_OSX_ARCHITECTURES` argument value for this [Architecture].
  String get cmakeOsx => _architectureStringsCMakeOsx[this]!;

  static const _architectureStringsCMakeOsx = {
    Architecture.arm: "armv7",
    Architecture.arm64: "arm64",
    Architecture.ia32: "x86",
    Architecture.x64: "x86_64",
  };
}

/// The operating systems the Dart VM runs on.
class OS {
  /// This OS as used in [Platform.version]
  final String dartPlatform;

  const OS._(this.dartPlatform);

  /// The [OS] corresponding the substring of [Platform.version]
  /// describing the [OS].
  ///
  /// The [Platform.version] strings are formatted as follows:
  /// `<version> (<date>) on "<OS>_<Architecture>"`.
  factory OS.fromDartPlatform(String dartPlatform) =>
      values.where((element) => element.dartPlatform == dartPlatform).first;

  factory OS.fromAbi(Abi abi) => _abiToOS[abi]!;

  static const OS android = OS._('android');
  static const OS fuchsia = OS._('fuchsia');
  static const OS iOS = OS._('ios');
  static const OS linux = OS._('linux');
  static const OS macOS = OS._('macos');
  static const OS windows = OS._('windows');

  /// Known values for [Architecture].
  static const List<OS> values = [
    android,
    fuchsia,
    iOS,
    linux,
    macOS,
    windows,
  ];

  static const _abiToOS = {
    Abi.androidArm: OS.android,
    Abi.androidArm64: OS.android,
    Abi.androidIA32: OS.android,
    Abi.androidX64: OS.android,
    Abi.fuchsiaArm64: OS.fuchsia,
    Abi.fuchsiaX64: OS.fuchsia,
    Abi.iosArm: OS.iOS,
    Abi.iosArm64: OS.iOS,
    Abi.iosX64: OS.iOS,
    Abi.linuxArm: OS.linux,
    Abi.linuxArm64: OS.linux,
    Abi.linuxIA32: OS.linux,
    Abi.linuxX64: OS.linux,
    Abi.macosArm64: OS.macOS,
    Abi.macosX64: OS.macOS,
    Abi.windowsArm64: OS.windows,
    Abi.windowsIA32: OS.windows,
    Abi.windowsX64: OS.windows,
  };

  /// Whether the [OS] is a OS for mobile devices.
  bool get isMobile => this == OS.android || this == OS.iOS;

  /// Whether the [OS] is a OS for desktop devices.
  bool get isDesktop =>
      this == OS.linux || this == OS.macOS || this == OS.windows;

  /// Typical cross compilation between OSes.
  static const _osCrossCompilationDefault = {
    OS.macOS: [OS.macOS, OS.iOS, OS.android],
    OS.linux: [OS.linux, OS.android],
    OS.windows: [OS.windows, OS.android],
  };

  /// The default dynamic library file name on this [OS].
  String dylibFileName(String name) {
    final prefix = _dylibPrefix[this]!;
    final extension = _dylibExtension[this]!;
    return '$prefix$name.$extension';
  }

  /// The default static library file name on this [OS].
  String staticlibFileName(String name) {
    final prefix = _staticlibPrefix[this]!;
    final extension = _staticlibExtension[this]!;
    return '$prefix$name.$extension';
  }

  /// The default executable file name on this [OS].
  String executableFileName(String name) {
    final extension = _executableExtension[this]!;
    final dot = extension.isNotEmpty ? '.' : '';
    return '$name$dot$extension';
  }

  /// The default name prefix for dynamic libraries per [OS].
  static const _dylibPrefix = {
    OS.android: 'lib',
    OS.fuchsia: 'lib',
    OS.iOS: 'lib',
    OS.linux: 'lib',
    OS.macOS: 'lib',
    OS.windows: '',
  };

  /// The default extension for dynamic libraries per [OS].
  static const _dylibExtension = {
    OS.android: 'so',
    OS.fuchsia: 'so',
    OS.iOS: 'dylib',
    OS.linux: 'so',
    OS.macOS: 'dylib',
    OS.windows: 'dll',
  };

  /// The default name prefix for static libraries per [OS].
  static const _staticlibPrefix = _dylibPrefix;

  /// The default extension for static libraries per [OS].
  static const _staticlibExtension = {
    OS.android: 'a',
    OS.fuchsia: 'a',
    OS.iOS: 'a',
    OS.linux: 'a',
    OS.macOS: 'a',
    OS.windows: 'lib',
  };

  /// The default extension for executables per [OS].
  static const _executableExtension = {
    OS.android: '',
    OS.fuchsia: '',
    OS.iOS: '',
    OS.linux: '',
    OS.macOS: '',
    OS.windows: 'exe',
  };
}

/// For an iOS target, a build is either done for the device or the simulator.
///
/// Only fat binaries or xcframeworks can contain both targets.
class IOSSdk {
  final String xcodebuildSdk;

  const IOSSdk._(this.xcodebuildSdk);

  static const iPhoneOs = IOSSdk._('iphoneos');
  static const iPhoneSimulator = IOSSdk._('iphonesimulator');

  static const values = [
    iPhoneOs,
    iPhoneSimulator,
  ];
}

/// Application binary interface.
///
/// The Dart VM can run on a variety of [Target]s, see [Target.values].
class Target implements Comparable {
  final Abi abi;

  /// If the [os] is [OS.iOS], which SDK is targeted.
  final IOSSdk? iOSSdk;

  const Target._(this.abi, {this.iOSSdk});

  factory Target.fromString(String target) => _stringToTarget[target]!;

  /// The [Target] corresponding the substring of [Platform.version]
  /// describing the [Target].
  ///
  /// The [Platform.version] strings are formatted as follows:
  /// `<version> (<date>) on "<Target>"`.
  ///
  /// Cannot return targets with [IOSSdk.iPhoneSimulator].
  factory Target.fromDartPlatform(String dartPlatform) =>
      _dartVMstringToTarget[dartPlatform]!;

  /// Target for [os], [architecture], and (optionally) [iOSSdk].
  ///
  /// Must be included in [Target.values], which can be checked with [isValid].
  factory Target(OS os, Architecture architecture, {IOSSdk? iOSSdk}) =>
      _canonicalizedTargets[os]![architecture]![iOSSdk]!;

  static const androidArm = Target._(Abi.androidArm);
  static const androidArm64 = Target._(Abi.androidArm64);
  static const androidIA32 = Target._(Abi.androidIA32);
  static const androidX64 = Target._(Abi.androidX64);
  static const fuchsiaArm64 = Target._(Abi.fuchsiaArm64);
  static const fuchsiaX64 = Target._(Abi.fuchsiaX64);
  static const iOSArm = Target._(Abi.iosArm, iOSSdk: IOSSdk.iPhoneOs);
  static const iOSArm64 = Target._(Abi.iosArm64, iOSSdk: IOSSdk.iPhoneOs);
  static const iOSSimulatorArm64 =
      Target._(Abi.iosArm64, iOSSdk: IOSSdk.iPhoneSimulator);
  static const iOSSimulatorX64 =
      Target._(Abi.iosX64, iOSSdk: IOSSdk.iPhoneSimulator);
  static const linuxArm = Target._(Abi.linuxArm);
  static const linuxArm64 = Target._(Abi.linuxArm64);
  static const linuxIA32 = Target._(Abi.linuxIA32);
  static const linuxX64 = Target._(Abi.linuxX64);
  static const macOSArm64 = Target._(Abi.macosArm64);
  static const macOSX64 = Target._(Abi.macosX64);
  static const windowsIA32 = Target._(Abi.windowsIA32);
  static const windowsX64 = Target._(Abi.windowsX64);

  /// All Targets that we can build for.
  ///
  /// Note that for some of these a Dart SDK is not available and they are only
  /// used as target architectures for Flutter apps.
  ///
  /// This is a superset of [Abi] due to iOS builds either targeting the simulator
  /// or device.
  static const values = {
    androidArm,
    androidArm64,
    androidIA32,
    androidX64,
    fuchsiaArm64,
    fuchsiaX64,
    iOSArm,
    iOSArm64,
    iOSSimulatorArm64,
    iOSSimulatorX64,
    linuxArm,
    linuxArm64,
    linuxIA32,
    linuxX64,
    macOSArm64,
    macOSX64,
    windowsIA32,
    windowsX64,
  };

  /// Mapping from strings as used in [Target.toString] to [Target]s.
  static final Map<String, Target> _stringToTarget = Map.fromEntries(
      Target.values.map((target) => MapEntry(target.toString(), target)));

  /// Mapping from lowercased strings as used in [Platform.version] to [Target]s.
  ///
  /// The Dart VM does not distinguish between [IOSSdk]s.
  static final Map<String, Target> _dartVMstringToTarget = Map.fromEntries(
      Target.values.map((target) => MapEntry(target.dartVMToString(), target)));

  /// Efficient lookup for canonicalized instances in [Target.values].
  static final Map<OS, Map<Architecture, Map<IOSSdk?, Target>>>
      _canonicalizedTargets = {
    for (OS os in OS.values)
      os: {
        for (Architecture architecture in Architecture.values)
          architecture: {
            for (IOSSdk? iOSSdk in [...IOSSdk.values, null])
              if (Target.values
                  .where((target) =>
                      target.os == os &&
                      target.architecture == architecture &&
                      target.iOSSdk == iOSSdk)
                  .isNotEmpty)
                iOSSdk: Target.values.firstWhere((target) =>
                    target.os == os &&
                    target.architecture == architecture &&
                    target.iOSSdk == iOSSdk),
          },
      }
  };

  /// Whether [os], [architecture], and (optionally) [iOSSdk] is a supported
  /// Target ([Target.values]).
  static bool isValid(OS os, Architecture architecture, {IOSSdk? iOSSdk}) =>
      _canonicalizedTargets[os]![architecture]![iOSSdk] != null;

  /// The current [Target].
  ///
  /// Read from the [Platform.version] string.
  static final Target current = () {
    final versionStringFull = Platform.version;
    final split = versionStringFull.split('"');
    if (split.length < 2) {
      throw StateError(
          "Unknown version from Platform.version '$versionStringFull'.");
    }
    final versionString = split[1];
    final target = _dartVMstringToTarget[versionString];
    if (target == null) {
      throw StateError(
          "Unknown ABI '$versionString' from Platform.version '$versionStringFull'.");
    }
    return target;
  }();

  Architecture get architecture => Architecture.fromAbi(abi);

  OS get os => OS.fromAbi(abi);

  String get _architectureString => architecture.dartPlatform;

  String get _osString => os.dartPlatform;

  /// A string representation of this object.
  @override
  String toString() {
    final _iOSSdkString = iOSSdk == IOSSdk.iPhoneSimulator ? 'simulator' : '';
    return '$_osString${_iOSSdkString}_$_architectureString';
  }

  /// As used in [Platform.version].
  ///
  /// The Dart VM does not report on which [IOSSdk] it is running.
  String dartVMToString() => '${_osString}_$_architectureString';

  /// Compares `this` to [other].
  ///
  /// If [other] is also an [Target], consistent with sorting on [toString].
  @override
  int compareTo(other) {
    if (other is Target) {
      return toString().compareTo(other.toString());
    }
    return -1;
  }

  /// A list of supported target [Target]s from this host [os].
  List<Target> supportedTargetTargets(
      {Map<OS, List<OS>> osCrossCompilation = OS._osCrossCompilationDefault}) {
    return Target.values.where((target) =>
        // Only valid cross compilation.
        osCrossCompilation[os]!.contains(target.os)).sorted;
  }
}

/// Common methods for manipulating iterables of [Target]s.
extension TargetList on Iterable<Target> {
  /// The [Target]s in `this` sorted by name alphabetically.
  List<Target> get sorted => [for (final target in this) target]..sort();

  /// The [Target]s in `this` with all [fatTargets] included.
  ///
  /// For example:
  ///
  /// ```
  /// const fatTargets = [
  ///   [macOSArm64, macOSX64],
  ///   [iOSArm, iOSArm64, iOSSimulatorArm64, iOSSimulatorX64],
  /// ];
  ///
  /// /// Will be [macOSArm64, macOSX64].
  /// final expanded = [macOSX64].expandFatTargets(fatTargets);
  /// ```
  List<Target> expandFatTargets(Iterable<Iterable<Target>> fatTargets) {
    final fatTargetMap = Map.fromEntries([
      for (final group in fatTargets) ...[
        for (final target in group) ...[MapEntry(target, group)],
      ]
    ]);

    var result = <Target>{};
    for (final target in this) {
      if (!fatTargetMap.containsKey(target)) {
        result.add(target);
        continue;
      }
      result.addAll(fatTargetMap[target]!);
    }
    return result.sorted;
  }

  /// The [Target]s in `this` with all [fatTargets] duplicates removed.
  ///
  /// For example:
  ///
  /// ```
  /// const fatTargets = [
  ///   [macOSArm64, macOSX64],
  ///   [iOSArm, iOSArm64, iOSSimulatorArm64, iOSSimulatorX64],
  /// ];
  ///
  /// /// Will be [macOSArm64].
  /// final expanded = [macOSArm64, macOSX64].expandFatTargets(fatTargets);
  /// ```
  List<Target> unduplicateFatTargets(Iterable<Iterable<Target>> fatTargets) {
    final fatTargetMap = Map.fromEntries([
      for (final group in fatTargets) ...[
        for (final target in group) ...[MapEntry(target, group)],
      ]
    ]);

    var result = <Target>{};
    for (final target in this) {
      if (!fatTargetMap.containsKey(target)) {
        result.add(target);
        continue;
      }
      final group = fatTargetMap[target]!;
      if (result.intersection(group.toSet()).isEmpty) {
        result.add(target);
      }
    }
    return result.sorted;
  }
}
