import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/marketplace/models/marketplace_post.dart';
import '../shared/domain_types.dart';
import '../shared/firestore_paths.dart';

class MarketplaceRepository {
  MarketplaceRepository({
    FirebaseFirestore? firestore,
    Future<Database> Function()? dbProvider,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _dbProvider = dbProvider ?? _defaultDbProvider;

  final FirebaseFirestore _firestore;
  final Future<Database> Function() _dbProvider;

  static Future<Database> _defaultDbProvider() async {
    final path = join(await getDatabasesPath(), 'marketplace_cache.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE cached_jobs(id TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)',
        );
      },
    );
  }

  CollectionReference<Map<String, dynamic>> _collectionFor(PostType type) {
    return _firestore.collection(
      type == PostType.jobRequest ? FirestorePaths.jobs : FirestorePaths.services,
    );
  }

  Future<String> createPost(MarketplacePost post) async {
    if (post.minimumBudget <= 0 && post.type == PostType.jobRequest) {
      throw ArgumentError('Minimum budget must be greater than zero.');
    }

    final ref = await _collectionFor(post.type).add(post.toFirestore());
    return ref.id;
  }

  Future<void> updatePost(MarketplacePost post) async {
    if (post.isAccepted) {
      throw StateError('Accepted posts cannot be updated.');
    }
    await _collectionFor(post.type).doc(post.id).update(post.toFirestore());
  }

  Future<void> deletePost({required String postId, required PostType type}) {
    return _collectionFor(type).doc(postId).delete();
  }

  Stream<List<MarketplacePost>> streamActiveFeed(PostType type) {
    return _collectionFor(type)
        .where('deadline', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('deadline')
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(MarketplacePost.fromFirestore).toList());
  }

  Future<void> cacheLatestJobs() async {
    final snapshot = await _collectionFor(PostType.jobRequest)
        .where('deadline', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('deadline')
        .limit(20)
        .get();

    final db = await _dbProvider();
    final batch = db.batch();
    batch.delete('cached_jobs');

    for (final doc in snapshot.docs) {
      final post = MarketplacePost.fromFirestore(doc);
      batch.insert('cached_jobs', {
        'id': post.id,
        'payload': jsonEncode({
          'id': post.id,
          'ownerId': post.ownerId,
          'ownerName': post.ownerName,
          'title': post.title,
          'description': post.description,
          'minimumBudget': post.minimumBudget,
          'deadline': post.deadline.toIso8601String(),
          'skills': post.skills,
          'type': post.type.name,
          'imageUrl': post.imageUrl,
          'isAccepted': post.isAccepted,
        }),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> readCachedJobs() async {
    final db = await _dbProvider();
    final rows = await db.query('cached_jobs', orderBy: 'updated_at DESC', limit: 20);
    return rows.map((row) => jsonDecode(row['payload'] as String) as Map<String, dynamic>).toList();
  }
}
