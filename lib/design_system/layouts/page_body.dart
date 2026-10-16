import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/services/workflow_sync_service.dart';

class PageBody extends StatefulWidget {
  const PageBody({
    super.key,
    required this.child,
    this.onRefresh,
    this.narrow = false,
  });
  final Widget child;
  final Future<void> Function()? onRefresh;
  final bool narrow;
  @override
  State<PageBody> createState() => _PageBodyState();
}

class _PageBodyState extends State<PageBody> with WidgetsBindingObserver {
  Timer? timer;
  Timer? changeDebounce;
  StreamSubscription<void>? changes;
  bool refreshing = false;
  bool refreshAgain = false;
  Future<void> refresh() async {
    if (!mounted ||
        !active ||
        !TickerMode.valuesOf(context).enabled ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    if (refreshing) {
      refreshAgain = true;
      return;
    }
    refreshing = true;
    try {
      await widget.onRefresh?.call();
    } finally {
      refreshing = false;
      if (refreshAgain) {
        refreshAgain = false;
        if (mounted) unawaited(refresh());
      }
    }
  }

  bool active = true;
  bool? wasVisible;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (wasVisible == false && visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRefresh?.call();
      });
    }
    wasVisible = visible;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    changes = WorkflowEvents.changes.listen((_) {
      changeDebounce?.cancel();
      changeDebounce = Timer(
        const Duration(milliseconds: 500),
        () => unawaited(refresh()),
      );
    });
    timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted &&
          active &&
          TickerMode.valuesOf(context).enabled &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        widget.onRefresh?.call();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed &&
        mounted &&
        TickerMode.valuesOf(context).enabled) {
      widget.onRefresh?.call();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    changes?.cancel();
    changeDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final view = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width < 600 ? 20 : 32,
        24,
        MediaQuery.sizeOf(context).width < 600 ? 20 : 32,
        36,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.narrow ? 560 : 1080),
          child: widget.child,
        ),
      ),
    );
    return SafeArea(
      top: Scaffold.maybeOf(context)?.hasAppBar != true,
      child: widget.onRefresh == null
          ? view
          : RefreshIndicator(onRefresh: widget.onRefresh!, child: view),
    );
  }
}
