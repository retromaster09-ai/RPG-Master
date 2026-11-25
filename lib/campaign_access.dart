import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'campaigns.dart';

String _campaignError(Object error) {
  if (error is CampaignJoinException) {
    return error.status == 'limited'
        ? 'Muitas tentativas. Tente de novo em 15 minutos.'
        : 'Confira se o código está correto e continua ativo.';
  }
  if (error is PostgrestException) {
    return switch (error.code) {
      '22023' => 'Confira os dados. O convite pode ter expirado.',
      '42501' => 'Somente o mestre pode fazer essa alteração.',
      '23505' => 'Esse valor já está em uso. Atualize a lista e tente outro.',
      _ => 'Não foi possível concluir. Tente novamente.',
    };
  }
  return 'Não foi possível concluir. Tente novamente.';
}

Future<String?> askCampaignText(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  required String? Function(String) validate,
  required Future<void> Function(String) submit,
  String? help,
}) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (context) => _CampaignTextDialog(
    title: title,
    label: label,
    action: action,
    validate: validate,
    submit: submit,
    help: help,
  ),
);

class _CampaignTextDialog extends StatefulWidget {
  const _CampaignTextDialog({
    required this.title,
    required this.label,
    required this.action,
    required this.validate,
    required this.submit,
    this.help,
  });

  final String title;
  final String label;
  final String action;
  final String? Function(String) validate;
  final Future<void> Function(String) submit;
  final String? help;

  @override
  State<_CampaignTextDialog> createState() => _CampaignTextDialogState();
}

class _CampaignTextDialogState extends State<_CampaignTextDialog> {
  final _input = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final value = _input.text.trim();
    final error = widget.validate(value);
    setState(() => _error = error);
    if (error != null) return;
    setState(() => _busy = true);
    try {
      await widget.submit(value);
      if (mounted) Navigator.pop(context, value);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _campaignError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: TextField(
        controller: _input,
        autofocus: true,
        enabled: !_busy,
        autocorrect: false,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.help,
          helperMaxLines: 3,
          errorText: _error,
          errorMaxLines: 3,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Aguarde…' : widget.action),
        ),
      ],
    ),
  );
}

class CampaignAccessScreen extends StatefulWidget {
  const CampaignAccessScreen({
    super.key,
    required this.campaign,
    required this.repository,
    required this.onBack,
  });

  final Campaign campaign;
  final CampaignRepository repository;
  final VoidCallback onBack;

  @override
  State<CampaignAccessScreen> createState() => _CampaignAccessScreenState();
}

class _CampaignAccessScreenState extends State<CampaignAccessScreen> {
  late Future<CampaignAccess> _access = widget.repository.readAccess(
    widget.campaign,
  );
  bool _busy = false;
  String? _code;

  void _refresh() {
    setState(() => _access = widget.repository.readAccess(widget.campaign));
  }

  Future<void> _editCode() async {
    final value = await askCampaignText(
      context,
      title: 'Código da campanha',
      label: 'Novo código',
      action: 'Salvar código',
      help: 'Use 10 a 48 letras sem acento, números, hífen ou sublinhado.',
      validate: (code) => campaignCodePattern.hasMatch(code)
          ? null
          : 'Confira o formato do código.',
      submit: (code) =>
          widget.repository.setCampaignCode(widget.campaign, code),
    );
    if (!mounted || value == null) return;
    _code = value;
    _refresh();
  }

  Future<void> _disableCode() async {
    setState(() => _busy = true);
    try {
      await widget.repository.setCampaignCode(widget.campaign, null);
      if (mounted) {
        _code = null;
        _refresh();
      }
    } on Exception catch (error) {
      if (mounted) _showMessage(_campaignError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    setState(() => _busy = true);
    try {
      final invitation = await widget.repository.createCampaignInvite(
        widget.campaign,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Convite individual'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Válido por 7 dias para uma pessoa.'),
              const SizedBox(height: 12),
              SelectableText(invitation),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: invitation));
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  _showMessage('Convite copiado.');
                }
              },
              child: const Text('Copiar convite'),
            ),
          ],
        ),
      );
    } on Exception catch (error) {
      if (mounted) _showMessage(_campaignError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (popped, _) {
      if (!popped && !_busy) widget.onBack();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _busy ? null : widget.onBack),
        title: const Text('Acesso e participantes'),
        actions: [
          IconButton(
            tooltip: 'Atualizar participantes',
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _refresh,
          ),
        ],
      ),
      body: FutureBuilder(
        future: _access,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível consultar a campanha.'),
            );
          }
          final access = snapshot.requireData;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.campaign.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                access.codeEnabled
                    ? 'Código compartilhado ativo'
                    : 'Código compartilhado desativado',
              ),
              if ((access.codeEnabled, _code) case (true, final String code))
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (mounted) _showMessage('Código copiado.');
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copiar código'),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton(
                    onPressed: _busy ? null : _editCode,
                    child: Text(
                      access.codeEnabled ? 'Trocar código' : 'Definir código',
                    ),
                  ),
                  if (access.codeEnabled)
                    TextButton(
                      onPressed: _busy ? null : _disableCode,
                      child: const Text('Desativar código'),
                    ),
                  OutlinedButton(
                    onPressed: _busy ? null : _invite,
                    child: const Text('Gerar convite individual'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Participantes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final member in access.members)
                ListTile(
                  title: Text(member.name),
                  subtitle: Text(member.isOwner ? 'Mestre' : 'Jogador'),
                ),
            ],
          );
        },
      ),
    ),
  );
}
