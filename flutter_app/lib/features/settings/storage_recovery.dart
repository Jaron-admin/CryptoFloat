import 'package:flutter/material.dart';

import '../../data/storage_location.dart';

/// Startup cannot guess a data location when its selector is damaged/unreadable.
class StorageRecoveryApp extends StatefulWidget {
  const StorageRecoveryApp({
    super.key,
    required this.root,
    required this.onRecovered,
  });
  final DataRoot root;
  final Future<void> Function() onRecovered;
  @override
  State<StorageRecoveryApp> createState() => _StorageRecoveryAppState();
}

class _StorageRecoveryAppState extends State<StorageRecoveryApp> {
  bool _busy = false;
  bool _failed = false;
  bool get _chinese =>
      WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'zh';

  Future<void> _select(DataStorageMode mode) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await persistStorageMode(widget.root, mode);
      await widget.onRecovered();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DuoMonitor',
    home: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _chinese ? '选择要打开的数据位置' : 'Choose the data location to open',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _chinese
                      ? '无法读取或准备已保存的数据位置。请选择要打开的文件夹；现有设置和文件会保留，此操作不会复制或覆盖它们。'
                      : 'The saved data location could not be read or prepared. Choose a folder to open. Existing settings and files are retained without copying or replacing them.',
                ),
                const SizedBox(height: 20),
                for (final mode in DataStorageMode.values) ...[
                  FilledButton(
                    onPressed: _busy ? null : () => _select(mode),
                    child: Text(
                      mode == DataStorageMode.portable
                          ? (_chinese ? '打开便携数据' : 'Open portable data')
                          : (_chinese ? '打开系统应用数据' : 'Open system app data'),
                    ),
                  ),
                  SelectableText(widget.root.directoryFor(mode)),
                  const SizedBox(height: 16),
                ],
                if (_failed)
                  Text(
                    _chinese ? '无法保存选择，请检查文件夹的写入权限后重试。' : 'Could not save the selection. Check folder write permissions and retry.',
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
