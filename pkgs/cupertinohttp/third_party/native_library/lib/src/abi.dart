import 'dart:ffi' as ffi;
import 'dart:io';

/// The hardware architectures the Dart VM runs on.
enum Architecture {
  arm,
  arm64,
  ia32,
  x64,
}

/// Extension for [Architecture].
extension ArchitectureExtension on Architecture {
  /// This architecture as used in [Platform.version]
  String get dartPlatform => architectureStrings[this]!;

  /// The `CMAKE_ANDROID_ARCH_ABI` argument value for this [Architecture].
  String get cmakeAndroid => _architectureStringsCMakeAndroid[this]!;

  /// The `CMAKE_OSX_ARCHITECTURES` argument value for this [Architecture].
  String get cmakeOsx => _architectureStringsCMakeOsx[this]!;
}

/// Mapping from [Architecture]s to lowercased architecture strings as used in
/// [Platform.version].
const architectureStrings = {
  Architecture.arm: "arm",
  Architecture.arm64: "arm64",
  Architecture.ia32: "ia32",
  Architecture.x64: "x64",
};

/// Mapping from lowercased architecture strings as used in [Platform.version]
/// to [Architecture].
final stringToArchitecture =
    architectureStrings.map((key, value) => MapEntry(value, key));

const _architectureStringsCMakeAndroid = {
  Architecture.arm: "armeabi-v7a",
  Architecture.arm64: "arm64-v8a",
  Architecture.ia32: "x86",
  Architecture.x64: "x86_64",
};

const _architectureStringsCMakeOsx = {
  Architecture.arm: "armv7",
  Architecture.arm64: "arm64",
  Architecture.ia32: "x86",
  Architecture.x64: "x86_64",
};

/// The operating systems the Dart VM runs on.
enum OS {
  android,
  fuchsia,
  iOS,
  linux,
  macOS,
  windows,
}

/// Extension for [OS].
extension OSExtension on OS {
  /// This OS as used in [Platform.version]
  String get dartPlatform => osStrings[this]!;

  /// Whether the [OS] is a OS for mobile devices.
  bool get isMobile => this == OS.android || this == OS.iOS;

  /// Whether the [OS] is a OS for desktop devices.
  bool get isDesktop =>
      this == OS.linux || this == OS.macOS || this == OS.windows;
}

/// Mapping from [OS]s to lowercased OS strings as used in [Platform.version].
const osStrings = {
  OS.android: "android",
  OS.fuchsia: "fuchsia",
  OS.linux: "linux",
  OS.iOS: "ios",
  OS.macOS: "macos",
  OS.windows: "windows",
};

/// Mapping from lowercased OS strings as used in [Platform.version] to [OS]s.
final stringToOs = osStrings.map((key, value) => MapEntry(value, key));

/// For an iOS target, a build is either done for the device or the simulator.
///
/// Only fat binaries or xcframeworks can contain both targets.
enum IOSSdk {
  iPhoneOs,
  iPhoneSimulator,
}

/// Extension for [IOSSdk].
extension IOSSdkExtension on IOSSdk {
  /// The XCode `-sdk` argument value for `this`.
  String get xcodebuildSdk => _iOSSdkStringsXCodeBuild[this]!;
}

const _iOSSdkStrings = {
  IOSSdk.iPhoneOs: "",
  IOSSdk.iPhoneSimulator: "simulator",
};

const _iOSSdkStringsXCodeBuild = {
  IOSSdk.iPhoneOs: "iphoneos",
  IOSSdk.iPhoneSimulator: "iphonesimulator",
};

/// Application binary interface.
///
/// The Dart VM can run on a variety of [Abi]s, see [supportedAbis].
class Abi implements Comparable {
  final ffi.Abi abi;

  /// If the [os] is [OS.iOS], which SDK is targeted.
  // TODO(dacoharkes): This should not be part of Abi.
  final IOSSdk? iOSSdk;

  const Abi._(this.abi, {this.iOSSdk});

  /// Abi for [os], [architecture], and (optionally) [iOSSdk].
  ///
  /// Must be included in [supportedAbis], which can be checked with [isValid].
  factory Abi(OS os, Architecture architecture, {IOSSdk? iOSSdk}) =>
      _canonicalizedAbis[os]![architecture]![iOSSdk]!;

