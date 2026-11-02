import 'package:flutter/widgets.dart';

/// Web variant: a picked image is a `blob:`/`data:` URL, not a file path.
///
/// `dart:io` does not exist in the browser, so this file deliberately avoids it.
ImageProvider<Object>? buildProfileImageProvider(String? path) {
  if (path == null || path.isEmpty) return null;
  return NetworkImage(path);
}
