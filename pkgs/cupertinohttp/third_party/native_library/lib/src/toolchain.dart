import 'dart:async';
import 'dart:convert';
import 'dart:io';

class NativeTool {
  /// The name, excluding `.exe` if an executable on Windows.
  final String name;

  /// The path of the native tool on the host system.
  ///
  /// Non-`null` if [isAvailable].
  final Uri? uri;

  /// The version of the native tool.
  ///
  /// Can be null even if [isAvailable].
  final SemanticVersion? version;

  /// Searched for executable on the environment `PATH`.
  final bool searchedOnPath;

  /// Searched for the native tool in these [Uri]s.
  ///
  /// Typically default install locations for tools.
  final List<Uri> searchedInUris;

  /// Extra info regarding this native tool.
  final String? extraInfo;

  const NativeTool._(this.name, this.uri, this.version, this.searchedOnPath,
      this.searchedInUris, this.extraInfo);

  static Future<NativeTool> search(String name,
      {String? executableName,
      bool searchOnPath: true,
      Future<Uri?> Function(List<Uri>)? searchUris,
      bool lookupVersion: true,
      String? lookupVersionArgument,
      int lookupVersionExitCode = 0,
      String? extraInfo}) async {
    Uri? uri;
    if (searchOnPath) {
      if (executableName == null) {
        executableName = name.toLowerCase();
      }
      uri = await which(executableName);
    }
    final searchedInUris = <Uri>[];
    if (uri == null && searchUris != null) {
      uri = await searchUris(searchedInUris);
    }
    SemanticVersion? version;
    if (lookupVersion) {
      if (lookupVersionArgument == null) {
        version = await uri?.version(expectedExitCode: lookupVersionExitCode);
      } else {
        version = await uri?.version(
            argument: lookupVersionArgument,
            expectedExitCode: lookupVersionExitCode);
      }
    }
    return NativeTool._(
        name, uri, version, searchOnPath, searchedInUris, extraInfo);
  }

  /// Whether this tool is available on the host system.
  bool get isAvailable => uri != null;

