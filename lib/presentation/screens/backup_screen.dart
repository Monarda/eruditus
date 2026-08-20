import 'package:flutter/material.dart';

import 'package:eruditus/data/services/backup_service.dart';
import 'package:eruditus/l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    final jsonString = await widget.backupService.exportToJson();
    await widget.exportJson(jsonString);
    setState(() => _statusMessage = l10n.backupExported);
  }

  Future<void> _handleImport() async {
    final l10n = AppLocalizations.of(context);
    final jsonString = await widget.importJson();
    if (jsonString == null) {
      setState(() => _statusMessage = l10n.backupImportCancelled);
      return;
    }
    try {
      final result = await widget.backupService.importFromJson(jsonString);
      setState(() {
        _statusMessage = l10n.backupImported(
              result.spellsImported,
              result.effectsImported,
              result.parametersImported,
            ) +
            l10n.backupRejectedSpells(
              result.spellsRejected,
              result.rejectedSpells.map((e) => e.spellId).join(', '),
            );
      });
    } catch (e) {
      setState(() => _statusMessage = l10n.backupImportFailed(e.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              key: const Key('export-button'),
              onPressed: _handleExport,
              child: Text(l10n.exportBackupToFile),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('import-button'),
              onPressed: _handleImport,
              child: Text(l10n.importBackupFromFile),
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
