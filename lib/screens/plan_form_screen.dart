import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/plans_controller.dart';
import '../core/config/app_theme.dart';
import '../core/exceptions/api_exception.dart';
import '../models/plan.dart';
import '../widgets/app_shell.dart';
import '../widgets/shimmer_loading.dart';

class PlanFormScreen extends StatefulWidget {
  final String slug;
  final String? planId;

  const PlanFormScreen({
    super.key,
    required this.slug,
    this.planId,
  });

  @override
  State<PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends State<PlanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _durationController = TextEditingController();

  bool _isInative = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Plan? _plan;

  bool get _isEditing => widget.planId != null && widget.planId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_isEditing) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = context.read<PlansController>().plansService;
      _plan = await service.fetchPlan(widget.planId!);
      final plan = _plan!;

      _nameController.text = plan.name;
      _valueController.text = _formatValue(plan.value);
      _durationController.text = plan.duration.toString();
      _isInative = plan.isInative;
    } on ApiException catch (exception) {
      _error = exception.message;
    } catch (_) {
      _error = 'Erro ao carregar dados do plano.';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Planos',
      slug: widget.slug,
      currentRoute: 'plans',
      actions: [
        IconButton(
          tooltip: 'Voltar',
          onPressed: _saving ? null : _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ],
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFFF5F7F8),
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              child: Row(
                children: [
                  Text(
                    _isEditing ? 'Editar plano' : 'Criar novo plano',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _goBack,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F5592),
                    ),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: TableShimmer(rows: 4, columns: 2),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: AppTheme.danger),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(22),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final twoColumns =
                                        constraints.maxWidth >= 780;
                                    final fields = [
                                      _textField(
                                        'Nome do plano',
                                        _nameController,
                                        required: true,
                                      ),
                                      _numberField(
                                        'Valor',
                                        _valueController,
                                        required: true,
                                      ),
                                      _numberField(
                                        'Duração',
                                        _durationController,
                                        required: true,
                                      ),
                                      _statusField(),
                                    ];

                                    if (!twoColumns) {
                                      return Column(
                                        children: [
                                          for (final field in fields) ...[
                                            field,
                                            const SizedBox(height: 18),
                                          ],
                                        ],
                                      );
                                    }

                                    return Column(
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: fields[0]),
                                            const SizedBox(width: 18),
                                            Expanded(child: fields[1]),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: fields[2]),
                                            const SizedBox(width: 18),
                                            Expanded(child: fields[3]),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 34),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton(
                                    onPressed: _saving ? null : _save,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.success,
                                    ),
                                    child: _saving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Salvar'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) =>
              value == null || value.trim().isEmpty ? 'Informe $label.' : null
          : null,
    );
  }

  Widget _numberField(
    String label,
    TextEditingController controller, {
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (required && text.isEmpty) {
          return 'Informe $label.';
        }

        if (text.isNotEmpty &&
            num.tryParse(text.replaceAll(',', '.')) == null) {
          return '$label inválido.';
        }

        return null;
      },
    );
  }

  Widget _statusField() {
    return DropdownButtonFormField<bool>(
      initialValue: _isInative,
      decoration: const InputDecoration(
        labelText: 'Status',
        filled: true,
        fillColor: Color(0xFFF1F2F6),
      ),
      items: const [
        DropdownMenuItem(value: false, child: Text('Ativo')),
        DropdownMenuItem(value: true, child: Text('Inativo')),
      ],
      onChanged: (value) => setState(() => _isInative = value ?? false),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final parsedValue =
        num.tryParse(_valueController.text.trim().replaceAll(',', '.'));
    final parsedDuration = int.tryParse(_durationController.text.trim());

    if (parsedValue == null || parsedDuration == null) {
      _showSnack('Informe valor e duração válidos.', isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final service = context.read<PlansController>().plansService;
      final payload = {
        'name': _nameController.text.trim(),
        'value': parsedValue,
        'duration': parsedDuration,
        'isInative': _isInative,
      };

      if (_isEditing) {
        await service.updatePlan(
          planId: widget.planId!,
          name: payload['name'] as String,
          value: payload['value'] as num,
          duration: payload['duration'] as int,
          isInative: payload['isInative'] as bool,
        );
      } else {
        await service.createPlan(
          name: payload['name'] as String,
          value: payload['value'] as num,
          duration: payload['duration'] as int,
          isInative: payload['isInative'] as bool,
        );
      }

      if (!mounted) return;
      _showSnack(_isEditing ? 'Plano atualizado.' : 'Plano criado.');
      _goBack();
    } on ApiException catch (exception) {
      _showSnack(exception.message, isError: true);
    } catch (_) {
      _showSnack('Erro ao salvar plano.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goBack() {
    context.go('/plans/${widget.slug}');
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? AppTheme.danger : null,
        ),
      );
  }
}

String _formatValue(num value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toStringAsFixed(2);
}
