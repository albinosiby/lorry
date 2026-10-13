import '../../loads/models/load_model.dart';

class HomeModel {
  const HomeModel({
    required this.open,
    required this.active,
    required this.completed,
    required this.pending,
    required this.unread,
    required this.loads,
  });
  final int open, active, completed, pending, unread;
  final List<LoadModel> loads;
  factory HomeModel.fromJson(Map<String, dynamic> j) => HomeModel(
    open: j['open_count'],
    active: j['active_count'],
    completed: j['completed_count'],
    pending: j['pending_count'],
    unread: j['unread_count'],
    loads: (j['loads'] as List).map((l) => LoadModel.fromJson(l)).toList(),
  );
}
