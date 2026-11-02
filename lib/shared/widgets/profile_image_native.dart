import 'dart:io';

import 'package:flutter/widgets.dart';

ImageProvider<Object>? buildProfileImageProvider(String? path) {
  if (path == null || path.isEmpty) return null;
  return FileImage(File(path));
}
