import 'dart:async';
import 'dart:convert';

import 'package:diacritic/diacritic.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_screens.dart';
import 'accounts.dart';
import 'campaign_access.dart';
import 'campaign_cover.dart';
import 'campaigns.dart';
import 'gm_note_editor.dart';
import 'gm_note_page.dart';
import 'notebook_editor.dart';
import 'notebook_sync.dart';
import 'offline_storage.dart';
import 'session_dates.dart';
import 'trash_screen.dart';

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
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final _accounts = AccountService(widget.client);
  final _passwordAgain = TextEditingController();
  bool _legacy = false;
  bool _registering = false;
  bool _recovering = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _passwordAgain.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_legacy) {
        await widget.client.auth.signInWithPassword(
          email: _identifier.text.trim(),
          password: _password.text,
        );
      } else {
        if (_registering) {
          await _accounts.register(_identifier.text.trim(), _password.text);
          if (!mounted) return;
          setState(() => _registering = false);
        }
        await _accounts.signIn(_identifier.text.trim(), _password.text);
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(
          () => _error = accountMessage(
            error,
            'Não foi possível entrar. Confira seus dados.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_recovering) {
      return PasswordRecoveryScreen(
        accounts: _accounts,
        onClose: () => setState(() => _recovering = false),
      );
    }
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
                      if (_legacy)
                        const Text(
                          'Entre com a conta antiga e escolha seu nome de usuário em Minha conta.',
                        ),
                      TextFormField(
                        controller: _identifier,
                        enabled: !_busy,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: _legacy
                              ? 'E-mail da conta antiga'
                              : 'Nome de usuário',
                        ),
                        keyboardType: _legacy
                            ? TextInputType.emailAddress
                            : TextInputType.text,
                        autofillHints: [
                          _legacy
                              ? AutofillHints.email
                              : AutofillHints.username,
                        ],
                        validator: (text) {
                          if (_legacy) {
                            return text?.contains('@') == true
                                ? null
                                : 'Informe o e-mail da conta antiga.';
                          }
                          return isUsername(text)
                              ? null
                              : 'Informe o nome de usuário.';
                        },
                      ),
                      TextFormField(
                        controller: _password,
                        enabled: !_busy,
                        decoration: const InputDecoration(labelText: 'Senha'),
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: _registering
                            ? null
                            : (_) => _signIn(),
                        validator: (text) {
                          if (text == null || text.isEmpty) {
                            return 'Informe sua senha.';
                          }
                          if (_registering && text.length < 8) {
                            return 'Use pelo menos 8 caracteres.';
                          }
                          return null;
                        },
                      ),
                      if (_registering) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordAgain,
                          enabled: !_busy,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar senha',
                          ),
                          onFieldSubmitted: (_) => _signIn(),
                          validator: (text) => text == _password.text
                              ? null
                              : 'As senhas precisam ser iguais.',
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (_error case final error?) Text(error),
                      FilledButton(
                        onPressed: _busy ? null : _signIn,
                        child: Text(
                          _busy
                              ? 'Aguarde…'
                              : _registering
                              ? 'Criar conta'
                              : 'Entrar',
                        ),
                      ),
                      if (_registering || !_legacy)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _registering = !_registering;
                                  _passwordAgain.clear();
                                  _error = null;
                                }),
                          child: Text(
                            _registering ? 'Já tenho conta' : 'Criar uma conta',
                          ),
                        ),
                      if (!_registering) ...[
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _recovering = true),
                          child: const Text('Esqueci minha senha'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                  _legacy = !_legacy;
                                  _identifier.clear();
                                  _password.clear();
                                  _error = null;
                                }),
                          child: Text(
                            _legacy
                                ? 'Usar nome de usuário'
                                : 'Primeiro acesso com a conta antiga',
                          ),
                        ),
                      ],
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
  late final _offlineStorage = deviceStorage(
    const String.fromEnvironment('SUPABASE_URL'),
    widget.userId,
  );
  bool get _currentAccount =>
      widget.client.auth.currentUser?.id == widget.userId;
  late Future<List<Campaign>> _campaigns = _loadCampaigns();
  Campaign? _selected;
  bool _accountOpen = false;

  Future<List<Campaign>> _loadCampaigns() async {
    const key = 'campaigns';
    try {
      final campaigns = await _repository.list().timeout(
        notebookRequestTimeout,
      );
      if (_currentAccount) {
        try {
          await _offlineStorage.write(
            key,
            jsonEncode(campaigns.map((campaign) => campaign.toJson()).toList()),
          );
        } on Exception {
          // The network response is still usable when the device cache fails.
        }
      }
      return campaigns;
    } on Exception catch (error) {
      if (!isConnectionFailure(error) || !_currentAccount) rethrow;
      final cached = await _offlineStorage.read(key);
      if (cached == null) rethrow;
      return (jsonDecode(cached) as List)
          .cast<Map<String, dynamic>>()
          .map(Campaign.fromJson)
          .toList();
    }
  }

  Future<void> _createCampaign() async {
    final id = newNotebookRecordId();
    final name = await askCampaignText(
      context,
      title: 'Criar campanha',
      label: 'Nome da campanha',
      action: 'Criar',
      validate: (name) => name.isEmpty || name.runes.length > 100
          ? 'Use de 1 a 100 caracteres.'
          : null,
      submit: (name) => _repository.createCampaign(id, name),
    );
    if (!mounted || name == null) return;
    setState(() {
      _campaigns = _loadCampaigns();
      _selected = Campaign(id: id, name: name, ownerId: widget.userId);
    });
  }

  Future<void> _joinCampaign() async {
    final joined = await askCampaignText(
      context,
      title: 'Entrar por código',
      label: 'Código ou convite',
      action: 'Entrar na campanha',
      validate: (code) =>
          campaignCodePattern.hasMatch(code) ||
              campaignInvitePattern.hasMatch(code)
          ? null
          : 'Confira o código recebido do mestre.',
      submit: _repository.joinCampaign,
    );
    if (!mounted || joined == null) return;
    setState(() => _campaigns = _loadCampaigns());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Campanha adicionada às suas mesas.')),
    );
  }

  Future<void> _editCover(Campaign campaign) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          CampaignCoverDialog(campaign: campaign, repository: _repository),
    );
    if (mounted) setState(() => _campaigns = _loadCampaigns());
  }

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
    if (_accountOpen) {
      return AccountSettingsScreen(
        accounts: AccountService(widget.client),
        onClose: () => setState(() => _accountOpen = false),
      );
    }
    final campaign = _selected;
    if (campaign != null) {
      return NotebookScreen(
        key: ValueKey(campaign.id),
        campaign: campaign,
        repository: _repository,
        isOwner: campaign.ownerId == widget.userId,
        offlineStorage: _offlineStorage,
        isCurrentAccount: () => _currentAccount,
        onBack: () => setState(() => _selected = null),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suas campanhas'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _accountOpen = true),
            icon: const Icon(Icons.manage_accounts_outlined),
            tooltip: 'Minha conta',
          ),
          IconButton(
            onPressed: () => setState(() => _campaigns = _loadCampaigns()),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilledButton.icon(
                    onPressed: _createCampaign,
                    icon: const Icon(Icons.add),
                    label: const Text('Criar campanha'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _joinCampaign,
                    icon: const Icon(Icons.key_outlined),
                    label: const Text('Entrar por código'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder(
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
                  return const Center(
                    child: Text('Nenhuma campanha disponível.'),
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                      itemCount: campaigns.length,
                      itemBuilder: (context, index) {
                        final campaign = campaigns[index];
                        final isOwner = campaign.ownerId == widget.userId;
                        return CampaignCard(
                          key: ValueKey(campaign.id),
                          campaign: campaign,
                          repository: _repository,
                          isOwner: isOwner,
                          onOpen: () => setState(() => _selected = campaign),
                          onEditCover: isOwner
                              ? () => _editCover(campaign)
                              : null,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
    this.offlineStorage,
    this.isCurrentAccount,
  });

  final Campaign campaign;
  final CampaignRepository repository;
  final bool isOwner;
  final VoidCallback onBack;
  final OfflineStorage? offlineStorage;
  final bool Function()? isCurrentAccount;

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen>
    with WidgetsBindingObserver {
  late final NotebookSync _sync;
  Timer? _poll;
  final _search = TextEditingController();
  String? _category;
  bool _recentFirst = true;
  bool _trashBusy = false;

  @override
  void initState() {
    super.initState();
    _sync = NotebookSync(
      repository: widget.repository,
      campaignId: widget.campaign.id,
      storage: widget.offlineStorage ?? MemoryOfflineStorage(),
      isCurrentAccount: widget.isCurrentAccount ?? () => true,
    )..addListener(_onSync);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_sync.load());
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == null || state == AppLifecycleState.resumed) {
        unawaited(_sync.refresh());
      }
    });
  }

  void _onSync() {
    if (mounted && _editor == null && _tab != _NotebookTab.private) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_sync.refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _search.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _sync.dispose();
    super.dispose();
  }

  Future<List<GmNote>>? _privateNotes;
  _NotebookTab _tab = _NotebookTab.records;
  Widget? _editor;

  void _selectTab(_NotebookTab tab) {
    if (tab == _tab) return;
    setState(() {
      _search.clear();
      _category = null;
      _tab = tab;
      if (_tab == _NotebookTab.private) {
        _privateNotes = widget.repository.readGmNotes(widget.campaign);
      } else {
        _privateNotes = null;
      }
    });
  }

  void _refresh() {
    if (_tab == _NotebookTab.private) {
      setState(() {
        _privateNotes = widget.repository.readGmNotes(widget.campaign);
      });
    } else {
      unawaited(_sync.refresh());
    }
  }

  void _edit(
    Notebook notebook, {
    CampaignRecord? record,
    NotebookDraft? draft,
  }) {
    setState(() {
      _editor = NotebookEditor(
        sync: _sync,
        epoch: notebook.epoch,
        isSession: draft?.isSession ?? _tab == _NotebookTab.sessions,
        record: record,
        savedDraft: draft,
        onClose: () => setState(() => _editor = null),
        onSaved: () => setState(() => _editor = null),
      );
    });
  }

  void _openTrash() {
    final private = _tab == _NotebookTab.private;
    setState(() {
      _editor = private
          ? TrashScreen<GmNote>(
              title: 'Lixeira do mestre',
              load: () => widget.repository
                  .readGmNotes(widget.campaign, trashed: true)
                  .timeout(notebookRequestTimeout),
              itemTitle: (note) => note.text.title,
              itemCategory: (note) => note.text.kind == GmNoteKind.note
                  ? note.text.section.label
                  : note.text.kind.label,
              restore: (note) => widget.repository
                  .setGmTrash(widget.campaign, note, trashed: false)
                  .timeout(notebookRequestTimeout),
              onBack: _closeGmEditor,
            )
          : TrashScreen<CampaignRecord>(
              title: 'Lixeira',
              load: () async {
                await _sync.refreshAfterChange();
                final notebook = _sync.notebook;
                if (notebook == null) {
                  throw NotebookConflict(
                    _sync.error ?? 'Não foi possível abrir o caderno.',
                  );
                }
                return notebook.trash;
              },
              itemTitle: (record) => record.title,
              itemCategory: (record) =>
                  record.category == 'Sessão' ? 'Crônica' : record.category,
              restore: (record) async {
                final notebook = _sync.notebook;
                if (notebook == null) {
                  throw const NotebookConflict(
                    'Atualize o caderno e tente novamente.',
                  );
                }
                await _setRecordTrash(notebook, record, trashed: false);
              },
              onBack: () => setState(() => _editor = null),
            );
    });
  }

  Future<void> _setRecordTrash(
    Notebook notebook,
    CampaignRecord record, {
    required bool trashed,
  }) => widget.repository
      .setNotebookTrash(widget.campaign.id, notebook, record, trashed: trashed)
      .timeout(notebookRequestTimeout);

  Future<void> _moveToTrash(
    String title,
    Future<void> Function() submit,
    VoidCallback onSuccess,
  ) async {
    if (_trashBusy) return;
    setState(() => _trashBusy = true);
    try {
      if (!await confirmMoveToTrash(context, title) || !mounted) return;
      await submit();
      if (!mounted) return;
      onSuccess();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Movido para a lixeira.')));
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(trashMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _trashBusy = false);
    }
  }

  void _openGmNote(GmNote note) {
    setState(() {
      _editor = GmNotePage(
        repository: widget.repository,
        campaign: widget.campaign,
        note: note,
        onBack: _closeGmEditor,
        onEdit: () => _editGmNote(note),
        onTrash: () => _moveToTrash(
          note.text.title,
          () => widget.repository
              .setGmTrash(widget.campaign, note, trashed: true)
              .timeout(notebookRequestTimeout),
          _closeGmEditor,
        ),
      );
    });
  }

  void _editGmNote([GmNote? note]) {
    setState(() {
      _editor = GmNoteEditor(
        repository: widget.repository,
        campaign: widget.campaign,
        note: note,
        onClose: note == null ? _closeGmEditor : () => _openGmNote(note),
        onSaved: () {
          _closeGmEditor();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Nota privada salva.')));
        },
      );
    });
  }

  void _closeGmEditor() => setState(() {
    _editor = null;
    _privateNotes = widget.repository.readGmNotes(widget.campaign);
  });

  Widget _gmNotes(AsyncSnapshot<List<GmNote>> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return const Center(child: Text('Não foi possível abrir o roteiro.'));
    }
    final notes = snapshot.requireData;
    final sections = <String, List<GmNote>>{
      for (final kind in GmNoteKind.values)
        if (kind != GmNoteKind.note) kind.plural: [],
      for (final section in GmSection.values) section.label: [],
    };
    for (final note in notes) {
      final text = note.text;
      final label = text.kind == GmNoteKind.note
          ? text.section.label
          : text.kind.plural;
      sections[label]!.add(note);
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _editGmNote,
            icon: const Icon(Icons.add),
            label: const Text('Nova nota ou página'),
          ),
        ),
        if (notes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('Seu roteiro está vazio.')),
          ),
        for (final section in sections.entries)
          if (section.value.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
              child: Text(
                section.key,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final note in section.value)
              Card(
                child: ListTile(
                  title: Text(note.text.title),
                  subtitle: note.text.body.isEmpty
                      ? null
                      : Text(
                          note.text.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openGmNote(note),
                ),
              ),
          ],
      ],
    );
  }

  List<CampaignRecord> _orderSessions(List<CampaignRecord> records) {
    final rows = [
      for (final (index, record) in records.indexed)
        (index: index, date: firstSessionDay(record.dates), record: record),
    ];
    rows.sort((a, b) {
      final first = a.date;
      final second = b.date;
      if (first == null && second == null) return a.index.compareTo(b.index);
      if (first == null) return 1;
      if (second == null) return -1;
      final order = _recentFirst
          ? second.compareTo(first)
          : first.compareTo(second);
      return order == 0 ? a.index.compareTo(b.index) : order;
    });
    return rows.map((row) => row.record).toList(growable: false);
  }

  Widget _records() {
    final notebook = _sync.notebook;
    if (notebook == null) {
      final error = _sync.error;
      if (error == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error, textAlign: TextAlign.center),
        ),
      );
    }
    final isSession = _tab == _NotebookTab.sessions;
    final allEntries = isSession ? notebook.sessions : notebook.records;
    final allDrafts = _sync.drafts
        .where((draft) => draft.isSession == isSession)
        .toList();
    final categories = {
      ?_category,
      for (final record in allEntries) ?record.category,
      for (final draft in allDrafts) draft.category,
    }.toList()..sort();
    final terms = removeDiacritics(_search.text.trim().toLowerCase())
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    final searching = terms.isNotEmpty || _category != null;

    bool matches(NotebookText text, String? category, List<String> dates) {
      if (_category != null && category != _category) return false;
      if (terms.isEmpty) return true;
      final content = removeDiacritics(
        [
          text.title,
          text.body,
          text.answer,
          text.confidence,
          category ?? '',
          ...dates.map(sessionDateLabel),
        ].join(' ').toLowerCase(),
      );
      return terms.every(content.contains);
    }

    final drafts = {
      for (final draft in allDrafts)
        if (matches(
          draft.text,
          draft.category,
          draft.dates ?? draft.original?.dates ?? const [],
        ))
          draft.id: draft,
    };
    final draftIds = allDrafts.map((draft) => draft.id).toSet();
    final matchingEntries = allEntries
        .where(
          (record) =>
              !draftIds.contains(record.id) &&
              matches(record.text, record.category, record.dates),
        )
        .toList(growable: false);
    final entries = isSession
        ? _orderSessions(matchingEntries)
        : matchingEntries;
    final header = <Widget>[
      if (_sync.localError)
        const ListTile(
          leading: Icon(Icons.warning_amber_outlined),
          title: Text('Falha ao gravar a cópia neste aparelho.'),
        ),
      if (_sync.offline || _sync.error != null)
        ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: Text(_sync.error ?? 'Sem conexão · cópia neste aparelho'),
        ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FilledButton.icon(
            onPressed: () => _edit(notebook),
            icon: const Icon(Icons.add),
            label: Text(isSession ? 'Nova crônica' : 'Novo registro'),
          ),
          if (isSession)
            PopupMenuButton<bool>(
              icon: const Icon(Icons.sort),
              tooltip: 'Ordenar por data',
              initialValue: _recentFirst,
              onSelected: (recent) => setState(() => _recentFirst = recent),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: true,
                  child: Text('Mais recentes primeiro'),
                ),
                PopupMenuItem(
                  value: false,
                  child: Text('Mais antigas primeiro'),
                ),
              ],
            ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextField(
          controller: _search,
          decoration: InputDecoration(
            labelText: isSession ? 'Buscar crônicas' : 'Buscar no caderno',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () => setState(_search.clear),
                    icon: const Icon(Icons.close),
                    tooltip: 'Limpar busca',
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      if (!isSession && categories.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: DropdownButton<String>(
            value: _category,
            hint: const Text('Todas as categorias'),
            isExpanded: true,
            items: [
              const DropdownMenuItem(child: Text('Todas as categorias')),
              for (final category in categories)
                DropdownMenuItem(value: category, child: Text(category)),
            ],
            onChanged: (category) => setState(() => _category = category),
          ),
        ),
      for (final draft in drafts.values)
        Card(
          child: ListTile(
            leading: const Icon(Icons.edit_note_outlined),
            title: Text(
              draft.text.title.trim().isEmpty ? 'Sem título' : draft.text.title,
            ),
            subtitle: Text(switch (draft.status) {
              DraftStatus.editing => 'Rascunho neste aparelho',
              DraftStatus.queued => 'Aguardando envio',
              DraftStatus.review => 'Revisar edição',
            }),
            onTap: draft.status == DraftStatus.queued
                ? null
                : () => _edit(notebook, draft: draft),
          ),
        ),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount:
          header.length +
          (entries.isEmpty && drafts.isEmpty ? 1 : entries.length),
      itemBuilder: (context, index) {
        if (index < header.length) return header[index];
        if (entries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                searching
                    ? 'Nenhum resultado para esta busca.'
                    : 'Nenhum registro nesta aba.',
              ),
            ),
          );
        }
        final record = entries[index - header.length];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (record.id != null)
                      IconButton(
                        onPressed: () => _edit(notebook, record: record),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Editar',
                      ),
                    if (record.id != null)
                      PopupMenuButton<bool>(
                        enabled: !_trashBusy,
                        tooltip: 'Opções do registro',
                        onSelected: (_) => _moveToTrash(record.title, () async {
                          await _setRecordTrash(
                            notebook,
                            record,
                            trashed: true,
                          );
                          await _sync.refreshAfterChange();
                        }, () {}),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: true,
                            child: Text('Mover para a lixeira'),
                          ),
                        ],
                      ),
                  ],
                ),
                if (isSession && record.dates.isNotEmpty)
                  Text(
                    record.dates.map(sessionDateLabel).join(' · '),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                if (!isSession && record.category != null)
                  Text(record.category!),
                if (record.confidence case final confidence?)
                  Text('Confiança · $confidence'),
                if (record.body.isNotEmpty) SelectableText(record.body),
                if (record.answer.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Resposta'),
                  SelectableText(record.answer),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_editor case final editor?) return editor;
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
            if (widget.isOwner)
              IconButton(
                icon: const Icon(Icons.group_outlined),
                tooltip: 'Acesso e participantes',
                onPressed: () => setState(() {
                  _editor = CampaignAccessScreen(
                    campaign: widget.campaign,
                    repository: widget.repository,
                    onBack: () => setState(() => _editor = null),
                  );
                }),
              ),
            IconButton(
              onPressed: _trashBusy ? null : _openTrash,
              icon: const Icon(Icons.delete_outline),
              tooltip: _tab == _NotebookTab.private
                  ? 'Lixeira do mestre'
                  : 'Lixeira',
            ),
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar',
            ),
          ],
        ),
        body: _tab == _NotebookTab.private
            ? FutureBuilder(
                future: _privateNotes,
                builder: (context, snapshot) => _gmNotes(snapshot),
              )
            : _records(),
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
