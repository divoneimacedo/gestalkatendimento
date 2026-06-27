import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/reports_controller.dart';
import '../core/config/app_theme.dart';
import '../models/report_call.dart';
import '../models/report_metrics.dart';
import '../services/report_pdf_service.dart';
import '../services/report_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/shimmer_loading.dart';

class ReportsScreen extends StatefulWidget {
  final String slug;

  const ReportsScreen({super.key, required this.slug});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _searchController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();
      final controller = context.read<ReportsController>();
      controller.loadOptions();
      controller.load(
        user: auth.user,
        slug: widget.slug,
        resetPage: true,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final controller = context.watch<ReportsController>();

    return AppShell(
      title: 'Relatórios',
      slug: widget.slug,
      currentRoute: 'reports',
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: controller.loading
              ? null
              : () => controller.refresh(user: auth.user, slug: widget.slug),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.error != null) _errorCard(controller.error!),
            _filters(context, controller, auth),
            const SizedBox(height: 16),
            _metrics(controller),
            const SizedBox(height: 16),
            _charts(controller),
            const SizedBox(height: 16),
            _rankingChart(controller),
            const SizedBox(height: 16),
            _interpretersTable(controller),
            const SizedBox(height: 16),
            _resultsSection(controller, auth),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String message) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _metrics(ReportsController controller) {
    final metrics = controller.metrics;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final cards = [
          _MetricCard(
            label: 'Total de chamadas',
            value: metrics.totalCalls.toString(),
            icon: Icons.call_outlined,
          ),
          _MetricCard(
            label: 'Atendidas',
            value: metrics.attendedCount.toString(),
            icon: Icons.check_circle_outline,
          ),
          _MetricCard(
            label: 'Não atendidas',
            value: metrics.notAttendedCount.toString(),
            icon: Icons.cancel_outlined,
          ),
          _MetricCard(
            label: 'Taxa de atendimento',
            value: '${metrics.attendedRate}%',
            icon: Icons.trending_up,
          ),
          _MetricCard(
            label: 'TME médio',
            value: metrics.tmeAvg,
            icon: Icons.hourglass_bottom,
          ),
          _MetricCard(
            label: 'TMA médio',
            value: metrics.tmaAvg,
            icon: Icons.timer_outlined,
          ),
        ];

        return GridView.count(
          crossAxisCount: narrow ? 2 : 6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: narrow ? 2.8 : 1.55,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }

  Widget _filters(
    BuildContext context,
    ReportsController controller,
    AuthController auth,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _quickFilterChip(
                  label: 'Hoje',
                  onTap: () => _applyQuickPeriod(controller, auth, days: 1),
                ),
                _quickFilterChip(
                  label: 'Última Semana',
                  onTap: () => _applyQuickPeriod(controller, auth, days: 7),
                ),
                _quickFilterChip(
                  label: 'Último Mês',
                  onTap: () => _applyQuickPeriod(controller, auth, days: 30),
                ),
                _quickFilterChip(
                  label: 'Último Trimestre',
                  onTap: () => _applyQuickPeriod(controller, auth, days: 90),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _dateButton(
                  label: 'Data Inicial',
                  date: controller.filters.startDate,
                  onTap: () => _pickDate(
                    current: controller.filters.startDate,
                    onSelected: (date) => controller.applyFilters(
                      user: auth.user,
                      slug: widget.slug,
                      startDate: date,
                    ),
                  ),
                  onClear: null,
                ),
                _dateButton(
                  label: 'Data Final',
                  date: controller.filters.endDate,
                  onTap: () => _pickDate(
                    current: controller.filters.endDate,
                    onSelected: (date) => controller.applyFilters(
                      user: auth.user,
                      slug: widget.slug,
                      endDate: date,
                    ),
                  ),
                  onClear: null,
                ),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<String>(
                    initialValue: controller.filters.status ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem<String>(value: '', child: Text('Todos')),
                      DropdownMenuItem<String>(
                        value: 'FINISHED',
                        child: Text('Finalizado'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'CANCELED',
                        child: Text('Cancelado'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'IN_PROGRESS',
                        child: Text('Em atendimento'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'WAITING_FOR_RESPONSE',
                        child: Text('Aguardando'),
                      ),
                    ],
                    onChanged: (value) => controller.applyFilters(
                      user: auth.user,
                      slug: widget.slug,
                      status: value,
                      clearStatus: value == null || value.isEmpty,
                    ),
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<String>(
                    initialValue: controller.filters.channelId ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Canal',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Todos os canais'),
                      ),
                      ..._optionItems(controller.filterOptions.channels),
                    ],
                    onChanged: (value) => controller.applyFilters(
                      user: auth.user,
                      slug: widget.slug,
                      channelId: value,
                      clearChannel: value == null || value.isEmpty,
                    ),
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<String>(
                    initialValue: controller.filters.attendantId ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Intérprete',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Todos os intérpretes'),
                      ),
                      ..._optionItems(controller.filterOptions.interpreters),
                    ],
                    onChanged: (value) => controller.applyFilters(
                      user: auth.user,
                      slug: widget.slug,
                      attendantId: value,
                      clearAttendant: value == null || value.isEmpty,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: controller.loading
                      ? null
                      : () {
                          _searchController.clear();
                          controller.applyFilters(
                            user: auth.user,
                            slug: widget.slug,
                            clearSearch: true,
                            clearStatus: true,
                            clearChannel: true,
                            clearAttendant: true,
                          );
                        },
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: const Text('Limpar'),
                ),
                FilledButton.icon(
                  onPressed: controller.loading
                      ? null
                      : () => controller.refresh(
                          user: auth.user, slug: widget.slug),
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('Aplicar Filtros'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickFilterChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _charts(ReportsController controller) {
    final metrics = controller.metrics;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final charts = [
          _ChartCard(
            title: 'Atendimentos ao Longo do Tempo',
            child: _CallsByDayChart(data: metrics.callsByDay),
          ),
          _ChartCard(
            title: 'Distribuição por Status',
            child: _StatusDonutChart(distribution: metrics.statusDistribution),
          ),
          _ChartCard(
            title: 'Distribuição de Tempos de Atendimento (TMA)',
            child: _TmaBarsChart(metrics: metrics),
          ),
          _ChartCard(
            title: 'Tempo Médio de Espera (TME)',
            child: _GaugeChart(
              valueSeconds: metrics.tmeAvgSeconds,
              label: metrics.tmeAvg,
            ),
          ),
        ];

        return GridView.count(
          crossAxisCount: narrow ? 1 : 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: narrow ? 1.8 : 2.05,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: charts,
        );
      },
    );
  }

  Widget _rankingChart(ReportsController controller) {
    return _ChartCard(
      title: 'Ranking de Intérpretes - Tempo de Ocupação (TMO)',
      height: 300,
      child: _InterpreterRankingChart(
        interpreters: controller.metrics.interpretersPerformance,
      ),
    );
  }

  Widget _interpretersTable(ReportsController controller) {
    final interpreters = controller.metrics.interpretersPerformance;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detalhamento por Intérprete',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (interpreters.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Nenhum intérprete encontrado.')),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Intérprete')),
                    DataColumn(label: Text('Chamadas Atendidas')),
                    DataColumn(label: Text('TMA Médio')),
                    DataColumn(label: Text('Tempo Total (TMO)')),
                  ],
                  rows: interpreters
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text(item.name)),
                            DataCell(Text(item.totalCalls.toString())),
                            DataCell(Text(item.avgTMA)),
                            DataCell(Text('${item.totalHours}h')),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resultsSection(ReportsController controller, AuthController auth) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Resultados Detalhados (${controller.total})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar',
                      hintText: 'Protocolo, empresa ou pessoa',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _applySearch(controller, auth),
                  ),
                ),
                FilledButton.icon(
                  onPressed: controller.exporting
                      ? null
                      : () => _exportPdf(context, controller, auth),
                  icon: controller.exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Exportar Todos'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _table(controller, auth),
            const SizedBox(height: 12),
            _paginationHeader(controller, auth),
          ],
        ),
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback? onClear,
  }) {
    return SizedBox(
      width: 170,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date == null ? label : _dateFormat.format(date),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              InkWell(
                onTap: onClear,
                child: const Icon(Icons.close, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _paginationHeader(ReportsController controller, AuthController auth) {
    return Row(
      children: [
        Text(
          '${controller.total} registro(s)',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        Text(
          'Página ${controller.page} de ${controller.totalPages}',
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(width: 16),
        IconButton(
          tooltip: 'Página anterior',
          onPressed: controller.canGoPrevious
              ? () =>
                  controller.previousPage(user: auth.user, slug: widget.slug)
              : null,
          icon: const Icon(Icons.chevron_left),
          color: controller.canGoPrevious ? AppTheme.primary : Colors.grey,
        ),
        IconButton(
          tooltip: 'Próxima página',
          onPressed: controller.canGoNext
              ? () => controller.nextPage(user: auth.user, slug: widget.slug)
              : null,
          icon: const Icon(Icons.chevron_right),
          color: controller.canGoNext ? AppTheme.primary : Colors.grey,
        ),
      ],
    );
  }

  Widget _table(ReportsController controller, AuthController auth) {
    return Card(
      margin: EdgeInsets.zero,
      child: Stack(
        children: [
          if (controller.calls.isEmpty && controller.loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: TableShimmer(rows: 8, columns: 8),
            )
          else if (controller.calls.isEmpty)
            const Center(child: Text('Nenhum registro encontrado.'))
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: SingleChildScrollView(
                      child: DataTable(
                        sortColumnIndex: _sortColumnIndex(controller),
                        sortAscending: controller.filters.sortOrder == 'asc',
                        columns: [
                          _column(
                            label: 'Protocolo',
                            sortBy: 'protocol',
                            controller: controller,
                            auth: auth,
                          ),
                          _column(
                            label: 'Data/Hora',
                            sortBy: 'createdAt',
                            controller: controller,
                            auth: auth,
                          ),
                          const DataColumn(label: Text('Empresa')),
                          const DataColumn(label: Text('Canal')),
                          _column(
                            label: 'Status',
                            sortBy: 'status',
                            controller: controller,
                            auth: auth,
                          ),
                          const DataColumn(label: Text('TME')),
                          const DataColumn(label: Text('TMA')),
                          const DataColumn(label: Text('TMO')),
                        ],
                        rows: controller.calls.map(_row).toList(),
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
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: TableShimmer(rows: 8, columns: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  DataColumn _column({
    required String label,
    required String sortBy,
    required ReportsController controller,
    required AuthController auth,
  }) {
    return DataColumn(
      label: Text(label),
      onSort: (_, __) => controller.sort(
        user: auth.user,
        slug: widget.slug,
        sortBy: sortBy,
      ),
    );
  }

  List<DropdownMenuItem<String>> _optionItems(List<ReportOption> options) {
    return options
        .map(
          (option) => DropdownMenuItem<String>(
            value: option.id,
            child: Text(
              option.name.isEmpty ? option.id : option.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
  }

  DataRow _row(ReportCall call) {
    return DataRow(
      cells: [
        DataCell(Text(call.protocol.isEmpty ? '-' : call.protocol)),
        DataCell(Text(_formatDateTime(call.startTime))),
        DataCell(Text(call.company.isEmpty ? '-' : call.company)),
        DataCell(Text(call.channel.isEmpty ? '-' : call.channel)),
        DataCell(_statusBadge(call.status)),
        DataCell(Text(call.tme ?? '-')),
        DataCell(Text(call.tma ?? '-')),
        DataCell(Text(call.tmo ?? '-')),
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

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );

    if (selected != null) onSelected(selected);
  }

  void _applySearch(ReportsController controller, AuthController auth) {
    controller.applyFilters(
      user: auth.user,
      slug: widget.slug,
      search: _searchController.text,
      clearSearch: _searchController.text.trim().isEmpty,
    );
  }

  void _applyQuickPeriod(
    ReportsController controller,
    AuthController auth, {
    required int days,
  }) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final start = DateTime(now.year, now.month, now.day - (days - 1));

    controller.applyFilters(
      user: auth.user,
      slug: widget.slug,
      startDate: start,
      endDate: end,
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    ReportsController controller,
    AuthController auth,
  ) async {
    try {
      final calls = await controller.exportCalls(
        user: auth.user,
        slug: widget.slug,
      );

      if (!context.mounted) return;

      if (calls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum registro para exportar.')),
        );
        return;
      }

      await ReportPdfService.shareReport(
        calls: calls,
        metrics: controller.metrics,
        filters: controller.filters,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.error ?? 'Não foi possível gerar o PDF.'),
        ),
      );
    }
  }

  int? _sortColumnIndex(ReportsController controller) {
    return switch (controller.filters.sortBy) {
      'protocol' => 0,
      'createdAt' => 1,
      'status' => 4,
      _ => null,
    };
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return '-';
    return _dateTimeFormat.format(date.toLocal());
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

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primary, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double height;

  const _ChartCard({
    required this.title,
    required this.child,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(height: height - 58, child: child),
          ],
        ),
      ),
    );
  }
}

class _CallsByDayChart extends StatelessWidget {
  final List<CallsByDayMetric> data;

  const _CallsByDayChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('Sem dados no período.'));

    return CustomPaint(
      painter: _CallsByDayPainter(data),
      child: const SizedBox.expand(),
    );
  }
}

class _StatusDonutChart extends StatelessWidget {
  final Map<String, int> distribution;

  const _StatusDonutChart({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold<int>(0, (sum, item) => sum + item);
    if (total == 0) return const Center(child: Text('Sem dados no período.'));

    return CustomPaint(
      painter: _StatusDonutPainter(distribution),
      child: const SizedBox.expand(),
    );
  }
}

class _TmaBarsChart extends StatelessWidget {
  final ReportMetrics metrics;

  const _TmaBarsChart({required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.tmaMaxSeconds == 0) {
      return const Center(child: Text('Sem dados no período.'));
    }

    return CustomPaint(
      painter: _TmaBarsPainter(metrics),
      child: const SizedBox.expand(),
    );
  }
}

class _GaugeChart extends StatelessWidget {
  final int valueSeconds;
  final String label;

  const _GaugeChart({
    required this.valueSeconds,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GaugePainter(valueSeconds, label),
      child: const SizedBox.expand(),
    );
  }
}

class _InterpreterRankingChart extends StatelessWidget {
  final List<InterpreterPerformanceMetric> interpreters;

  const _InterpreterRankingChart({required this.interpreters});

  @override
  Widget build(BuildContext context) {
    if (interpreters.isEmpty) {
      return const Center(child: Text('Sem intérpretes no período.'));
    }

    return CustomPaint(
      painter: _InterpreterRankingPainter(interpreters.take(6).toList()),
      child: const SizedBox.expand(),
    );
  }
}

class _CallsByDayPainter extends CustomPainter {
  final List<CallsByDayMetric> data;

  _CallsByDayPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final area = Rect.fromLTWH(42, 12, size.width - 56, size.height - 46);
    final axis = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    final attendedPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final notAttendedPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (var i = 0; i <= 4; i++) {
      final y = area.top + area.height * i / 4;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), axis);
    }

    final maxValue = data
        .map((item) => math.max(item.attended, item.notAttended))
        .fold<int>(1, math.max);

    Path pathFor(int Function(CallsByDayMetric item) value) {
      final path = Path();
      for (var i = 0; i < data.length; i++) {
        final x = data.length == 1
            ? area.center.dx
            : area.left + area.width * i / (data.length - 1);
        final y = area.bottom - (value(data[i]) / maxValue) * area.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }

    canvas.drawPath(pathFor((item) => item.attended), attendedPaint);
    canvas.drawPath(pathFor((item) => item.notAttended), notAttendedPaint);

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    for (var i = 0; i < data.length; i++) {
      final x = data.length == 1
          ? area.center.dx
          : area.left + area.width * i / (data.length - 1);
      textPainter.text = TextSpan(
        text: data[i].date,
        style: const TextStyle(fontSize: 10, color: Colors.black54),
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(x - textPainter.width / 2, area.bottom + 8));
    }

    _drawLegend(canvas, Offset(area.left, size.height - 18), [
      ('Atendidos', const Color(0xFF10B981)),
      ('Não Atendidos', const Color(0xFFEF4444)),
    ]);
  }

  @override
  bool shouldRepaint(covariant _CallsByDayPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

class _StatusDonutPainter extends CustomPainter {
  final Map<String, int> distribution;

  _StatusDonutPainter(this.distribution);

  @override
  void paint(Canvas canvas, Size size) {
    final colors = {
      'FINISHED': const Color(0xFF10B981),
      'IN_PROGRESS': const Color(0xFF3B82F6),
      'CANCELED': const Color(0xFFEF4444),
      'WAITING_FOR_RESPONSE': const Color(0xFFF59E0B),
    };
    final labels = {
      'FINISHED': 'Finalizados',
      'IN_PROGRESS': 'Em Andamento',
      'CANCELED': 'Cancelados',
      'WAITING_FOR_RESPONSE': 'Aguardando',
    };
    final total = distribution.values.fold<int>(0, (sum, item) => sum + item);
    final center = Offset(size.width / 2, size.height / 2 - 10);
    final radius = math.min(size.width, size.height) * 0.28;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.42
      ..strokeCap = StrokeCap.butt;
    var start = -math.pi / 2;

    for (final entry in colors.entries) {
      final value = distribution[entry.key] ?? 0;
      if (value == 0) continue;
      final sweep = (value / total) * math.pi * 2;
      paint.color = entry.value;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }

    final legendItems = colors.entries
        .map((entry) => (labels[entry.key]!, entry.value))
        .toList();
    _drawLegend(canvas, Offset(16, size.height - 22), legendItems);
  }

  @override
  bool shouldRepaint(covariant _StatusDonutPainter oldDelegate) {
    return oldDelegate.distribution != distribution;
  }
}

class _TmaBarsPainter extends CustomPainter {
  final ReportMetrics metrics;

  _TmaBarsPainter(this.metrics);

  @override
  void paint(Canvas canvas, Size size) {
    final labels = ['Mínimo', 'Médio', 'Máximo'];
    final values = [
      metrics.tmaMinSeconds,
      metrics.tmaAvgSeconds,
      metrics.tmaMaxSeconds,
    ];
    final captions = [metrics.tmaMin, metrics.tmaAvg, metrics.tmaMax];
    final colors = [
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
    ];
    final maxValue = values.fold<int>(1, math.max);
    final chart = Rect.fromLTWH(36, 14, size.width - 56, size.height - 48);
    final barWidth = chart.width / 6;
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    for (var i = 0; i < values.length; i++) {
      final x = chart.left + chart.width * (i + 0.5) / values.length;
      final height = chart.height * values[i] / maxValue;
      final rect = Rect.fromLTWH(
          x - barWidth / 2, chart.bottom - height, barWidth, height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = colors[i],
      );
      textPainter.text = TextSpan(
        text: captions[i],
        style: const TextStyle(fontSize: 10, color: Colors.black54),
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(x - textPainter.width / 2, rect.top - 16));
      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(fontSize: 10, color: Colors.black54),
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(x - textPainter.width / 2, chart.bottom + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _TmaBarsPainter oldDelegate) {
    return oldDelegate.metrics != metrics;
  }
}

class _GaugePainter extends CustomPainter {
  final int valueSeconds;
  final String label;

  _GaugePainter(this.valueSeconds, this.label);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.72);
    final radius = math.min(size.width, size.height) * 0.42;
    final stroke = radius * 0.16;
    final segments = [
      (const Color(0xFF10B981), math.pi * 0.35),
      (const Color(0xFFF59E0B), math.pi * 0.45),
      (const Color(0xFFEF4444), math.pi * 0.70),
    ];
    var start = math.pi;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    for (final segment in segments) {
      paint.color = segment.$1;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        segment.$2,
        false,
        paint,
      );
      start += segment.$2;
    }

    final maxSeconds = 15 * 60;
    final ratio = (valueSeconds / maxSeconds).clamp(0.0, 1.0);
    final angle = math.pi + ratio * math.pi;
    final needleEnd = Offset(
      center.dx + math.cos(angle) * radius * 0.78,
      center.dy + math.sin(angle) * radius * 0.78,
    );
    canvas.drawLine(
      center,
      needleEnd,
      Paint()
        ..color = Colors.black87
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr)
      ..text = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      )
      ..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy + 10),
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.valueSeconds != valueSeconds ||
        oldDelegate.label != label;
  }
}

class _InterpreterRankingPainter extends CustomPainter {
  final List<InterpreterPerformanceMetric> interpreters;

  _InterpreterRankingPainter(this.interpreters);

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(140, 16, size.width - 170, size.height - 40);
    final maxValue =
        interpreters.map((item) => item.totalHours).fold<double>(0.1, math.max);
    final rowHeight = chart.height / interpreters.length;
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    for (var i = 0; i < interpreters.length; i++) {
      final item = interpreters[i];
      final y = chart.top + i * rowHeight + rowHeight * 0.22;
      final width = chart.width * (item.totalHours / maxValue);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(chart.left, y, width, rowHeight * 0.46),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFF59E0B),
      );

      textPainter.text = TextSpan(
        text: item.name,
        style: const TextStyle(fontSize: 11, color: Colors.black54),
      );
      textPainter.layout(maxWidth: 125);
      textPainter.paint(canvas, Offset(8, y));

      textPainter.text = TextSpan(
        text: '${item.totalHours}h',
        style: const TextStyle(fontSize: 10, color: Colors.black54),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(chart.left + width + 6, y));
    }
  }

  @override
  bool shouldRepaint(covariant _InterpreterRankingPainter oldDelegate) {
    return oldDelegate.interpreters != interpreters;
  }
}

void _drawLegend(
  Canvas canvas,
  Offset origin,
  List<(String, Color)> items,
) {
  final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
  var dx = origin.dx;

  for (final item in items) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(dx, origin.dy + 4, 10, 10),
        const Radius.circular(2),
      ),
      Paint()..color = item.$2,
    );
    dx += 14;
    textPainter.text = TextSpan(
      text: item.$1,
      style: const TextStyle(fontSize: 10, color: Colors.black54),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(dx, origin.dy));
    dx += textPainter.width + 16;
  }
}