  /// Whether [os], [architecture], and (optionally) [iOSSdk] is a supported
  /// Abi ([supportedAbis]).
  static bool isValid(OS os, Architecture architecture, {IOSSdk? iOSSdk}) =>
      _canonicalizedAbis[os]![architecture]![iOSSdk] != null;

  /// Read the ABI from the [Platform.version] string.
  static Abi _fromPlatform() {
    final versionStringFull = Platform.version;
    final split = versionStringFull.split('"');
    if (split.length < 2) {
      throw StateError(
          "Unknown version from Platform.version '$versionStringFull'.");
    }
    final versionString = split[1];
    final abi = dartVMstringToAbi[versionString];
    if (abi == null) {
      throw StateError(
          "Unknown ABI '$versionString' from Platform.version '$versionStringFull'.");
    }
    return abi;
  }

  /// The current [Abi].
  ///
  /// Read from the [Platform.version] string.
  static final current = _fromPlatform();

  Architecture get architecture => ffiAbiArch[abi]!;

  OS get os => ffiAbiOs[abi]!;

  String get _architectureString => architecture.dartPlatform;

  String get _osString => os.dartPlatform;

  String get _iOSSdkString => _iOSSdkStrings[iOSSdk] ?? '';

  /// A string representation of this object.
  @override
  String toString() => '$_osString${_iOSSdkString}_$_architectureString';

  /// As used in [Platform.version].
  ///
  /// The Dart VM does not report on which [IOSSdk] it is running.
  String dartVMToString() => '${_osString}_$_architectureString';

  /// Compares `this` to [other].
  ///
  /// If [other] is also an [Abi], consistent with sorting on [toString].
  @override
  int compareTo(other) {
    if (other is Abi) {
      return toString().compareTo(other.toString());
    }
    return -1;
  }
}

const androidArm = Abi._(ffi.Abi.androidArm);
const androidArm64 = Abi._(ffi.Abi.androidArm64);
const androidIA32 = Abi._(ffi.Abi.androidIA32);
const androidX64 = Abi._(ffi.Abi.androidX64);
const fuchsiaArm64 = Abi._(ffi.Abi.fuchsiaArm64);
const fuchsiaX64 = Abi._(ffi.Abi.fuchsiaX64);
const iOSArm = Abi._(ffi.Abi.iosArm, iOSSdk: IOSSdk.iPhoneOs);
const iOSArm64 = Abi._(ffi.Abi.iosArm64, iOSSdk: IOSSdk.iPhoneOs);
const iOSSimulatorArm64 =
    Abi._(ffi.Abi.iosArm64, iOSSdk: IOSSdk.iPhoneSimulator);
const iOSSimulatorX64 = Abi._(ffi.Abi.iosX64, iOSSdk: IOSSdk.iPhoneSimulator);
const linuxArm = Abi._(ffi.Abi.linuxArm);
const linuxArm64 = Abi._(ffi.Abi.linuxArm64);
const linuxIA32 = Abi._(ffi.Abi.linuxIA32);
const linuxX64 = Abi._(ffi.Abi.linuxX64);
const macOSArm64 = Abi._(ffi.Abi.macosArm64);
const macOSX64 = Abi._(ffi.Abi.macosX64);
const windowsIA32 = Abi._(ffi.Abi.windowsIA32);
const windowsX64 = Abi._(ffi.Abi.windowsX64);

