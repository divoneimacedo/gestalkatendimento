import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/companies_controller.dart';
import '../core/config/app_config.dart';
import '../core/config/app_theme.dart';
import '../core/exceptions/api_exception.dart';
import '../models/company.dart';
import '../widgets/app_shell.dart';
import '../widgets/shimmer_loading.dart';

class CompanyFormScreen extends StatefulWidget {
  final String slug;
  final String? companyId;

  const CompanyFormScreen({
    super.key,
    required this.slug,
    this.companyId,
  });

  @override
  State<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends State<CompanyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _slugController = TextEditingController();
  final _termsController = TextEditingController();
  final _primaryColorController = TextEditingController(text: '#000000');
  final _secondaryColorController = TextEditingController(text: '#000000');
  final _buttonColorController = TextEditingController(text: '#000000');

  List<CompanyPlanOption> _plans = [];
  String? _planId;
  String? _logoPath;
  String? _backgroundPath;
  String _logoUrl = '';
  String _backgroundUrl = '';
  bool _isInative = false;
  bool _requireUserLogin = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Company? _company;

  bool get _isEditing =>
      widget.companyId != null && widget.companyId!.isNotEmpty;
  String get _loginUrl => _slugController.text.trim().isEmpty
      ? ''
      : '${AppConfig.frontendUrl}/${_slugController.text.trim()}/signin';

