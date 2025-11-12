import 'dart:collection';
import 'package:flutter/material.dart';
import '../models/calendar_event_proposal.dart';

class InboxItem {
  final String id;
  CalendarEventProposal proposal;
  final DateTime createdAt;

  InboxItem({required this.id, required this.proposal, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();
}

class CalendarInboxProvider with ChangeNotifier {
  final List<InboxItem> _items = [];

  UnmodifiableListView<InboxItem> get items => UnmodifiableListView(_items);
  int get pendingCount => _items.length;

  String _makeId(CalendarEventProposal p) {
    final start = p.start.toDateTime?.toIso8601String() ?? p.start.date ?? '';
    return '${p.summary}|$start|${p.location ?? ''}'.toLowerCase();
  }

  void add(CalendarEventProposal proposal) {
    final id = _makeId(proposal);
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      _items[idx].proposal = proposal; // 上書き
    } else {
      _items.insert(0, InboxItem(id: id, proposal: proposal));
    }
    notifyListeners();
  }

  void addAll(List<CalendarEventProposal> proposals) {
    for (final p in proposals) {
      add(p);
    }
  }

  void removeById(String id) {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void updateProposal(String id, CalendarEventProposal updated) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      _items[idx].proposal = updated;
      notifyListeners();
    }
  }
}
