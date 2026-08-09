import 'package:flutter/material.dart';

import 'package:eruditus/data/services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  final BackupService backupService;
  final Future<void> Function(String jsonContent) exportJson;
  final Future<String?> Function() importJson;

  const BackupScreen({
    super.key,
    required this.backupService,
    required this.exportJson,
    required this.importJson,
  });

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? _statusMessage;

  Future<void> _handleExport() async {
    final jsonString = await widget.backupService.exportToJson();
    await widget.exportJson(jsonString);
    setState(() => _statusMessage = 'Backup exported successfully.');
  }

  Future<void> _handleImport() async {
    final jsonString = await widget.importJson();
    if (jsonString == null) {
      setState(() => _statusMessage = 'Import cancelled.');
      return;
    }
    try {
      final result = await widget.backupService.importFromJson(jsonString);
      setState(() {
        _statusMessage = 'Imported ${result.spellsImported} spells, '
            '${result.effectsImported} effects, '
            '${result.parametersImported} parameters.'
            '${result.spellsRejected == 0 ? '' : ' Skipped ${result.spellsRejected} '
                'invalid spell(s): ${result.rejectedSpells.map((e) => e.spellId).join(', ')}'}';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Import failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              key: const Key('export-button'),
              onPressed: _handleExport,
              child: const Text('Export Backup to File'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('import-button'),
              onPressed: _handleImport,
              child: const Text('Import Backup from File'),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              Text(_statusMessage!, key: const Key('status-message')),
            ],
          ],
        ),
      ),
    );
  }
}
