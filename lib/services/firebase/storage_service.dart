import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../../core/exceptions/app_exception.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  Future<String> uploadStoreImage({
    required String storeId,
    required File file,
  }) async {
    return _uploadFile(
      path: 'stores/$storeId/${_uuid.v4()}.jpg',
      file: file,
    );
  }

  Future<String> uploadProductImage({
    required String storeId,
    required String productId,
    required File file,
  }) async {
    return _uploadFile(
      path: 'products/$storeId/$productId/${_uuid.v4()}.jpg',
      file: file,
    );
  }

  Future<String> uploadUserAvatar({
    required String userId,
    required File file,
  }) async {
    return _uploadFile(
      path: 'avatars/$userId/${_uuid.v4()}.jpg',
      file: file,
    );
  }

  Future<String> _uploadFile({
    required String path,
    required File file,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      );

      final uploadTask = ref.putFile(file, metadata);

      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        _logger.d('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      _logger.i('File uploaded: $path');
      return downloadUrl;
    } on FirebaseException catch (e) {
      _logger.e('Upload failed', error: e);
      throw StorageException(
        'Failed to upload image. Please try again.',
        code: e.code,
        originalError: e,
      );
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      _logger.w('Failed to delete file', error: e);
    }
  }
}
