import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calendar_inbox_provider.dart';
import '../services/googleCalendarService.dart';
import '../models/calendar_event_proposal.dart';
import '../widgets/editable_calendar_event_sheet.dart';

class CalendarInboxPage extends StatelessWidget {
  const CalendarInboxPage({super.key});

  String _formatDateTime(CalendarEventProposal p) {
    final dt = p.start.toDateTime;
    if (dt != null) {
      final two = (int n) => n.toString().padLeft(2, '0');
      return '${dt.year}/${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
    }
    if (p.start.date != null) return p.start.date!; // 終日
    return '日時未設定';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('インボックス', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
      ),
      body: Consumer<CalendarInboxProvider>(
        builder: (context, inbox, _) {
          final items = inbox.items;
          if (items.isEmpty) {
            return const Center(
              child: Text('インボックスは空です', style: TextStyle(color: Colors.black54)),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final p = item.proposal;
              return ListTile(
                title: Text(p.summary, style: const TextStyle(color: Colors.black87)),
                subtitle: Text(
                  _formatDateTime(p) + (p.location != null && p.location!.isNotEmpty ? ' @ ${p.location}' : ''),
                  style: const TextStyle(color: Colors.black54),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () async {
                        await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) {
                            return EditableCalendarEventSheet(
                              proposal: p,
                              uiService: null,
                              onConfirm: (updated) {
                                // 設定のみ保存して閉じる
                                context.read<CalendarInboxProvider>().updateProposal(item.id, updated);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('設定を保存しました: ${updated.summary}')),
                                  );
                                }
                              },
                            );
                          },
                        );
                      },
                      child: const Text('編集'),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          final svc = GoogleCalendarService();
                          await svc.createEventFromProposal(p);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('カレンダーに追加しました: ${p.summary}')),
                            );
                            context.read<CalendarInboxProvider>().removeById(item.id);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('追加に失敗しました: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('追加'),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<CalendarInboxProvider>().removeById(item.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('削除しました: ${p.summary}')),
                        );
                      },
                      child: const Text('削除'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
