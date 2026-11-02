import 'package:flutter/widgets.dart';

import 'profile_image_native.dart'
    if (dart.library.js_interop) 'profile_image_web.dart'
    as impl;

/// Builds an [ImageProvider] for a locally stored profile photo.
///
/// The storage format differs per platform: native builds keep an absolute file
/// path, while the browser returns a `blob:` URL for a picked file and cannot
/// construct a `File` at all. This conditional-import seam keeps `dart:io` out
/// of the web bundle instead of branching on `kIsWeb` at runtime.
ImageProvider<Object>? profileImageProvider(String? path) =>
    impl.buildProfileImageProvider(path);