  /// The path of this native tool.
  ///
  /// Throws if the tool is not available.
  String get path {
    final uri_ = uri;
    if (uri_ == null) {
      var message = 'Could not find $name.';
      if (searchedOnPath) {
        message += '\nSearched on environment PATH.';
      }
      if (searchedInUris.isNotEmpty) {
        message += '\nSearched in $searchedInUris';
      }
      if (extraInfo != null) {
        message += '\n$extraInfo';
      }
      throw NativeToolError(message);
    }
    // We use forward slashes on also on Windows because that's easier with
    // escaping when passing as command line arguments.
    // Using this because `windows: false` puts a `/` in front of `C:/`.
    return uri_.toFilePath().replaceAll(r'\', r'/');
  }
}

final Future<NativeTool> cmake = NativeTool.search(
  'CMake',
  searchUris: (List<Uri> urisSearched) async {
    if (Platform.isWindows) {
      if (_homeDir != null) {
        final cmakeUri = Directory(_homeDir!)
            .uri
            .resolve('AppData/Local/Android/Sdk/cmake/');
        final cmakeDir = Directory(cmakeUri.toFilePath());
        urisSearched.add(cmakeUri);
        if (await cmakeDir.exists()) {
          final cmakeVersions =
              (await cmakeDir.list().toList()).whereType<Directory>().toList();
          if (cmakeVersions.isNotEmpty) {
            return cmakeVersions.last.uri;
          }
        }
      }
    }
    if (Platform.isMacOS) {
      final cmakeUri = Uri.parse('/Applications/CMake.app/Contents/bin/cmake');
      urisSearched.add(cmakeUri);
      final cmakeFile = File.fromUri(cmakeUri);
      if (await cmakeFile.exists()) {
        return cmakeUri;
      }
    }
    return null;
  },
);

final Future<NativeTool> clang = NativeTool.search(
  'Clang',
  searchUris: (List<Uri> urisSearched) async {
    final llvmUri_ = await _llvmUri;
    if (llvmUri_ != null) {
      final clangUri = llvmUri_.resolve('bin/clang.exe');
      urisSearched.add(clangUri);
      if (await File.fromUri(clangUri).exists()) {
        return clangUri;
      }
    }

    final visualStudioUri = await _visualStudioUri;
    if (visualStudioUri != null) {
      final clangUri = visualStudioUri.resolve('VC/Tools/Llvm/bin/clang.exe');
      urisSearched.add(clangUri);
      if (await File.fromUri(clangUri).exists()) {
        return clangUri;
      }
    }
    return null;
  },
);

final Future<NativeTool> ninja = NativeTool.search(
  'Ninja',
  searchUris: (List<Uri> urisSearched) async {
    if (Platform.isWindows) {
      final cmakePath = (await cmake).uri;
      if (cmakePath != null) {
        final ninjaUri = cmakePath.resolve('bin/ninja.exe');
        urisSearched.add(ninjaUri);
        if (await File.fromUri(ninjaUri).exists()) {
          return ninjaUri;
        }
      }
    }
    return null;
  },
);

final Future<NativeTool> androidNdk = NativeTool.search(
  'Android NDK',
  searchUris: (List<Uri> urisSearched) async {
    if (Platform.isMacOS) {
      for (final path in _homebrewNdkPaths) {
        final uri = Uri.directory(path);
        final dir = Directory.fromUri(uri);
        urisSearched.add(uri);
        if (await dir.exists()) {
          return uri;
        }
      }
    } else if (Platform.isLinux) {
      if (_homeDir != null) {
        final ndkBundleUri =
            Directory(_homeDir!).uri.resolve('Android/Sdk/ndk-bundle/');
        urisSearched.add(ndkBundleUri);
        if (await Directory(ndkBundleUri.path).exists()) {
          return ndkBundleUri;
        }
      }
    } else if (Platform.isWindows) {
      if (_homeDir != null) {
        final ndkBundleUri = Directory(_homeDir!)
            .uri
            .resolve('AppData/Local/Android/Sdk/ndk-bundle');
        urisSearched.add(ndkBundleUri);
        if (await Directory(ndkBundleUri.toFilePath()).exists()) {
          return ndkBundleUri;
        }
      }
    }
    return null;
  },
  extraInfo: '''
CMake 3.18 expects an ndk-bundle/platforms which was the directory layout in
Android NDK r18 and earlier.
CMake 3.20 and NDK r23 should also work together, but this is not implemented
in this repo (yet).
  ''',
  searchOnPath: false,
  lookupVersion: false,
);

final Future<NativeTool> msvc = NativeTool.search(
  'MSVC',
  executableName: 'cl',
  searchUris: (List<Uri> urisSearched) async {
    final visualStudioUri = await _visualStudioUri;
    if (visualStudioUri != null) {
      final msvcVersionsDir =
          Directory.fromUri(visualStudioUri.resolve('VC/Tools/MSVC/'));
      final msvcVersions = (await msvcVersionsDir.list().toList())
          .whereType<Directory>()
          .toList();
      if (msvcVersions.isNotEmpty) {
        final uri = msvcVersions.last.uri.resolve('bin/Hostx64/x64/cl.exe');
        urisSearched.add(uri);
        if (await File.fromUri(uri).exists()) {
          return uri;
        }
      }
    }
    return null;
  },
  searchOnPath: true,
  lookupVersion: true,
  lookupVersionArgument: '',
  // Has no version command line argument. Reports its version on missing input.
  lookupVersionExitCode: 2,
);

Future<List<NativeTool>> get tools => Future.wait([
      androidNdk,
      clang,
      cmake,
      if (Platform.isWindows) msvc,
      ninja,
    ]);

// Try different environment variables for finding the home directory.
//
// The $HOME in powershell does not show up in Dart.
final _homeDir =
    Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

/// Default path for homebrew to install the Android NDK.
final _homebrewNdkPaths = [
  '/usr/local/Caskroom/android-ndk/21/android-ndk-r21',
  '/usr/local/Caskroom/android-ndk/20/android-ndk-r20',
  '/usr/local/Caskroom/android-ndk/19/android-ndk-r19',
];

final Future<Uri?> _programFilesX86Uri = () async {
  final uri = Uri(path: 'C:/Program Files (x86)/');
  if (await Directory.fromUri(uri).exists()) {
    return uri;
  }
  return null;
}();

final _visualStudioYears = [
  '2019',
  '2017',
  '2015',
  '2013',
];

final _visualStudioEditions = [
  'Professional',
  'Community',
];

/// Default install paths for Visual Studio.
final Future<Uri?> _visualStudioUri = () async {
  final programFilesX86Uri_ = await _programFilesX86Uri;
  if (programFilesX86Uri_ != null) {
    final visualStudioContainerUri =
        programFilesX86Uri_.resolve('Microsoft Visual Studio/');
    final visualStudioContainerDir =
        Directory.fromUri(visualStudioContainerUri);
    if (await visualStudioContainerDir.exists()) {
      for (final visualStudioYear in _visualStudioYears) {
        for (final visualStudioEdition in _visualStudioEditions) {
          final folderUri = visualStudioContainerUri
              .resolve('$visualStudioYear/$visualStudioEdition/');
          if (await Directory.fromUri(folderUri).exists()) {
            return folderUri;
          }
        }
      }
    }
  }
}();

const _llvmPaths = [
  'C:/Program Files/LLVM/',
];

final Future<Uri?> _llvmUri = () async {
  for (final path in _llvmPaths) {
    final uri = Uri(path: path);
    if (await Directory.fromUri(uri).exists()) {
      return uri;
    }
  }
}();

/// Finds an executable available on the `PATH`.
///
/// Adds `.exe` on Windows.
Future<Uri?> which(String executableName) async {
  final whichOrWhere = Platform.isWindows ? 'where' : 'which';
  final fileExtension = Platform.isWindows ? '.exe' : '';
  final process =
      await _runProcess(whichOrWhere, ['$executableName$fileExtension']);
  if (process.exitCode == 0) {
    final file = File(LineSplitter.split(process.stdout).first);
    final uri = File(await file.resolveSymbolicLinks()).uri;
    return uri;
  }
  if (process.exitCode == 1) {
    // The exit code for executable not being on the `PATH`.
    return null;
  }
  throw NativeToolError(
      '`$whichOrWhere $executableName` returned unexpected exit code: '
      '${process.exitCode}.');
}

final _semverRegex = RegExp(
    r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?');

/// Extension on [Uri].
extension UriExtension on Uri {
  /// Finds the version of an [executable].
  ///
  /// Assumes the version is formatted as semantic versioning.
  ///
  /// Takes the first semantic version string as version.
  Future<SemanticVersion> version(
      {String argument: '--version', int expectedExitCode = 0}) async {
    final executablePath = toFilePath();
    final process = await _runProcess(executablePath, [argument]);
    if (process.exitCode != expectedExitCode) {
      throw NativeToolError(
          '`$executablePath $argument` returned unexpected exit code: '
          '${process.exitCode}.');
    }
    final match = _semverRegex.firstMatch(process.stdout)!;
    final semver = SemanticVersion(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        match.group(4),
        match.group(5));
    return semver;
  }
}

class _RunProcessResult {
  final int exitCode;
  final String stdout;
  const _RunProcessResult(this.exitCode, this.stdout);
}

/// Runs a process async and captures the exit code and standard out.
Future<_RunProcessResult> _runProcess(
    String executable, List<String> args) async {
  final List<int> stdoutBuffer = <int>[];
  final Completer<int> exitCodeCompleter = new Completer<int>();
  final Process process = await Process.start(executable, args);
  process.stdout.listen((List<int> event) {
    stdoutBuffer.addAll(event);
  }, onDone: () async => exitCodeCompleter.complete(await process.exitCode));
  final int exitCode = await exitCodeCompleter.future;
  final String stdout = utf8.decoder.convert(stdoutBuffer);
  return _RunProcessResult(exitCode, stdout);
}

/// A semantic version as defined on https://semver.org/.
class SemanticVersion {
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;
  final String? metaData;

  const SemanticVersion(
      this.major, this.minor, this.patch, this.preRelease, this.metaData);

  String get _preReleaseString => preRelease != null ? '-$preRelease' : '';
  String get _metaDataString => metaData != null ? '+$metaData' : '';

  String toString() => '$major.$minor.$patch$_preReleaseString$_metaDataString';
}

/// The operation could not be performed due to a configuration error on the
/// host system.
class NativeToolError extends Error {
  final String message;
  NativeToolError(this.message);
  String toString() => "System not configured correctly: $message";
}
