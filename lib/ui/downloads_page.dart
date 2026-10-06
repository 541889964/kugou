import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../downloader.dart';
import 'theme.dart';
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final dl = context.watch<Downloader>();
    final ts = dl.tasks.values.toList();
    return Scaffold(
      appBar: AppBar(title: Text('下载 (${ts.length})'), actions: [
        if (ts.isNotEmpty) IconButton(icon: const Icon(Icons.cleaning_services_outlined),
          onPressed: () => dl.clearAllDone()),
      ]),
      body: ts.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.download_outlined, size: 80, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 20),
            Text('还没有下载', style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 15)),
            const SizedBox(height: 20),
            Text('保存位置：/storage/emulated/0/Music/KuGou/',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3))),
          ]))
        : ListView.builder(padding: const EdgeInsets.all(12),
            itemCount: ts.length, itemBuilder: (_, i) => _c(ts[i])),
    );
  }
  Widget _c(DownloadTask t) {
    Color c; IconData i; String s;
    switch (t.status) {
      case 'resolving': c = Colors.amber; i = Icons.search; s = '获取链接…'; break;
      case 'downloading': c = AppTheme.p; i = Icons.downloading; s = '${(t.progress*100).toStringAsFixed(0)}%'; break;
      case 'done': c = Colors.greenAccent; i = Icons.check_circle; s = '已完成'; break;
      case 'failed': c = Colors.redAccent; i = Icons.error_outline; s = '失败: ${t.error ?? ""}'; break;
      default: c = Colors.white54; i = Icons.hourglass_empty; s = '等待中';
    }
    return Container(margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(i, color: c, size: 22), const SizedBox(width: 12),
          Expanded(child: Text(t.display, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          IconButton(icon: const Icon(Icons.close, size: 20),
            onPressed: () => Downloader.I.clearTask(t.hash)),
        ]),
        const SizedBox(height: 8),
        Text(s, style: TextStyle(fontSize: 12, color: c)),
        if (t.status == 'downloading') Padding(padding: const EdgeInsets.only(top: 10),
          child: ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: t.progress, minHeight: 5,
              backgroundColor: Colors.white10, valueColor: AlwaysStoppedAnimation(c)))),
      ]));
  }
}
