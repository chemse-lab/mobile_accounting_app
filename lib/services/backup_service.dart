import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../db/database_helper.dart';

/// خدمة النسخ الاحتياطي واستعادة قاعدة البيانات
/// تتيح للبائع حفظ نسخة من بياناته (محلياً أو عبر مشاركتها على Google Drive / WhatsApp)
/// واستعادتها لاحقاً في حال تغيير الجهاز أو فقدان البيانات.
class BackupService {
  /// إنشاء نسخة احتياطية ومشاركتها عبر أي تطبيق (Drive، WhatsApp، بريد...)
  static Future<void> exportAndShare() async {
    final dbPath = await DatabaseHelper.instance.getDbPath();
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception('قاعدة البيانات غير موجودة');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final backupName = 'نسخة_احتياطية_$timestamp.db';
    final backupFile = await dbFile.copy('${tempDir.path}/$backupName');

    await Share.shareXFiles(
      [XFile(backupFile.path)],
      text: 'نسخة احتياطية من تطبيق المحاسبة بتاريخ ${DateFormatter_shortDate(DateTime.now())}',
      subject: 'نسخة احتياطية - تطبيق المحاسبة',
    );
  }

  /// اختيار ملف نسخة احتياطية من الجهاز واستعادته (سيستبدل البيانات الحالية بالكامل)
  /// يُرجع true عند النجاح
  static Future<bool> pickAndRestore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );

    if (result == null || result.files.single.path == null) {
      return false; // المستخدم ألغى الاختيار
    }

    final pickedPath = result.files.single.path!;
    final pickedFile = File(pickedPath);

    if (!pickedPath.endsWith('.db')) {
      throw Exception('الملف المختار ليس نسخة احتياطية صالحة (.db)');
    }

    // إغلاق الاتصال الحالي بقاعدة البيانات قبل الاستبدال
    await DatabaseHelper.instance.closeDb();

    final dbPath = await DatabaseHelper.instance.getDbPath();
    await pickedFile.copy(dbPath);

    // إعادة فتح الاتصال بالقاعدة الجديدة (سيتم تلقائياً عند أول استخدام)
    await DatabaseHelper.instance.database;

    return true;
  }

  /// حفظ نسخة احتياطية محلياً في مجلد التطبيق (بدون مشاركة) - نسخ تلقائية دورية
  static Future<String> saveLocalBackup() async {
    final dbPath = await DatabaseHelper.instance.getDbPath();
    final dbFile = File(dbPath);

    final docsDir = await getApplicationDocumentsDirectory();
    final backupsDir = Directory('${docsDir.path}/backups');
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final backupPath = '${backupsDir.path}/backup_$timestamp.db';
    await dbFile.copy(backupPath);
    return backupPath;
  }
}

String DateFormatter_shortDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