  @override
  void initState() {
    super.initState();
    _slugController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _slugController.dispose();
    _termsController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _buttonColorController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = context.read<CompaniesController>().companiesService;
      final results = await Future.wait<dynamic>([
        service.fetchPlans(),
        if (_isEditing) service.fetchCompany(widget.companyId!),
      ]);

      _plans = results.first as List<CompanyPlanOption>;

      if (_isEditing) {
        _company = results[1] as Company;
        final company = _company!;
        _nameController.text = company.name;
        _titleController.text = company.title;
        _subtitleController.text = company.subtitle;
        _slugController.text = company.slug;
        _termsController.text = company.terms;
        _primaryColorController.text = _color(company.primaryColor, '#000000');
        _secondaryColorController.text =
            _color(company.secondaryColor, '#FFFFFF');
        _buttonColorController.text = _color(company.buttonColor, '#000000');
        _planId = company.planId.isEmpty ? null : company.planId;
        _logoUrl = company.logo;
        _backgroundUrl = company.backgroundAttImage;
        _isInative = company.isInative;
        _requireUserLogin = company.requireUserLogin;
      }
    } on ApiException catch (exception) {
      _error = exception.message;
    } catch (_) {
      _error = 'Erro ao carregar dados da empresa.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Empresas',
      slug: widget.slug,
      currentRoute: 'companies',
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
                    _isEditing ? 'Editar empresa' : 'Criar nova empresa',
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
                      child: TableShimmer(rows: 8, columns: 2),
                    )
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: AppTheme.danger),
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
                                      _nameField(),
                                      _statusField(),
                                      _planField(),
                                      _fileField(
                                        label: 'Logo',
                                        path: _logoPath,
                                        currentUrl: _logoUrl,
                                        onPick: () => _pickImage(isLogo: true),
                                      ),
                                      _fileField(
                                        label: 'Imagem de Fundo',
                                        path: _backgroundPath,
                                        currentUrl: _backgroundUrl,
                                        onPick: () => _pickImage(isLogo: false),
                                      ),
                                      _colorField(
                                        'Cor Primária',
                                        _primaryColorController,
                                      ),
                                      _colorField(
                                        'Cor Secundária',
                                        _secondaryColorController,
                                      ),
                                      _colorField(
                                        'Cor dos botões',
                                        _buttonColorController,
                                      ),
                                      _textField(
                                        'Título',
                                        _titleController,
                                        required: true,
                                      ),
                                      _textField(
                                        'Sub Título',
                                        _subtitleController,
                                        required: true,
                                      ),
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
                                        for (var i = 0;
                                            i < fields.length;
                                            i += 2)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 18,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(child: fields[i]),
                                                const SizedBox(width: 18),
                                                Expanded(
                                                  child: i + 1 < fields.length
                                                      ? fields[i + 1]
                                                      : const SizedBox(),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                _slugField(),
                                if (_loginUrl.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  _loginUrlField(),
                                ],
                                const SizedBox(height: 18),
                                _requireLoginCard(),
                                const SizedBox(height: 28),
                                _termsField(),
                                const SizedBox(height: 28),
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

  Widget _nameField() {
    return _textField('Nome', _nameController, required: true);
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
        DropdownMenuItem(value: true, child: Text('Inativa')),
      ],
      onChanged: (value) => setState(() => _isInative = value ?? false),
    );
  }

  Widget _planField() {
    return DropdownButtonFormField<String>(
      initialValue: _planId,
      decoration: const InputDecoration(
        labelText: 'Plano',
        filled: true,
        fillColor: Color(0xFFF1F2F6),
      ),
      items: [
        for (final plan in _plans)
          DropdownMenuItem(value: plan.id, child: Text(plan.name)),
      ],
      validator: (value) =>
          value == null || value.isEmpty ? 'Selecione um plano.' : null,
      onChanged: (value) => setState(() => _planId = value),
    );
  }

  Widget _fileField({
    required String label,
    required String? path,
    required String currentUrl,
    required VoidCallback onPick,
  }) {
    final selectedName = path == null ? '' : path.split('/').last;
    final resolvedCurrentUrl = _resolveImageUrl(currentUrl);
    final hasCurrentImage = resolvedCurrentUrl.isNotEmpty;
    final helperText = selectedName.isNotEmpty
        ? selectedName
        : hasCurrentImage
            ? 'Imagem atual cadastrada'
            : 'Nenhum arquivo selecionado.';

    Widget preview;
    if (path != null && path.isNotEmpty) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(path),
          width: 80,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _imageUnavailable(),
        ),
      );
    } else if (hasCurrentImage) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          resolvedCurrentUrl,
          width: 80,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _imageUnavailable(),
        ),
      );
    } else {
      preview = _imageUnavailable();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            preview,
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: onPick,
              child: const Text('Procurar...'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                helperText,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _imageUnavailable() {
    return Container(
      width: 80,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black12),
      ),
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 18,
        color: Colors.black45,
      ),
    );
  }

  Widget _colorField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _parseColor(controller.text),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black12),
            ),
          ),
        ),
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (value == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
          return 'Informe uma cor em hexadecimal. Ex: #209EA1';
        }
        return null;
      },
    );
  }

  Widget _slugField() {
    return TextFormField(
      controller: _slugController,
      decoration: const InputDecoration(
        labelText: 'Slug',
        helperText:
            'Slug deve conter apenas letras minúsculas, números e hífens.',
      ),
      onChanged: (value) {
        final normalized = _normalizeSlug(value);
        if (normalized != value) {
          _slugController.value = TextEditingValue(
            text: normalized,
            selection: TextSelection.collapsed(offset: normalized.length),
          );
        }
      },
      validator: (value) {
        final text = value?.trim() ?? '';
        if (!_isEditing && text.isEmpty) return 'Informe o slug.';
        if (text.isNotEmpty && !RegExp(r'^[a-z0-9-]+$').hasMatch(text)) {
          return 'Use apenas letras minúsculas, números e hífens.';
        }
        return null;
      },
    );
  }

  Widget _loginUrlField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('URL de Login'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(4),
                  ),
                ),
                child: Text(
                  _loginUrl,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _loginUrl));
                  _showSnack('URL copiada.');
                },
                style: FilledButton.styleFrom(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(4),
                    ),
                  ),
                ),
                child: const Text('Copiar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Link de acesso direto para a página de login da empresa.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _requireLoginCard() {
    return Material(
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: CheckboxListTile(
        value: _requireUserLogin,
        onChanged: (value) =>
            setState(() => _requireUserLogin = value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        title: const Text(
          'Forçar Login de usuários',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          'Quando ativado, surdos deverão fazer cadastro e login antes de iniciar um atendimento.',
        ),
      ),
    );
  }

  Widget _termsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Termos de Uso',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Configure os termos de uso que os usuários devem aceitar ao realizar o cadastro.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _termsController,
          minLines: 12,
          maxLines: 18,
          decoration: const InputDecoration(
            alignLabelWithHint: true,
            labelText: 'Digite os termos de uso da empresa aqui...',
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage({required bool isLogo}) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Imagens',
          extensions: ['png', 'jpg', 'jpeg', 'webp'],
        ),
      ],
    );

    if (file == null) return;

    setState(() {
      if (isLogo) {
        _logoPath = file.path;
      } else {
        _backgroundPath = file.path;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final service = context.read<CompaniesController>().companiesService;
      final logoUrl =
          _logoPath == null ? _logoUrl : await service.uploadImage(_logoPath!);
      final backgroundUrl = _backgroundPath == null
          ? _backgroundUrl
          : await service.uploadImage(_backgroundPath!);
      final terms = _termsController.text.trim();
      final slug = _slugController.text.trim();

      await service.saveCompany(
        companyId: widget.companyId,
        payload: {
          'name': _nameController.text.trim(),
          'planId': _planId,
          'planConsumption': _company?.planConsumption ?? 0,
          'plansTotal': _company?.plansTotal ?? 0,
          'isInative': _isInative,
          'logo': logoUrl.isEmpty ? null : logoUrl,
          'backgroundAttImage': backgroundUrl.isEmpty ? null : backgroundUrl,
          'primaryColor': _primaryColorController.text.trim(),
          'secondaryColor': _secondaryColorController.text.trim(),
          'buttonColor': _buttonColorController.text.trim(),
          'title': _titleController.text.trim(),
          'subtitle': _subtitleController.text.trim(),
          'slug': slug.isEmpty ? null : slug,
          'requireUserLogin': _requireUserLogin,
          'terms': terms.isEmpty ? null : terms,
          'termsVersion': _company?.termsVersion ?? (terms.isEmpty ? 0 : 1),
        },
        customizationPayload: {
          'primaryColor': _primaryColorController.text.trim(),
          'secondaryColor': _secondaryColorController.text.trim(),
          'buttonColor': _buttonColorController.text.trim(),
          'title': _titleController.text.trim(),
          'subtitle': _subtitleController.text.trim(),
          if (slug.isNotEmpty) 'slug': slug,
          if (logoUrl.isNotEmpty) 'logo': logoUrl,
        },
      );

      if (!mounted) return;
      _showSnack(_isEditing ? 'Empresa atualizada.' : 'Empresa criada.');
      _goBack();
    } on ApiException catch (exception) {
      _showSnack(exception.message, isError: true);
    } catch (_) {
      _showSnack('Erro ao salvar empresa.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goBack() {
    context.go('/companies/${widget.slug}');
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

String _normalizeSlug(String value) {
  return value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'[^a-z0-9-]'), '');
}

String _color(String value, String fallback) {
  return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value) ? value : fallback;
}

Color _parseColor(String value) {
  final hex = _color(value, '#000000').replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

String _resolveImageUrl(String rawUrl) {
  final value = rawUrl.trim();
  if (value.isEmpty) return '';

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  if (value.startsWith('//')) {
    return 'https:$value';
  }

  final base = AppConfig.apiUrl.replaceFirst(RegExp(r'/+$'), '');
  final path = value.startsWith('/') ? value : '/$value';
  return '$base$path';
}
