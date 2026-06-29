import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/call_controller.dart';
import '../core/config/app_theme.dart';
import '../widgets/app_shell.dart';

class CallReviewScreen extends StatefulWidget {
  final String slug;
  final String callId;
  final String protocol;

  const CallReviewScreen({
    super.key,
    required this.slug,
    required this.callId,
    required this.protocol,
  });

  @override
  State<CallReviewScreen> createState() => _CallReviewScreenState();
}

class _CallReviewScreenState extends State<CallReviewScreen> {
  final _descriptionController = TextEditingController();
  int _rating = 0;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CallController>();
    final protocol =
        widget.protocol.isNotEmpty ? widget.protocol : widget.callId;

    return AppShell(
      title: 'Avaliação',
      slug: widget.slug,
      currentRoute: 'call-review',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _formPanel(controller, protocol),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formPanel(CallController controller, String protocol) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'O atendimento foi encerrado.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.cancel,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Agradecemos por utilizar nossos serviços.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
        Divider(color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(
          'Protocolo: $protocol',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'O que você achou do nosso atendimento?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _stars(),
        const SizedBox(height: 18),
        TextField(
          controller: _descriptionController,
          minLines: 4,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Comentário',
            hintText: 'Gostei do atendimento por...',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: controller.reviewing ? null : _skip,
                child: const Text('Pular'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: controller.reviewing || _rating == 0
                    ? null
                    : () => _submit(controller),
                icon: controller.reviewing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: const Text('Enviar'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final value = index + 1;
        return IconButton(
          tooltip: '$value estrela${value == 1 ? '' : 's'}',
          onPressed: () => setState(() => _rating = value),
          iconSize: 40,
          color: AppTheme.cancel,
          icon: Icon(value <= _rating ? Icons.star : Icons.star_border),
        );
      }),
    );
  }

  Future<void> _submit(CallController controller) async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Selecione uma avaliação de 1 a 5 estrelas.'),
          ),
        );
      return;
    }

    final auth = context.read<AuthController>();

    try {
      await controller.submitReview(
        callId: widget.callId,
        rating: _rating,
        description: _descriptionController.text.trim(),
        userId: auth.user?.id,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Avaliação enviada com sucesso.')),
        );
      _goToQueue();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text(controller.error ?? 'Erro ao enviar avaliação.'),
          ),
        );
    }
  }

  void _skip() {
    _goToQueue();
  }

  void _goToQueue() {
    context.go('/queue/${widget.slug}');
  }
}