const ffiAbiArch = {
  ffi.Abi.androidArm: Architecture.arm,
  ffi.Abi.androidArm64: Architecture.arm64,
  ffi.Abi.androidIA32: Architecture.ia32,
  ffi.Abi.androidX64: Architecture.x64,
  ffi.Abi.fuchsiaArm64: Architecture.arm64,
  ffi.Abi.fuchsiaX64: Architecture.x64,
  ffi.Abi.iosArm: Architecture.arm,
  ffi.Abi.iosArm64: Architecture.arm64,
  ffi.Abi.iosX64: Architecture.x64,
  ffi.Abi.linuxArm: Architecture.arm,
  ffi.Abi.linuxArm64: Architecture.arm64,
  ffi.Abi.linuxIA32: Architecture.ia32,
  ffi.Abi.linuxX64: Architecture.x64,
  ffi.Abi.macosArm64: Architecture.arm64,
  ffi.Abi.macosX64: Architecture.x64,
  ffi.Abi.windowsArm64: Architecture.arm64,
  ffi.Abi.windowsIA32: Architecture.ia32,
  ffi.Abi.windowsX64: Architecture.x64,
};
const ffiAbiOs = {
  ffi.Abi.androidArm: OS.android,
  ffi.Abi.androidArm64: OS.android,
  ffi.Abi.androidIA32: OS.android,
  ffi.Abi.androidX64: OS.android,
  ffi.Abi.fuchsiaArm64: OS.fuchsia,
  ffi.Abi.fuchsiaX64: OS.fuchsia,
  ffi.Abi.iosArm: OS.iOS,
  ffi.Abi.iosArm64: OS.iOS,
  ffi.Abi.iosX64: OS.iOS,
  ffi.Abi.linuxArm: OS.linux,
  ffi.Abi.linuxArm64: OS.linux,
  ffi.Abi.linuxIA32: OS.linux,
  ffi.Abi.linuxX64: OS.linux,
  ffi.Abi.macosArm64: OS.macOS,
  ffi.Abi.macosX64: OS.macOS,
  ffi.Abi.windowsArm64: OS.windows,
  ffi.Abi.windowsIA32: OS.windows,
  ffi.Abi.windowsX64: OS.windows,
};

