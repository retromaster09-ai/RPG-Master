import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'campaigns.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  final endpoint = Uri.tryParse(url);
  SupabaseClient? client;
  if (endpoint != null &&
      endpoint.scheme == 'https' &&
      endpoint.host.isNotEmpty &&
      publishableKey.startsWith('sb_publishable_')) {
    await Supabase.initialize(url: url, publishableKey: publishableKey);
    client = Supabase.instance.client;
  }
  runApp(RpgMasterSet(client: client));
}

class RpgMasterSet extends StatelessWidget {
  const RpgMasterSet({super.key, this.client});

  final SupabaseClient? client;

  @override
  Widget build(BuildContext context) {
    final configuredClient = client;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RPG Master Set',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffa86d3a),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff191513),
        fontFamily: 'Crimson Text',
      ),
      home: configuredClient == null
          ? const Scaffold(
              body: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Configure o Supabase para abrir a campanha.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          : AuthGate(client: configuredClient),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.client});

  final SupabaseClient client;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _subscription;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = widget.client.auth.currentUser?.id;
    _subscription = widget.client.auth.onAuthStateChange.listen(
      (state) {
        if (mounted) setState(() => _userId = state.session?.user.id);
      },
      onError: (Object error) {
        if (mounted) {
          setState(() => _userId = widget.client.auth.currentUser?.id);
        }
      },
    );
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _userId;
    return userId == null
        ? SignInScreen(client: widget.client)
        : CampaignScreen(
            key: ValueKey(userId),
            client: widget.client,
            userId: userId,
          );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.client});

  final SupabaseClient client;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on Exception {
      if (mounted) {
        setState(() => _error = 'Não foi possível entrar. Confira seus dados.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/brand/emblem.png', height: 100),
                      Text(
                        'RPG Master Set',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'E-mail'),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: (text) => text == null || text.trim().isEmpty
                            ? 'Informe o e-mail da sua conta.'
                            : null,
                      ),
                      TextFormField(
                        controller: _password,
                        decoration: const InputDecoration(labelText: 'Senha'),
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _signIn(),
                        validator: (text) => text == null || text.isEmpty
                            ? 'Informe sua senha.'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      if (_error case final error?) Text(error),
                      FilledButton(
                        onPressed: _busy ? null : _signIn,
                        child: Text(_busy ? 'Entrando…' : 'Entrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CampaignScreen extends StatefulWidget {
  const CampaignScreen({super.key, required this.client, required this.userId});

  final SupabaseClient client;
  final String userId;

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  late final _repository = CampaignRepository(widget.client);
  late Future<List<Campaign>> _campaigns = _repository.list();
  Campaign? _selected;

  Future<void> _signOut() async {
    try {
      await widget.client.auth.signOut();
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível sair. Tente de novo.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaign = _selected;
    if (campaign != null) {
      return NotebookScreen(
        key: ValueKey(campaign.id),
        campaign: campaign,
        repository: _repository,
        isOwner: campaign.ownerId == widget.userId,
        onBack: () => setState(() => _selected = null),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suas campanhas'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _campaigns = _repository.list()),
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: FutureBuilder(
        future: _campaigns,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar suas campanhas.'),
            );
          }
          final campaigns = snapshot.data!;
          if (campaigns.isEmpty) {
            return const Center(child: Text('Nenhuma campanha disponível.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: campaigns.length,
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              return Card(
                child: ListTile(
                  title: Text(campaign.name),
                  subtitle: Text(
                    campaign.ownerId == widget.userId ? 'Mestre' : 'Jogador',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => _selected = campaign),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

enum _NotebookTab { records, sessions, private }

class NotebookScreen extends StatefulWidget {
  const NotebookScreen({
    super.key,
    required this.campaign,
    required this.repository,
    required this.isOwner,
    required this.onBack,
  });

  final Campaign campaign;
  final CampaignRepository repository;
  final bool isOwner;
  final VoidCallback onBack;

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  late Future<Notebook> _notebook = widget.repository.readNotebook(
    widget.campaign.id,
  );
  Future<List<CampaignRecord>>? _privateNotes;
  _NotebookTab _tab = _NotebookTab.records;

  void _selectTab(_NotebookTab tab) {
    setState(() {
      _tab = tab;
      if (_tab == _NotebookTab.private) {
        _privateNotes = widget.repository.readGmNotes(widget.campaign);
      } else {
        _privateNotes = null;
      }
    });
  }

  void _refresh() {
    setState(() {
      if (_tab == _NotebookTab.private) {
        _privateNotes = widget.repository.readGmNotes(widget.campaign);
      } else {
        _notebook = widget.repository.readNotebook(widget.campaign.id);
      }
    });
  }

  Future<List<CampaignRecord>> _sharedRecords() async {
    final sessions = _tab == _NotebookTab.sessions;
    final notebook = await _notebook;
    return sessions ? notebook.sessions : notebook.records;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) widget.onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: widget.onBack),
          title: Text(widget.campaign.name),
          actions: [
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar',
            ),
          ],
        ),
        body: FutureBuilder(
          future: _tab == _NotebookTab.private
              ? _privateNotes
              : _sharedRecords(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final message = snapshot.error is FormatException
                  ? 'Esta versão ainda precisa do formato dos registros.'
                  : 'Não foi possível carregar os registros.';
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(message, textAlign: TextAlign.center),
                ),
              );
            }
            final records = snapshot.data!;
            if (records.isEmpty) {
              return const Center(child: Text('Nenhum registro nesta aba.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (record.title.isNotEmpty)
                          Text(
                            record.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        if (record.confidence case final confidence?)
                          Text('Confiança · $confidence'),
                        if (record.body.isNotEmpty) SelectableText(record.body),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (index) =>
              _selectTab(_NotebookTab.values[index]),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              label: 'Caderno',
            ),
            const NavigationDestination(
              icon: Icon(Icons.history_edu_outlined),
              label: 'Crônicas',
            ),
            if (widget.isOwner)
              const NavigationDestination(
                icon: Icon(Icons.lock_outline),
                label: 'Mestre',
              ),
          ],
        ),
      ),
    );
  }
}
