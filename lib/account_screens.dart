import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'accounts.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({
    super.key,
    required this.accounts,
    required this.onClose,
  });
  final AccountService accounts;
  final VoidCallback onClose;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _username = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _enterCode = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _username.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _message = null;
      _busy = true;
    });
    try {
      if (_enterCode) {
        await widget.accounts.call('recover', {
          'username': _username.text.trim(),
          'code': _code.text,
          'password': _password.text,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha alterada. Entre com a nova senha.'),
          ),
        );
        widget.onClose();
      } else {
        await widget.accounts.call('request', {
          'username': _username.text.trim(),
        });
        if (mounted) {
          setState(() {
            _enterCode = true;
            _message = 'Se você configurou um mestre para recuperação, avise-o do pedido.';
          });
        }
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () =>
              _message = accountMessage(error, 'Tente novamente em instantes.'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (popped, _) {
      if (!popped && !_busy) widget.onClose();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _busy ? () {} : widget.onClose),
        title: const Text('Esqueci minha senha'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _username,
              enabled: !_busy,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Nome de usuário'),
              validator: (value) =>
                  isUsername(value) ? null : 'Informe o nome de usuário.',
            ),
            if (_enterCode) ...[
              TextFormField(
                controller: _code,
                enabled: !_busy,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Código do mestre ou de reserva',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Informe o código.'
                    : null,
              ),
              TextFormField(
                controller: _password,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nova senha'),
                validator: (value) => (value?.length ?? 0) < 8
                    ? 'Use pelo menos 8 caracteres.'
                    : null,
              ),
              TextFormField(
                controller: _confirmation,
                enabled: !_busy,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nova senha',
                ),
                validator: (value) => value == _password.text
                    ? null
                    : 'As senhas precisam ser iguais.',
              ),
            ],
            const SizedBox(height: 16),
            if (_message case final message?) Text(message),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(
                _busy
                    ? 'Aguarde…'
                    : (_enterCode ? 'Alterar senha' : 'Pedir código ao mestre'),
              ),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _enterCode = !_enterCode;
                      _message = null;
                    }),
              child: Text(
                _enterCode ? 'Pedir código ao mestre' : 'Já tenho um código',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({
    super.key,
    required this.accounts,
    required this.onClose,
  });
  final AccountService accounts;
  final VoidCallback onClose;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _username = TextEditingController();
  late Future<Map<String, dynamic>> _settings = _load();
  String? _campaignId;
  bool _busy = false;
  String? _message;

  Future<Map<String, dynamic>> _load() async {
    final settings = await widget.accounts.call('settings');
    if (mounted) {
      _username.text = settings['username'] as String? ?? '';
      _campaignId = settings['recovery_campaign_id'] as String?;
    }
    return settings;
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _run(String action, {String? requestId}) async {
    if (_busy) return;
    if (action == 'setup' && !isUsername(_username.text)) {
      setState(
        () => _message =
            'Use de 3 a 24 caracteres: letras, números, ponto, _ ou hífen.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await widget.accounts.call(action, {
        if (action == 'setup') ...{
          'username': _username.text,
          'campaign_id': _campaignId,
        },
        'request_id': ?requestId,
      });
      if (!mounted) return;
      if (result['code'] case final String code) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              action == 'backup' ? 'Código de reserva' : 'Código do jogador',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(code),
                const SizedBox(height: 12),
                Text(
                  action == 'backup'
                      ? 'Guarde este código em local seguro. Ele aparece uma vez e substitui o anterior.'
                      : 'Envie apenas ao jogador que pediu. O código expira em 15 minutos.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Copiar e fechar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _settings = _load();
        if (action == 'setup') _message = 'Configuração da conta salva.';
      });
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () => _message = accountMessage(
            error,
            'Não foi possível concluir. Tente de novo.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (popped, _) {
      if (!popped && !_busy) widget.onClose();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _busy ? () {} : widget.onClose),
        title: const Text('Minha conta'),
        actions: [
          IconButton(
            onPressed: _busy ? null : () => setState(() => _settings = _load()),
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar pedidos',
          ),
        ],
      ),
      body: FutureBuilder(
        future: _settings,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final settings = snapshot.data;
          if (settings == null) {
            return Center(
              child: OutlinedButton(
                onPressed: () => setState(() => _settings = _load()),
                child: const Text('Tentar carregar a conta novamente'),
              ),
            );
          }
          final campaigns = settings['campaigns'] as List;
          final requests = settings['pending'] as List;
          if (!campaigns.any((campaign) => campaign['id'] == _campaignId)) {
            _campaignId = null;
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (settings['username'] == null)
                const Text('Escolha o nome de usuário que usará para entrar.'),
              TextField(
                controller: _username,
                enabled: !_busy,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Nome de usuário'),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(settings),
                initialValue: _campaignId ?? '',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Mestre autorizado a recuperar sua conta',
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Nenhum mestre autorizado'),
                  ),
                  for (final campaign in campaigns)
                    DropdownMenuItem<String>(
                      value: campaign['id'] as String,
                      child: Text('Mestre de ${campaign['name']}'),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => _campaignId = value == '' ? null : value,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : () => _run('setup'),
                child: const Text('Salvar configuração da conta'),
              ),
              if (settings['username'] != null)
                OutlinedButton(
                  onPressed: _busy ? null : () => _run('backup'),
                  child: Text(
                    settings['has_backup'] == true
                        ? 'Substituir código de reserva'
                        : 'Gerar código de reserva',
                  ),
                ),
              if (requests.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Pedidos de recuperação',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text('Confirme com o jogador antes de aprovar.'),
                for (final request in requests)
                  ListTile(
                    title: Text(request['username'] as String),
                    subtitle: Text(request['campaign'] as String),
                    trailing: TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              'approve',
                              requestId: request['id'] as String,
                            ),
                      child: const Text('Aprovar'),
                    ),
                  ),
              ],
              if (_message case final message?) Text(message),
            ],
          );
        },
      ),
    ),
  );
}
