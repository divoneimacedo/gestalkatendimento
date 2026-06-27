import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../controllers/queue_controller.dart';
import '../core/config/app_theme.dart';
import '../models/queue_call.dart';
import '../widgets/app_shell.dart';

class QueueScreen extends StatefulWidget {
  final String slug;
  const QueueScreen({super.key, required this.slug});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<QueueController>()
          .refresh(slug: widget.slug, enableAlerts: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QueueController>();
    final auth = context.watch<AuthController>();

    return AppShell(
      title: 'Fila de atendimento',
      slug: widget.slug,
      currentRoute: 'queue',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: () =>
              controller.refresh(slug: widget.slug, enableAlerts: false),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.error != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(controller.error!,
                    style: const TextStyle(color: Colors.red)),
              ),
            ),
          Row(
            children: [
              Text('${controller.calls.length} chamada(s) aguardando',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const Spacer(),
              if (controller.loading)
                const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _tableWidth(context),
                  child: DataTable(
                    columnSpacing: 22,
                    horizontalMargin: 16,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    headingRowHeight: 48,
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Canal')),
                      DataColumn(label: Text('Prioridade')),
                      DataColumn(label: Text('Hora de entrada')),
                      DataColumn(label: Text('Tempo de espera')),
                      DataColumn(label: Text('Ações')),
                    ],
                    rows: controller.calls
                        .map((call) => _row(context, call, auth, controller))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(BuildContext context, QueueCall call, AuthController auth,
      QueueController controller) {
    final dateText = call.createdAt == null
        ? '-'
        : DateFormat('dd/MM/yyyy HH:mm').format(call.createdAt!.toLocal());

    return DataRow(cells: [
      DataCell(
        Tooltip(
          message: call.id,
          child: Text(
            _shortId(call.id),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      DataCell(_statusBadge(call.status)),
      DataCell(SizedBox(
        width: 150,
        child: Text(
          call.channelName ?? '-',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      )),
      DataCell(_priorityBadge(call.serviceTypePriority)),
      DataCell(Text(dateText)),
      DataCell(Text(call.waitingTime ?? '-')),
      DataCell(Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              minimumSize: const Size(42, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: () async {
              final attendantId = auth.user?.id ?? '';
              await controller.accept(call, attendantId);
              if (context.mounted) {
                context.go('/call/${widget.slug}/${call.id}');
              }
            },
            child: const Icon(Icons.call, size: 18),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.cancel,
              foregroundColor: Colors.white,
              minimumSize: const Size(42, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Você tem certeza?'),
                  content: const Text('Esta ação é irreversível.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Não')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sim, cancelar')),
                  ],
                ),
              );
              if (confirmed == true) {
                await controller.cancel(call.id, widget.slug);
              }
            },
            child: const Icon(Icons.close, size: 18),
          ),
        ],
      )),
    ]);
  }

  double _tableWidth(BuildContext context) {
    final available = MediaQuery.sizeOf(context).width - 28;
    return available < 980 ? 980 : available;
  }

  String _shortId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'WAITING_FOR_RESPONSE' => Colors.orange,
      'IN_PROGRESS' => Colors.blue,
      'FINISHED' => Colors.green,
      'CANCELED' => Colors.red,
      _ => Colors.grey,
    };

    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(_translateStatus(status)),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }

  Widget _priorityBadge(int priority) {
    final color = priority >= 100
        ? Colors.red
        : priority >= 50
            ? Colors.orange
            : priority > 0
                ? Colors.green
                : Colors.grey;
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text('$priority'),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color),
    );
  }

  String _translateStatus(String status) {
    return switch (status) {
      'WAITING_FOR_RESPONSE' => 'Aguardando',
      'IN_PROGRESS' => 'Em atendimento',
      'FINISHED' => 'Finalizado',
      'CANCELED' => 'Cancelado',
      _ => status.isEmpty ? '-' : status,
    };
  }
}
