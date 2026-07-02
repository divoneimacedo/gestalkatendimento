import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/channels_controller.dart';
import '../core/config/app_theme.dart';
import '../core/exceptions/api_exception.dart';
import '../models/channel.dart';
import '../services/channels_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/shimmer_loading.dart';

class ChannelFormScreen extends StatefulWidget {
  final String slug;
  final String? channelId;

  const ChannelFormScreen({
    super.key,
    required this.slug,
    this.channelId,
  });

  @override
  State<ChannelFormScreen> createState() => _ChannelFormScreenState();
}

class _ChannelFormScreenState extends State<ChannelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  List<ChannelCompanyOption> _companies = [];
  String? _companyId;
  bool _isInative = false;
  bool _isPrivated = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _isEditing =>
      widget.channelId != null && widget.channelId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = context.read<ChannelsController>().channelsService;
      final results = await Future.wait<dynamic>([
        service.fetchCompanies(widget.slug),
        if (_isEditing) service.fetchChannel(widget.channelId!),
      ]);

      _companies = results.first as List<ChannelCompanyOption>;

      if (_isEditing) {
        final channel = results[1] as Channel;
        _nameController.text = channel.name;
        _companyId = channel.companyId;
        _isInative = channel.isInative;
        _isPrivated = channel.isPrivated;

        if (_companies.every((company) => company.id != channel.companyId)) {
          _companies = [
            ChannelCompanyOption(
              id: channel.companyId,
              name: channel.companyName.isEmpty
                  ? 'Empresa atual'
                  : channel.companyName,
            ),
            ..._companies,
          ];
        }
      } else if (_companies.length == 1) {
        _companyId = _companies.first.id;
      }
    } on ApiException catch (exception) {
      _error = exception.message;
    } catch (_) {
      _error = 'Erro ao carregar dados do canal.';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Canais',
      slug: widget.slug,
      currentRoute: 'channels',
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
                    _isEditing ? 'Editar canal' : 'Criar novo canal',
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
                                      _companyField(),
                                      _nameField(),
                                      _statusField(),
                                      _privacyField(),
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

  Widget _companyField() {
    return DropdownButtonFormField<String>(
      initialValue: _companyId,
      decoration: const InputDecoration(
        labelText: 'Empresa',
        filled: true,
        fillColor: Color(0xFFF1F2F6),
      ),
      items: [
        if (_companies.isEmpty)
          const DropdownMenuItem(
            value: '',
            child: Text('Não Selecionada'),
          ),
        for (final company in _companies)
          DropdownMenuItem(
            value: company.id,
            child: Text(company.name),
          ),
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Selecione uma empresa.';
        }
        return null;
      },
      onChanged: (value) => setState(() => _companyId = value),
    );
  }

  Widget _nameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Nome',
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Informe o nome do canal.';
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
        DropdownMenuItem(value: false, child: Text('Ativa')),
        DropdownMenuItem(value: true, child: Text('Desativada')),
      ],
      onChanged: (value) => setState(() => _isInative = value ?? false),
    );
  }

  Widget _privacyField() {
    return DropdownButtonFormField<bool>(
      initialValue: _isPrivated,
      decoration: const InputDecoration(
        labelText: 'É privado?',
        filled: true,
        fillColor: Color(0xFFF1F2F6),
      ),
      items: const [
        DropdownMenuItem(value: false, child: Text('Não')),
        DropdownMenuItem(value: true, child: Text('Sim')),
      ],
      onChanged: (value) => setState(() => _isPrivated = value ?? false),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await context.read<ChannelsController>().saveChannel(
            channelId: widget.channelId,
            name: _nameController.text.trim(),
            companyId: _companyId ?? '',
            isPrivated: _isPrivated,
            isInative: _isInative,
          );

      if (!mounted) return;
      _showSnack(_isEditing ? 'Canal atualizado.' : 'Canal criado.');
      _goBack();
    } on ApiException catch (exception) {
      _showSnack(exception.message, isError: true);
    } catch (_) {
      _showSnack('Erro ao salvar canal.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goBack() {
    context.go('/channels/${widget.slug}');
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
