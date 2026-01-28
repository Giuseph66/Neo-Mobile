import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/automation_models.dart';

class AutomationDatabase {
  static final AutomationDatabase instance = AutomationDatabase._init();
  static Database? _database;

  AutomationDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('automation_scheduled.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Routines
    await db.execute('''
      CREATE TABLE routines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        target_app_package TEXT,
        enabled INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // 2. Steps
    await db.execute('''
      CREATE TABLE steps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id INTEGER NOT NULL,
        step_order INTEGER NOT NULL,
        type TEXT NOT NULL,
        selector_ref TEXT,
        params TEXT NOT NULL,
        timeout_ms INTEGER DEFAULT 5000,
        retry_count INTEGER DEFAULT 0,
        FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE
      )
    ''');

    // 3. Triggers
    await db.execute('''
      CREATE TABLE triggers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id INTEGER NOT NULL,
        enabled INTEGER DEFAULT 1,
        type TEXT NOT NULL,
        time_of_day TEXT,
        days_of_week TEXT,
        start_date INTEGER,
        end_date INTEGER,
        constraints TEXT NOT NULL,
        FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE
      )
    ''');

    // 4. Runs
    await db.execute('''
      CREATE TABLE runs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id INTEGER NOT NULL,
        trigger_id INTEGER,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        status TEXT NOT NULL,
        error_summary TEXT,
        FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE,
        FOREIGN KEY (trigger_id) REFERENCES triggers(id) ON DELETE SET NULL
      )
    ''');

    // 5. Step Logs
    await db.execute('''
      CREATE TABLE step_logs (
        run_id INTEGER NOT NULL,
        step_id INTEGER NOT NULL,
        status TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER NOT NULL,
        error TEXT,
        debug_data TEXT NOT NULL,
        PRIMARY KEY (run_id, step_id),
        FOREIGN KEY (run_id) REFERENCES runs(id) ON DELETE CASCADE
      )
    ''');

    // Indices
    await db.execute('CREATE INDEX idx_steps_routine ON steps(routine_id)');
    await db.execute('CREATE INDEX idx_triggers_routine ON triggers(routine_id)');
    await db.execute('CREATE INDEX idx_runs_routine ON runs(routine_id)');
    await db.execute('CREATE INDEX idx_logs_run ON step_logs(run_id)');
  }

  // Routine CRUD
  Future<AutomationRoutine> createRoutine(AutomationRoutine routine) async {
    final db = await database;
    final id = await db.insert('routines', routine.toMap());
    return AutomationRoutine.fromMap({...routine.toMap(), 'id': id});
  }

  Future<List<AutomationRoutine>> getAllRoutines() async {
    final db = await database;
    final result = await db.query('routines', orderBy: 'updated_at DESC');
    return result.map((row) => AutomationRoutine.fromMap(row)).toList();
  }

  Future<void> updateRoutine(AutomationRoutine routine) async {
    final db = await database;
    await db.update(
      'routines',
      routine.toMap(),
      where: 'id = ?',
      whereArgs: [routine.id],
    );
  }

  Future<void> deleteRoutine(int id) async {
    final db = await database;
    await db.delete('routines', where: 'id = ?', whereArgs: [id]);
  }

  Future<AutomationRoutine> duplicateRoutine(int routineId) async {
    final originalSteps = await getStepsForRoutine(routineId);
    final allRoutines = await getAllRoutines();
    final original = allRoutines.firstWhere((r) => r.id == routineId);

    final duplicate = AutomationRoutine(
      name: '${original.name} (Cópia)',
      description: original.description,
      targetAppPackage: original.targetAppPackage,
      enabled: original.enabled,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final created = await createRoutine(duplicate);
    
    final duplicatedSteps = originalSteps.map((s) => AutomationStep(
      routineId: created.id!,
      order: s.order,
      type: s.type,
      selectorRef: s.selectorRef,
      params: s.params,
      timeoutMs: s.timeoutMs,
      retryCount: s.retryCount,
    )).toList();

    await updateSteps(created.id!, duplicatedSteps);
    return created;
  }

  // Steps
  Future<void> updateSteps(int routineId, List<AutomationStep> steps) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('steps', where: 'routine_id = ?', whereArgs: [routineId]);
      for (final step in steps) {
        await txn.insert('steps', step.toMap());
      }
    });
  }

  Future<List<AutomationStep>> getStepsForRoutine(int routineId) async {
    final db = await database;
    final result = await db.query(
      'steps',
      where: 'routine_id = ?',
      whereArgs: [routineId],
      orderBy: 'step_order ASC',
    );
    return result.map((row) => AutomationStep.fromMap(row)).toList();
  }

  // Triggers
  Future<void> addTrigger(AutomationTrigger trigger) async {
    final db = await database;
    await db.insert('triggers', trigger.toMap());
  }

  Future<List<AutomationTrigger>> getTriggersForRoutine(int routineId) async {
    final db = await database;
    final result = await db.query(
      'triggers',
      where: 'routine_id = ?',
      whereArgs: [routineId],
    );
    return result.map((row) => AutomationTrigger.fromMap(row)).toList();
  }

  // Runs
  Future<int> startRun(AutomationRun run) async {
    final db = await database;
    return await db.insert('runs', run.toMap());
  }

  Future<void> updateRun(AutomationRun run) async {
    final db = await database;
    await db.update(
      'runs',
      run.toMap(),
      where: 'id = ?',
      whereArgs: [run.id],
    );
  }

  Future<List<AutomationRun>> getRunsForRoutine(int routineId) async {
    final db = await database;
    final result = await db.query(
      'runs',
      where: 'routine_id = ?',
      whereArgs: [routineId],
      orderBy: 'started_at DESC',
      limit: 50,
    );
    return result.map((row) => AutomationRun.fromMap(row)).toList();
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
