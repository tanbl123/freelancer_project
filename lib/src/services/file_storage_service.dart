import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class FileStorageService {
  static final FileStorageService instance = FileStorageService._();
  FileStorageService._();

  static const _uuid = Uuid();

  Future<Directory> _subfolder(String name) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Saves an image XFile (from camera or gallery) to local storage.
  /// Returns the absolute file path.
  Future<String> saveImage(XFile image, String subfolder) async {
    final dir = await _subfolder('images/$subfolder');
    final ext = p.extension(image.path).isNotEmpty ? p.extension(image.path) : '.jpg';
    final dest = p.join(dir.path, '${_uuid.v4()}$ext');
    await File(image.path).copy(dest);
    return dest;
  }

  /// Saves raw bytes as a PNG (used for signatures).
  Future<String> saveSignaturePng(Uint8List bytes, String milestoneId) async {
    final dir = await _subfolder('signatures');
    final dest = p.join(dir.path, '$milestoneId.png');
    await File(dest).writeAsBytes(bytes);
    return dest;
  }

  /// Saves a PlatformFile (resume, document) to local storage.
  /// Returns the absolute file path.
  Future<String> savePlatformFile(PlatformFile file, String subfolder) async {
    final dir = await _subfolder('files/$subfolder');
    final ext = file.extension != null ? '.${file.extension}' : '';
    final dest = p.join(dir.path, '${_uuid.v4()}$ext');
    if (file.path != null) {
      await File(file.path!).copy(dest);
    } else if (file.bytes != null) {
      await File(dest).writeAsBytes(file.bytes!);
    }
    return dest;
  }

  /// Saves an audio recording to local storage.
  /// [tempPath] is the path returned by the record package after stopping.
  Future<String> saveAudio(String tempPath, String subfolder) async {
    final dir = await _subfolder('audio/$subfolder');
    final ext = p.extension(tempPath).isNotEmpty ? p.extension(tempPath) : '.m4a';
    final dest = p.join(dir.path, '${_uuid.v4()}$ext');
    await File(tempPath).copy(dest);
    return dest;
  }

  /// Checks whether a local file path exists and is readable.
  bool fileExists(String? path) {
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }
}
