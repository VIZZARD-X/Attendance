import 'dart:io';
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'attendance_service.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  // Stream to notify listeners when a sync completes
  final _syncCompleteController = StreamController<void>.broadcast();
  Stream<void> get onSyncComplete => _syncCompleteController.stream;

  Database? _database;
  final AttendanceService _attendanceService = AttendanceService();
  Timer? _syncTimer;
  bool _isSyncing = false;

  SyncService._internal() {
    _startPeriodicSync();
  }

  void _startPeriodicSync() {
    if (kIsWeb) return;
    // Try to sync every 30 seconds automatically for edge cases where the user remains online
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      syncQueueToServer();
    });
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_sync.db');

    return await openDatabase(
      path,
      version: 4,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS offline_sessions (
              id TEXT PRIMARY KEY,
              class_id INTEGER NOT NULL,
              class_type TEXT NOT NULL,
              duration_minutes INTEGER NOT NULL,
              start_time TEXT NOT NULL,
              end_time TEXT NOT NULL,
              shape_data TEXT,
              reference_image_path TEXT,
              status TEXT DEFAULT 'pending'
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS offline_qr_queue (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_id TEXT NOT NULL,
              timestamp TEXT NOT NULL,
              status TEXT DEFAULT 'pending'
            )
          ''');
        }
        if (oldVersion < 4) {
          try {
            await db.execute(
                'ALTER TABLE offline_sessions ADD COLUMN class_type TEXT NOT NULL DEFAULT "qr"');
          } catch (e) {
            // Ignore if column already exists
          }
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE offline_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            status TEXT DEFAULT 'pending'
          )
        ''');
        await db.execute('''
          CREATE TABLE offline_sessions (
            id TEXT PRIMARY KEY,
            class_id INTEGER NOT NULL,
            class_type TEXT NOT NULL,
            duration_minutes INTEGER NOT NULL,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            shape_data TEXT,
            reference_image_path TEXT,
            status TEXT DEFAULT 'pending'
          )
        ''');
        await db.execute('''
          CREATE TABLE offline_qr_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            status TEXT DEFAULT 'pending'
          )
        ''');
      },
    );
  }

  Future<void> enqueueOfflineSession(Map<String, dynamic> sessionData) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('offline_sessions', {
      'id': sessionData['id'],
      'class_id': sessionData['class_id'],
      'class_type': sessionData['class_type'],
      'duration_minutes': sessionData['duration_minutes'],
      'start_time': sessionData['start_time'],
      'end_time': sessionData['end_time'],
      'shape_data': sessionData['shape_data'],
      'status': 'pending',
    });
    debugPrint('Queued offline session ${sessionData['id']}');
  }

  Future<void> enqueuePatternScan(String imagePath, String timestamp) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('offline_queue', {
      'image_path': imagePath,
      'timestamp': timestamp,
      'status': 'pending',
    });
    debugPrint('Queued offline pattern scan at $timestamp');
  }

  Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM offline_queue WHERE status = ?',
      ['pending'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> enqueueSession({
    required String id,
    required int classId,
    required String classType,
    required int durationMinutes,
    required String startTime,
    required String endTime,
    String? shapeData,
  }) async {
    final db = await database;
    await db.insert('offline_sessions', {
      'id': id,
      'class_id': classId,
      'class_type': classType,
      'duration_minutes': durationMinutes,
      'start_time': startTime,
      'end_time': endTime,
      'shape_data': shapeData,
      'status': 'pending',
    });
    debugPrint('Queued offline session $id');
  }

  Future<void> updateSessionReferenceImage(String id, String imagePath) async {
    final db = await database;
    await db.update(
      'offline_sessions',
      {'reference_image_path': imagePath},
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('Updated offline session $id with reference image');
  }

  Future<void> syncQueueToServer() async {
    if (kIsWeb) return;
    if (_isSyncing) return;
    _isSyncing = true;
    bool anythingSynced = false;
    
    try {
      final db = await database;

      // 1. Sync Sessions First
      final pendingSessions = await db.query(
      'offline_sessions',
      where: 'status = ?',
      whereArgs: ['pending'],
    );
    if (pendingSessions.isNotEmpty) {
      debugPrint(
        'Found ${pendingSessions.length} pending offline sessions. Attempting sync...',
      );
      for (var session in pendingSessions) {
        final id = session['id'] as String;
        final classId = session['class_id'] as int;
        final classType = session['class_type'] as String;
        final durationMinutes = session['duration_minutes'] as int;
        final startTime = session['start_time'] as String;
        final endTime = session['end_time'] as String;
        final shapeData = session['shape_data'] as String?;
        final referenceImagePath = session['reference_image_path'] as String?;

        try {
          final result = await _attendanceService.syncOfflineSession(
            sessionId: id,
            classId: classId,
            classType: classType,
            durationMinutes: durationMinutes,
            startTime: startTime,
            endTime: endTime,
            shapeData: shapeData,
            referenceImagePath: referenceImagePath,
          );

          if (result['success']) {
            await db.update(
              'offline_sessions',
              {'status': 'synced'},
              where: 'id = ?',
              whereArgs: [id],
            );
            debugPrint('Successfully synced offline session $id');
            anythingSynced = true;
          } else {
            debugPrint(
              'Failed to sync offline session $id: ${result['message']}',
            );
          }
        } catch (e) {
          debugPrint('Error syncing offline session $id: $e');
        }
      }
    }

    // 2. Sync Pattern Scans
    final pendingRecords = await db.query(
      'offline_queue',
      where: 'status = ?',
      whereArgs: ['pending'],
    );

    if (pendingRecords.isNotEmpty) {
      debugPrint(
        'Found ${pendingRecords.length} pending offline pattern scans. Attempting sync...',
      );
      for (var record in pendingRecords) {
        final id = record['id'] as int;
        final imagePath = record['image_path'] as String;
        final timestamp = record['timestamp'] as String;
        
        // Check 24-hour expiration
        final scanTime = DateTime.parse(timestamp);
        if (DateTime.now().toUtc().difference(scanTime.toUtc()).inHours >= 24) {
          debugPrint('Discarding expired pattern scan $id (older than 24 hours)');
          await db.delete('offline_queue', where: 'id = ?', whereArgs: [id]);
          continue;
        }

        // Check if image exists
        final file = File(imagePath);
        if (!await file.exists()) {
          debugPrint(
            'Image file not found for queued record $id, marking as failed.',
          );
          await db.update(
            'offline_queue',
            {'status': 'failed_file_missing'},
            where: 'id = ?',
            whereArgs: [id],
          );
          continue;
        }

        try {
          final result = await _attendanceService.syncOfflinePattern(
            imagePath: imagePath,
            timestamp: timestamp,
          );

          if (result['success']) {
            await db.update(
              'offline_queue',
              {'status': 'synced'},
              where: 'id = ?',
              whereArgs: [id],
            );
            debugPrint('Successfully synced record $id');
            anythingSynced = true;
          } else {
            debugPrint('Failed to sync record $id: ${result['message']}');
          }
        } catch (e) {
          debugPrint('Error syncing record $id: $e');
        }
      }
    }

    // 3. Sync QR Scans
    final pendingQrScans = await db.query(
      'offline_qr_queue',
      where: 'status = ?',
      whereArgs: ['pending'],
    );
    if (pendingQrScans.isNotEmpty) {
      debugPrint(
        'Found ${pendingQrScans.length} pending offline QR scans. Attempting sync...',
      );
      for (var record in pendingQrScans) {
        final id = record['id'] as int;
        final sessionId = record['session_id'] as String;
        final timestamp = record['timestamp'] as String;

        // Check 24-hour expiration
        final scanTime = DateTime.parse(timestamp);
        if (DateTime.now().toUtc().difference(scanTime.toUtc()).inHours >= 24) {
          debugPrint('Discarding expired QR scan $id (older than 24 hours)');
          await db.delete('offline_qr_queue', where: 'id = ?', whereArgs: [id]);
          continue;
        }

        try {
          final result = await _attendanceService.markAttendance(
            sessionId,
            isOfflineSync: true,
            timestamp: timestamp,
          );
          if (result['success']) {
            await db.update(
              'offline_qr_queue',
              {'status': 'synced'},
              where: 'id = ?',
              whereArgs: [id],
            );
            debugPrint('Successfully synced QR record $id');
            anythingSynced = true;
          } else {
            debugPrint('Failed to sync QR record $id: ${result['message']}');
          }
        } catch (e) {
          debugPrint('Error syncing QR record $id: $e');
        }
      }
    }
    } finally {
      _isSyncing = false;
      // Notify listeners only if something was actually synced
      if (anythingSynced) {
        _syncCompleteController.add(null);
      }
    }
  }

  Future<void> enqueueQRScan(String sessionId, String timestamp) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert('offline_qr_queue', {
      'session_id': sessionId,
      'timestamp': timestamp,
      'status': 'pending',
    });
    debugPrint('Queued offline QR scan for session $sessionId');
  }
}
