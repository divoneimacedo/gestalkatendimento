import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/attendances_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/attendance_call.dart';
import '../widgets/app_shell.dart';
import '../widgets/shimmer_loading.dart';

class AttendancesScreen extends StatefulWidget {
  final String slug;

  const AttendancesScreen({super.key, required this.slug});

  @override
  State<AttendancesScreen> createState() => _AttendancesScreenState();
}

class _AttendancesScreenState extends State<AttendancesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AttendancesController>().load(slug: widget.slug);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AttendancesController>();
    final isAdmin = context.watch<AuthController>().user?.isAdmin ?? false;

    return AppShell(
      title: 'Atendimentos',
      slug: widget.slug,
      currentRoute: 'attendances',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: () => controller.refresh(slug: widget.slug),
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
                child: Text(
                  controller.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              Text(
                '${controller.total} atendimento(s)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Página ${controller.page} de ${controller.totalPages}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Página anterior',
                    onPressed: controller.canGoPrevious
                        ? () => controller.previousPage(slug: widget.slug)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    color: controller.canGoPrevious ? Colors.white : Colors.grey,
                  ),
                  IconButton(
                    tooltip: 'Próxima página',
                    onPressed: controller.canGoNext
                        ? () => controller.nextPage(slug: widget.slug)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    color: controller.canGoNext ? Colors.white : Colors.grey,
                  ),
                  if (controller.loading) ...[
                    const SizedBox(width: 12),
                    const Text(
                      'Atualizando...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: Stack(
                children: [
                  if (controller.calls.isEmpty && controller.loading)
                    TableShimmer(rows: 12, columns: isAdmin ? 7 : 6)
                  else if (controller.calls.isEmpty)
                    const Center(child: Text('Nenhum atendimento encontrado.'))
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: SingleChildScrollView(
                              child: DataTable(
                                columnSpacing: 48,
                                horizontalMargin: 24,
                                columns: [
                                  const DataColumn(label: Text('ID')),
                                  const DataColumn(label: Text('Protocolo')),
                                  const DataColumn(label: Text('Status')),
                                  const DataColumn(label: Text('Canal')),
                                  const DataColumn(
                                      label: Text('Hora de entrada')),
                                  const DataColumn(label: Text('Encerramento')),
                                  if (isAdmin)
                                    const DataColumn(label: Text('Ações')),
                                ],
                                showCheckboxColumn: false,
                                rows: controller.calls
                                    .map((call) => _row(context, call, isAdmin))
                                    .toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  if (controller.loading && controller.calls.isNotEmpty)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: 0.55),
                        child: TableShimmer(rows: 8, columns: isAdmin ? 7 : 6),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(BuildContext context, AttendanceCall call, bool isAdmin) {
    return DataRow(
      cells: [
        DataCell(Text(_shortId(call.id))),
        DataCell(Text(call.protocol.isEmpty ? '-' : call.protocol)),
        DataCell(_statusBadge(call.status)),
        DataCell(Text(call.channelName ?? '-')),
        DataCell(Text(_formatDate(call.createdAt))),
        DataCell(Text(_formatDate(call.endedAt))),
        if (isAdmin)
          DataCell(
            FilledButton.tonalIcon(
              onPressed: () => context.go('/call/${widget.slug}/${call.id}'),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir'),
            ),
          ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'FINISHED' => Colors.green,
      'CANCELED' => Colors.red,
      'IN_PROGRESS' => Colors.blue,
      'WAITING_FOR_RESPONSE' => Colors.orange,
      _ => Colors.grey,
    };

    return Chip(
      label: Text(_translateStatus(status)),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }

  String _shortId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(date.toLocal());
  }

  String _translateStatus(String status) {
    return switch (status) {
      'FINISHED' => 'Finalizado',
      'CANCELED' => 'Cancelado',
      'IN_PROGRESS' => 'Em atendimento',
      'WAITING_FOR_RESPONSE' => 'Aguardando',
      _ => status.isEmpty ? '-' : status,
    };
  }
}