/// All ABIs that the DartVM can run on.
///
/// Note that for some of these a Dart SDK is not available and they are only
/// used as target architectures for Flutter apps.
const supportedAbis = {
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

/// Mapping from strings as used in [Abi.toString] to [Abi]s.
final Map<String, Abi> stringToAbi =
    Map.fromEntries(supportedAbis.map((abi) => MapEntry(abi.toString(), abi)));

/// Mapping from lowercased strings as used in [Platform.version] to [Abi]s.
///
/// The Dart VM does not distinguish between [IOSSdk]s.
final Map<String, Abi> dartVMstringToAbi = Map.fromEntries(
    supportedAbis.map((abi) => MapEntry(abi.dartVMToString(), abi)));

/// Efficient lookup for canonicalized instances in [supportedAbis].
final Map<OS, Map<Architecture, Map<IOSSdk?, Abi>>> _canonicalizedAbis = {
  for (OS os in OS.values)
    os: {
      for (Architecture architecture in Architecture.values)
        architecture: {
          for (IOSSdk? iOSSdk in [...IOSSdk.values, null])
            if (supportedAbis
                .where((abi) =>
                    abi.os == os &&
                    abi.architecture == architecture &&
                    abi.iOSSdk == iOSSdk)
                .isNotEmpty)
              iOSSdk: supportedAbis.firstWhere((abi) =>
                  abi.os == os &&
                  abi.architecture == architecture &&
                  abi.iOSSdk == iOSSdk),
        },
    }
};

/// Typical cross compilation between OSes.
const _osCrossCompilationDefault = {
  OS.macOS: [OS.macOS, OS.iOS, OS.android],
  OS.linux: [OS.linux, OS.android],
  OS.windows: [OS.windows, OS.android],
};

/// A list of supported target [Abi]s.
///
/// [hostAbi] defaults to `Abi.current`.
List<Abi> supportedTargetAbis(
    {Abi? hostAbi,
    Map<OS, List<OS>> osCrossCompilation = _osCrossCompilationDefault}) {
  final host = hostAbi ?? Abi.current;
  return supportedAbis.where((abi) =>
      // Only valid cross compilation.
      osCrossCompilation[host.os]!.contains(abi.os)).sorted;
}

/// The default name prefix for dynamic libraries per [OS].
const dylibPrefix = {
  OS.android: 'lib',
  OS.fuchsia: 'lib',
  OS.iOS: 'lib',
  OS.linux: 'lib',
  OS.macOS: 'lib',
  OS.windows: '',
};

/// The default extension for dynamic libraries per [OS].
const dylibExtension = {
  OS.android: 'so',
  OS.fuchsia: 'so',
  OS.iOS: 'dylib',
  OS.linux: 'so',
  OS.macOS: 'dylib',
  OS.windows: 'dll',
};

/// The default dynamic library file name on an [os].
///
/// Uses the current [OS] if none is provided.
String dylibFileName(String name, {OS? os}) {
  final targetOs = os ?? Abi.current.os;
  final prefix = dylibPrefix[targetOs]!;
  final extension = dylibExtension[targetOs]!;
  return '$prefix$name.$extension';
}

/// The default name prefix for static libraries per [OS].
const staticlibPrefix = dylibPrefix;

/// The default extension for static libraries per [OS].
const staticlibExtension = {
  OS.android: 'a',
  OS.fuchsia: 'a',
  OS.iOS: 'a',
  OS.linux: 'a',
  OS.macOS: 'a',
  OS.windows: 'lib',
};

/// The default static library file name on an [os].
///
/// Uses the current [OS] if none is provided.
String staticlibFileName(String name, {OS? os}) {
  final targetOs = os ?? Abi.current.os;
  final prefix = staticlibPrefix[targetOs]!;
  final extension = staticlibExtension[targetOs]!;
  return '$prefix$name.$extension';
}

/// The default extension for executables per [OS].
const executableExtension = {
  OS.android: '',
  OS.fuchsia: '',
  OS.iOS: '',
  OS.linux: '',
  OS.macOS: '',
  OS.windows: 'exe',
};

/// The default executable file name on an [os].
///
/// Uses the current [OS] if none is provided.
String executableFileName(String name, {OS? os}) {
  final targetOs = os ?? Abi.current.os;
  final extension = executableExtension[targetOs]!;
  final dot = extension != '' ? '.' : '';
  return '$name$dot$extension';
}

/// Common methods for manipulating iterables of [Abi]s.
extension AbiList on Iterable<Abi> {
  /// The [Abi]s in `this` sorted by name alphabetically.
  List<Abi> get sorted => [for (final abi in this) abi]..sort();

  /// The [Abi]s in `this` with all [fatAbis] included.
  ///
  /// For example:
  ///
  /// ```
  /// const fatAbis = [
  ///   [macOSArm64, macOSX64],
  ///   [iOSArm, iOSArm64, iOSSimulatorArm64, iOSSimulatorX64],
  /// ];
  ///
  /// /// Will be [macOSArm64, macOSX64].
  /// final expanded = [macOSX64].expandFatAbis(fatAbis);
  /// ```
  List<Abi> expandFatAbis(Iterable<Iterable<Abi>> fatAbis) {
    final fatAbiMap = Map.fromEntries([
      for (final group in fatAbis) ...[
        for (final abi in group) ...[MapEntry(abi, group)],
      ]
    ]);

    var result = <Abi>{};
    for (final abi in this) {
      if (!fatAbiMap.containsKey(abi)) {
        result.add(abi);
        continue;
      }
      result.addAll(fatAbiMap[abi]!);
    }
    return result.sorted;
  }

  /// The [Abi]s in `this` with all [fatAbis] duplicates removed.
  ///
  /// For example:
  ///
  /// ```
  /// const fatAbis = [
  ///   [macOSArm64, macOSX64],
  ///   [iOSArm, iOSArm64, iOSSimulatorArm64, iOSSimulatorX64],
  /// ];
  ///
  /// /// Will be [macOSArm64].
  /// final expanded = [macOSArm64, macOSX64].expandFatAbis(fatAbis);
  /// ```
  List<Abi> unduplicateFatAbis(Iterable<Iterable<Abi>> fatAbis) {
    final fatAbiMap = Map.fromEntries([
      for (final group in fatAbis) ...[
        for (final abi in group) ...[MapEntry(abi, group)],
      ]
    ]);

    var result = <Abi>{};
    for (final abi in this) {
      if (!fatAbiMap.containsKey(abi)) {
        result.add(abi);
        continue;
      }
      final group = fatAbiMap[abi]!;
      if (result.intersection(group.toSet()).isEmpty) {
        result.add(abi);
      }
    }
    return result.sorted;
  }
}
