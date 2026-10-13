import 'dart:io';

import 'package:path/path.dart' as p;

/// User files belong to the application folder, independent of the launcher cwd.
String portableDataDirectory({String? executable, String? operatingSystem}) {
  final system = operatingSystem ?? Platform.operatingSystem;
  final paths = p.Context(
    style: system == 'windows' ? p.Style.windows : p.Style.posix,
  );
  var folder = paths.dirname(executable ?? Platform.resolvedExecutable);
  if (system == 'macos' &&
      paths.basename(folder) == 'MacOS' &&
      paths.basename(paths.dirname(folder)) == 'Contents' &&
      paths.basename(paths.dirname(paths.dirname(folder))).endsWith('.app')) {
    folder = paths.dirname(paths.dirname(paths.dirname(folder)));
  }
  return paths.join(folder, 'user_data');
}

/// Image references are portable and cannot escape the user data directory.
String? portableResourcePath(String directory, String reference) {
  final normalized = reference.replaceAll('\\', '/');
  final parts = normalized.split('/');
  if (normalized.isEmpty ||
      normalized.startsWith('/') ||
      normalized.contains(':') ||
      normalized.contains('\u0000') ||
      parts.any(
        (part) => part.isEmpty || part.endsWith('.') || part.endsWith(' '),
      )) {
    return null;
  }
  return [directory, ...parts].join(Platform.pathSeparator);
}
