import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/element_record.dart';
import '../models/element_group.dart';

class ElementDatabase {
  static final ElementDatabase instance = ElementDatabase._init();
  static Database? _database;

  ElementDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('elements.db');
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
    // Tabela de grupos (demandas/telas)
    await db.execute('''
      CREATE TABLE element_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at INTEGER NOT NULL,
        package_name TEXT,
        screen_name TEXT
      )
    ''');

    // Tabela de elementos
    await db.execute('''
      CREATE TABLE elements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER NOT NULL,
        text TEXT,
        path TEXT NOT NULL,
        position_left REAL NOT NULL,
        position_top REAL NOT NULL,
        position_right REAL NOT NULL,
        position_bottom REAL NOT NULL,
        className TEXT,
        view_id TEXT,
        clickable INTEGER DEFAULT 0,
        scrollable INTEGER DEFAULT 0,
        enabled INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        UNIQUE(group_id, path, text),
        FOREIGN KEY (group_id) REFERENCES element_groups(id) ON DELETE CASCADE
      )
    ''');

    // Índices para performance
    await db.execute('CREATE INDEX idx_elements_group ON elements(group_id)');
    await db.execute('CREATE INDEX idx_elements_path ON elements(path)');
    await db.execute('CREATE INDEX idx_elements_text ON elements(text)');
    await db.execute('CREATE INDEX idx_groups_created ON element_groups(created_at)');
  }

  // Criar novo grupo (demanda/tela)
  Future<ElementGroup> createGroup({
    String? packageName,
    String? screenName,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final id = await db.insert(
      'element_groups',
      {
        'created_at': now,
        'package_name': packageName,
        'screen_name': screenName,
      },
    );

    return ElementGroup(
      id: id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      packageName: packageName,
      screenName: screenName,
    );
  }

  // Salvar elementos de um snapshot (sem duplicatas)
  Future<void> saveElements(
    int groupId,
    List<ElementRecord> elements,
  ) async {
    final db = await database;

    // Usar transação para garantir atomicidade
    await db.transaction((txn) async {
      for (final element in elements) {
        // Verificar se já existe (UNIQUE constraint)
        // Se existir, ignorar (não inserir duplicata)
        try {
          await txn.insert(
            'elements',
            {
              'group_id': groupId,
              'text': element.text,
              'path': element.path,
              'position_left': element.positionLeft,
              'position_top': element.positionTop,
              'position_right': element.positionRight,
              'position_bottom': element.positionBottom,
              'className': element.className,
              'view_id': element.viewId,
              'clickable': element.clickable ? 1 : 0,
              'scrollable': element.scrollable ? 1 : 0,
              'enabled': element.enabled ? 1 : 0,
              'created_at': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore, // Ignorar duplicatas
          );
        } catch (e) {
          // Ignorar erros de duplicata
        }
      }
    });
  }

  // Buscar grupo mais recente ou criar novo
  Future<ElementGroup> getOrCreateCurrentGroup({
    String? packageName,
    String? screenName,
    Duration? groupTimeout,
  }) async {
    final db = await database;
    final timeout = groupTimeout ?? const Duration(seconds: 5);
    final timeoutMs = DateTime.now().millisecondsSinceEpoch - timeout.inMilliseconds;

    // Buscar grupo mais recente dentro do timeout
    final result = await db.query(
      'element_groups',
      where: 'created_at > ?',
      whereArgs: [timeoutMs],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      final row = result.first;
      return ElementGroup.fromMap(row);
    }

    // Criar novo grupo se não houver um recente
    return await createGroup(
      packageName: packageName,
      screenName: screenName,
    );
  }

  // Buscar elementos de um grupo
  Future<List<ElementRecord>> getElementsByGroup(int groupId) async {
    final db = await database;
    final result = await db.query(
      'elements',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'created_at ASC',
    );

    return result.map((row) => ElementRecord.fromMap(row)).toList();
  }

  // Buscar todos os grupos
  Future<List<ElementGroup>> getAllGroups() async {
    final db = await database;
    final result = await db.query(
      'element_groups',
      orderBy: 'created_at DESC',
    );

    return result.map((row) => ElementGroup.fromMap(row)).toList();
  }

  // Deletar grupo e seus elementos
  Future<void> deleteGroup(int groupId) async {
    final db = await database;
    await db.delete(
      'element_groups',
      where: 'id = ?',
      whereArgs: [groupId],
    );
  }

  // Buscar elementos por texto (busca)
  Future<List<ElementRecord>> searchElements(String query) async {
    final db = await database;
    final result = await db.query(
      'elements',
      where: 'text LIKE ? OR path LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );

    return result.map((row) => ElementRecord.fromMap(row)).toList();
  }

  // Fechar banco
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

