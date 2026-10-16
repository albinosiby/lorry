import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Invalidation only: screens always reload through their own repositories.
class WorkflowEvents {
  static final _controller = StreamController<void>.broadcast();
  static Stream<void> get changes => _controller.stream;
  static void changed() => _controller.add(null);
}

class WorkflowSyncService {
  WorkflowSyncService(this.client);
  final SupabaseClient client;
  RealtimeChannel? _channel;
  String? _user;
  int _generation = 0;
  Future<void> start(String user) async {
    if (_user == user) return;
    final generation = ++_generation;
    _user = user;
    final previous = _channel;
    _channel = null;
    if (previous != null) await client.removeChannel(previous);
    if (generation != _generation) return;
    _channel = client
        .channel('workflow-$user')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: user,
          ),
          callback: (_) {
            if (_user == user && client.auth.currentUser?.id == user) {
              WorkflowEvents.changed();
            }
          },
        )
        .subscribe((status, error) {
          // Reload on reconnect too: changes while disconnected may be missed.
          if (status == RealtimeSubscribeStatus.subscribed && _user == user) {
            WorkflowEvents.changed();
          }
        });
  }

  Future<void> stop() async {
    ++_generation;
    _user = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) await client.removeChannel(channel);
  }
}
