import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../downloader.dart';
import 'theme.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final dl = context.watch<Downloader>();
    final tasks = dl.tasks.values.toList();
    return Scaffold(appBar: AppBar(
      title: Text('下载 (${tasks.length})'),
      actions: [
        if (tasks.isNotEmpty) IconButton(
          icon: const Icon(Icons.cleaning_services_outlined),
          tooltip: '清除已完成', onPressed: () => dl.clearAllDone()),
      ]),
      body: tasks.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.download_outlined, size: 72,
              color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('还没有下载',
              style: TextStyle(color: Colors.white.withOpacity(0.55))),
            const SizedBox(height: 20),
            Text('保存位置：/storage/emulated/0/Music/KuGou/',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.25))),
          ]))
        : ListView.builder(padding: const EdgeInsets.all(12),
          itemCount: tasks.length, itemBuilder: (_, i) => _card(tasks[i])));
  }
  Widget _card(DownloadTask t) {
    Color c; IconData ic; String st;
    switch (t.status) {
      case 'resolving': c = Colors.amber; ic = Icons.search; st = '获取链接…'; break;
      case 'downloading': c = AppTheme.primary; ic = Icons.downloading;
        st = '${(t.progress * 100).toStringAsFixed(0)}%  '
            '${_f(t.received)}/${_f(t.total)}'; break;
      case 'done': c = Colors.greenAccent; ic = Icons.check_circle; st = '已完成'; break;
      case 'failed': c = Colors.redAccent; ic = Icons.error_outline;
        st = '失败: ${t.error ?? ""}'; break;
      default: c = Colors.white54; ic = Icons.hourglass_empty; st = '等待中';
    }
    return Container(margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ic, color: c, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(t.display, maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          IconButton(icon: const Icon(Icons.close, size: 18),
            onPressed: () => Downloader.I.clearTask(t.hash)),
        ]),
        const SizedBox(height: 6),
        Text(st, style: TextStyle(fontSize: 12, color: c)),
        if (t.status == 'downloading') ...[
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: t.progress, minHeight: 4,
              backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation(c))),
        ],
        if (t.status == 'done' && t.filePath != null) ...[
          const SizedBox(height: 6),
          Text(t.filePath!, style: TextStyle(fontSize: 10.5,
            color: Colors.white.withOpacity(0.4))),
        ],
      ]));
  }
  String _f(int b) {
    if (b < 1024) return '${b}B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)}KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)}MB';
  }
}
