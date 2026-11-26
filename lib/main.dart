import 'dart:async';
import 'dart:convert';

import 'package:diacritic/diacritic.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show Uint8List, compute;
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_screens.dart';
import 'accounts.dart';
import 'campaign_access.dart';
import 'campaign_cover.dart';
import 'campaigns.dart';
import 'chronicle_export.dart';
import 'cover_frame.dart';
import 'gm_note_editor.dart';
import 'gm_note_page.dart';
import 'hypotheses.dart';
import 'hypothesis_fields.dart';
import 'login_audio.dart';
import 'login_layout.dart';
import 'mission_fields.dart';
import 'missions.dart';
import 'notebook_editor.dart';
import 'notebook_page.dart';
import 'notebook_sync.dart';
import 'offline_storage.dart';
import 'organize_cards.dart';
import 'session_dates.dart';
import 'trash_screen.dart';
import 'word_import.dart';
import 'word_import_screen.dart';

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
  bool _showPassword = false;
  late bool _soundEnabled = loginAudioEnabled;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _passwordAgain.dispose();
    super.dispose();
  }

  Future<void> _submitLogin(bool soundsAvailable) async {
    if (!_busy && !_registering && soundsAvailable && _soundEnabled) {
      playLoginAudio(entering: true);
    }
    await _signIn();
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
    final soundsAvailable = isDesktopWebLogin(MediaQuery.sizeOf(context).width);
    final onTyping = soundsAvailable && _soundEnabled
        ? (String _) => playLoginAudio(entering: false)
        : null;
    return LoginLayout(
      soundControl: soundsAvailable
          ? IconButton.filledTonal(
              tooltip: _soundEnabled
                  ? 'Silenciar login'
                  : 'Ativar sons do login',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xbd161b34),
                foregroundColor: const Color(0xffffe1ad),
              ),
              onPressed: () {
                setState(() => _soundEnabled = !_soundEnabled);
                setLoginAudioEnabled(_soundEnabled);
                if (_soundEnabled) playLoginAudio(entering: false);
              },
              icon: Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off),
            )
          : null,
      form: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_legacy) ...[
                const Text(
                  'Entre com a conta antiga e escolha seu nome de usuário em Minha conta.',
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _identifier,
                onChanged: onTyping,
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
                  _legacy ? AutofillHints.email : AutofillHints.username,
                ],
                validator: (text) {
                  if (_legacy) {
                    return text?.contains('@') == true
                        ? null
                        : 'Informe o e-mail da conta antiga.';
                  }
                  return isUsername(text) ? null : 'Informe o nome de usuário.';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                onChanged: onTyping,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Ocultar senha' : 'Mostrar senha',
                    onPressed: _busy
                        ? null
                        : () => setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      size: 19,
                    ),
                  ),
                ),
                obscureText: !_showPassword,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: _registering
                    ? null
                    : (_) => _submitLogin(soundsAvailable),
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
                onPressed: _busy ? null : () => _submitLogin(soundsAvailable),
                child: Text(
                  _busy
                      ? 'Aguarde…'
                      : _registering
                      ? 'Criar conta'
                      : 'Entrar',
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
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
                  if (!_registering)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _recovering = true),
                      child: const Text('Esqueci minha senha'),
                    ),
                ],
              ),
              if (!_registering) ...[
                const Divider(height: 1, color: Color(0x5ec1a9cd)),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _legacy = !_legacy;
                          _identifier.clear();
                          _password.clear();
                          _showPassword = false;
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

enum _ChronicleOrder { recent, oldest, manual }

typedef _NotebookDrag = ({
  Notebook notebook,
  List<String> all,
  List<String> visible,
  bool sessions,
});

const _uncategorizedView = 'Sem categoria';
const _notebookSections = {
  'Missão': 'Objetivos e missões',
  'Investigação': 'Mistérios e pistas',
  'Personagem': 'Pessoas importantes',
  'Lugar': 'Lugares importantes',
  'Objeto': 'Relíquias, objetos e sinais',
  'Carta': 'Cartas',
};

const _notebookSectionIcons = {
  'Missão': Icons.task_alt_outlined,
  'Investigação': Icons.search,
  'Personagem': Icons.people_outline,
  'Lugar': Icons.place_outlined,
  'Objeto': Icons.diamond_outlined,
  'Carta': Icons.mail_outline,
};

const _notebookSectionArt = {
  'Missão': 'missions',
  'Investigação': 'clues',
  'Personagem': 'people',
  'Lugar': 'places',
  'Objeto': 'relics',
  'Carta': 'letters',
};

enum _RecordAction { duplicate, trash }

enum _NotebookTool { importWord }

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
  bool _showCompletedMissions = false;
  bool _showClosedInvestigations = false;
  _ChronicleOrder? _chroniclePreference;
  bool _trashBusy = false;
  bool _readingWord = false;
  bool _exportingChronicles = false;
  final _recordWrites = <String>{};
  _NotebookDrag? _dragBasis;
  List<String>? _notebookOrderPreview;
  List<String>? _gmOrderPreview;
  _NotebookTab? _draggedTab;

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
    if (tab == _tab) {
      if (tab == _NotebookTab.records && _category != null) _openSection(null);
      return;
    }
    setState(() {
      _search.clear();
      _category = null;
      _showCompletedMissions = false;
      _showClosedInvestigations = false;
      _tab = tab;
      if (_tab == _NotebookTab.private) {
        _privateNotes = widget.repository.readGmNotes(widget.campaign);
      } else {
        _privateNotes = null;
      }
    });
  }

  void _openSection(String? category) {
    setState(() {
      _category = category;
      _search.clear();
      _showCompletedMissions = false;
      _showClosedInvestigations = false;
    });
  }

  void _back() {
    if (_tab == _NotebookTab.records && _category != null) {
      _openSection(null);
    } else {
      widget.onBack();
    }
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

  void _readRecord(Notebook notebook, CampaignRecord record) {
    setState(() {
      _editor = NotebookPage(
        record: record,
        repository: widget.repository,
        campaignId: widget.campaign.id,
        onBack: () => setState(() => _editor = null),
        onExport: record.category == 'Sessão'
            ? () => _exportChronicles(imageOf: record)
            : null,
        onEdit: record.id == null
            ? null
            : () => _edit(notebook, record: record),
      );
    });
  }

  Future<void> _exportChronicles({CampaignRecord? imageOf}) async {
    final notebook = _sync.notebook;
    if (_exportingChronicles ||
        notebook == null ||
        (imageOf == null && notebook.sessions.isEmpty)) {
      return;
    }
    setState(() => _exportingChronicles = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final action = canShareChronicleFile
          ? await showDialog<ChronicleExportAction>(
              context: context,
              builder: (context) => SimpleDialog(
                title: Text(
                  imageOf == null ? 'Exportar PDF' : 'Exportar imagem',
                ),
                children: [
                  SimpleDialogOption(
                    onPressed: () =>
                        Navigator.pop(context, ChronicleExportAction.share),
                    child: const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.share_outlined),
                      title: Text('Compartilhar'),
                    ),
                  ),
                  SimpleDialogOption(
                    onPressed: () =>
                        Navigator.pop(context, ChronicleExportAction.save),
                    child: const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.save_alt),
                      title: Text('Salvar no dispositivo'),
                    ),
                  ),
                ],
              ),
            )
          : ChronicleExportAction.save;
      if (!mounted || action == null) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Preparando arquivo…')),
      );
      final images = <String, Future<Uint8List>>{};
      Future<Uint8List> readImage(String hash) => images.putIfAbsent(
        hash,
        () => widget.repository
            .readNotebookCover(widget.campaign.id, hash)
            .timeout(notebookRequestTimeout),
      );
      final name = imageOf == null
          ? chronicleFileName('Crônicas ${widget.campaign.name}', 'pdf')
          : chronicleFileName(imageOf.title, 'png');
      final order =
          _chroniclePreference ??
          (notebook.sessions.any(
                (entry) => entry.orderIndex(chronicleOrder) != null,
              )
              ? _ChronicleOrder.manual
              : _ChronicleOrder.recent);
      final bytes = imageOf == null
          ? await exportChroniclesPdf(
              widget.campaign.name,
              _sortSessions(notebook.sessions, order),
              readImage,
            )
          : await exportChroniclePng(imageOf, readImage);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      await saveChronicleFile(
        bytes,
        name,
        imageOf == null ? 'application/pdf' : 'image/png',
        action: action,
      );
    } on FormatException catch (error) {
      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Exception {
      if (mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível exportar. Confira a conexão para baixar as imagens da crônica.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingChronicles = false);
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
        initialCategory: _notebookSections.containsKey(_category)
            ? _category
            : null,
        onClose: () => setState(() => _editor = null),
        onSaved: () => setState(() => _editor = null),
      );
    });
  }

  Future<void> _openWord() async {
    final notebook = _sync.notebook;
    if (_readingWord || notebook == null) return;
    setState(() => _readingWord = true);
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Documento Word',
            extensions: ['docx'],
            mimeTypes: [
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            ],
            uniformTypeIdentifiers: [
              'org.openxmlformats.wordprocessingml.document',
            ],
          ),
        ],
      );
      if (file == null || !mounted) return;
      if (!file.name.toLowerCase().endsWith('.docx')) {
        throw const FormatException(
          'Escolha um documento Word no formato .docx.',
        );
      }
      if (await file.length() > maxWordFileBytes) {
        throw const FormatException('Escolha um documento de até 12 MB.');
      }
      final preview = await compute(readWordDocument, await file.readAsBytes());
      if (!mounted) return;
      setState(() {
        _editor = WordImportScreen(
          campaign: widget.campaign,
          notebook: notebook,
          preview: preview,
          onClose: () => setState(() => _editor = null),
          onImport: (selection) => _saveWordImport(notebook, selection),
        );
      });
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o arquivo Word.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _readingWord = false);
    }
  }

  Future<void> _saveWordImport(
    Notebook notebook,
    List<CampaignRecord> selection,
  ) async {
    final result = await widget.repository
        .importNotebookRecords(widget.campaign.id, notebook, selection)
        .timeout(const Duration(seconds: 25));
    if (!mounted) return;
    setState(() => _editor = null);
    unawaited(_sync.refresh());
    final message = result.skipped == 0
        ? '${result.saved} registros importados.'
        : '${result.saved} registros importados. ${result.skipped} já existiam.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _duplicate(
    Future<void> Function(String id) submit,
    VoidCallback onSaved,
  ) async {
    if (_trashBusy) return;
    setState(() => _trashBusy = true);
    try {
      await submit(newNotebookRecordId()).timeout(notebookRequestTimeout);
      if (!mounted) return;
      onSaved();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cópia criada.')));
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(organizeMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _trashBusy = false);
    }
  }

  Future<void> _changeMission(
    Notebook notebook,
    CampaignRecord record,
    MissionPlan plan,
  ) async {
    await _queueRecordChange(notebook, record, mission: plan);
  }

  Future<void> _changeInvestigation(
    Notebook notebook,
    CampaignRecord record,
  ) async {
    final current = record.resolution;
    final hypothesis = record.confidence == 'Hipótese';
    final resolution = current.closed
        ? HypothesisResolution(reason: current.reason)
        : await showDialog<HypothesisResolution>(
            context: context,
            builder: (_) => InvestigationConclusionDialog(
              initialReason: current.reason,
              hypothesis: hypothesis,
            ),
          );
    if (!mounted || resolution == null) return;
    final queued = await _queueRecordChange(
      notebook,
      record,
      resolution: resolution,
    );
    if (!mounted || !queued || !resolution.closed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hypothesis
              ? 'Hipótese ${resolution.status.label.toLowerCase()}.'
              : 'Conclusão registrada.',
        ),
        action: SnackBarAction(
          label: 'Ver concluídas',
          onPressed: () {
            if (_category != 'Investigação') return;
            setState(() {
              _showClosedInvestigations = true;
            });
          },
        ),
      ),
    );
  }

  Future<bool> _queueRecordChange(
    Notebook notebook,
    CampaignRecord record, {
    MissionPlan? mission,
    HypothesisResolution? resolution,
  }) async {
    final id = record.id;
    final category = record.category;
    if (id == null ||
        category == null ||
        _recordWrites.contains(id) ||
        _sync.drafts.any((draft) => draft.id == id)) {
      return false;
    }
    setState(() => _recordWrites.add(id));
    try {
      await _sync.keep(
        NotebookDraft(
          id: id,
          category: category,
          epoch: notebook.epoch,
          text: record.text,
          original: record,
          mission: mission,
          resolution: resolution,
          status: DraftStatus.queued,
        ),
      );
      unawaited(_sync.refresh());
      return true;
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível guardar a alteração neste aparelho.',
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _recordWrites.remove(id));
    }
  }

  Future<void> _dropNotebookCard(_NotebookDrag drag, int from, int to) async {
    if (from == to ||
        _trashBusy ||
        from >= drag.visible.length ||
        to >= drag.visible.length) {
      return;
    }
    final ids = moveVisibleCard(drag.all, drag.visible, from, to);
    setState(() {
      _trashBusy = true;
      _draggedTab = drag.sessions
          ? _NotebookTab.sessions
          : _NotebookTab.records;
      _notebookOrderPreview = ids;
    });
    try {
      await widget.repository
          .reorderRecords(
            widget.campaign.id,
            drag.notebook,
            ids,
            sessions: drag.sessions,
          )
          .timeout(notebookRequestTimeout);
      await _sync.refreshAfterChange();
      if (mounted && drag.sessions) {
        setState(() => _chroniclePreference = _ChronicleOrder.manual);
      }
    } on Exception catch (error) {
      if (mounted) _showOrderError(error);
    } finally {
      if (mounted) {
        setState(() {
          _trashBusy = false;
          _notebookOrderPreview = null;
        });
      }
    }
  }

  Future<void> _dropGmCard(List<GmNote> group, int from, int to) async {
    if (from == to || _trashBusy) return;
    final ids = group.map((note) => note.id).toList();
    final item = ids.removeAt(from);
    ids.insert(to, item);
    setState(() {
      _trashBusy = true;
      _gmOrderPreview = ids;
    });
    try {
      await widget.repository
          .reorderGmNotes(widget.campaign, group, ids)
          .timeout(notebookRequestTimeout);
      if (mounted && _tab == _NotebookTab.private) {
        final notes = await widget.repository
            .readGmNotes(widget.campaign)
            .timeout(notebookRequestTimeout);
        if (mounted && _tab == _NotebookTab.private) {
          setState(() {
            _privateNotes = Future.value(notes);
          });
        }
      }
    } on Exception catch (error) {
      if (mounted) _showOrderError(error);
    } finally {
      if (mounted) {
        setState(() {
          _trashBusy = false;
          _gmOrderPreview = null;
        });
      }
    }
  }

  void _showOrderError(Object error) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(organizeMessage(error))));

  void _organizeNotebook(
    Notebook notebook,
    List<CampaignRecord> records,
    _NotebookDrag drag,
  ) {
    final cards = [
      for (final record in records)
        if (record.id case final id?) (id: id, title: record.title),
    ];
    setState(() {
      _editor = OrganizeCardsScreen(
        cards: cards,
        save: (ids) async {
          await widget.repository
              .reorderRecords(
                widget.campaign.id,
                notebook,
                replaceVisibleOrder(drag.all, ids),
                sessions: drag.sessions,
              )
              .timeout(notebookRequestTimeout);
          await _sync.refreshAfterChange();
        },
        onBack: () => setState(() => _editor = null),
        onSaved: () => setState(() {
          if (drag.sessions) _chroniclePreference = _ChronicleOrder.manual;
          _editor = null;
        }),
      );
    });
  }

  void _organizeGm(List<GmNote> notes) {
    setState(() {
      _editor = OrganizeCardsScreen(
        cards: [
          for (final note in notes) (id: note.id, title: note.text.title),
        ],
        save: (ids) => widget.repository
            .reorderGmNotes(widget.campaign, notes, ids)
            .timeout(notebookRequestTimeout),
        onBack: _closeGmEditor,
        onSaved: _closeGmEditor,
      );
    });
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
    if (!snapshot.hasData && snapshot.connectionState != ConnectionState.done) {
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
    final preview = {
      for (final (index, id) in (_gmOrderPreview ?? const <String>[]).indexed)
        id: index,
    };
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _editGmNote,
                icon: const Icon(Icons.add),
                label: const Text('Nova nota ou página'),
              ),
            ),
          ),
        ),
        if (notes.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('Seu roteiro está vazio.')),
            ),
          ),
        for (final section in sections.entries)
          if (section.value.isNotEmpty)
            ..._gmSection(
              section.key,
              orderCards(
                section.value,
                (note) => preview[note.id] ?? note.orderIndex,
              ),
            ),
      ],
    );
  }

  List<Widget> _gmSection(String label, List<GmNote> notes) => [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (notes.length > 1)
              IconButton(
                tooltip: 'Organizar $label',
                icon: const Icon(Icons.swap_vert),
                onPressed: _trashBusy ? null : () => _organizeGm(notes),
              ),
          ],
        ),
      ),
    ),
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverReorderableList(
        key: ValueKey(label),
        itemCount: notes.length,
        onReorderItem: (from, to) => _dropGmCard(notes, from, to),
        itemBuilder: (context, index) {
          final note = notes[index];
          return ReorderableDelayedDragStartListener(
            key: ValueKey(note.id),
            index: index,
            enabled: !_trashBusy && notes.length > 1,
            child: Card(
              child: ListTile(
                title: Text(note.text.title),
                subtitle: note.text.body.isEmpty
                    ? null
                    : Text(
                        note.text.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: PopupMenuButton<_RecordAction>(
                  enabled: !_trashBusy,
                  tooltip: 'Opções da nota',
                  onSelected: (_) => _duplicate(
                    (id) => widget.repository.duplicateGmNote(
                      widget.campaign,
                      note,
                      id,
                    ),
                    _closeGmEditor,
                  ),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: _RecordAction.duplicate,
                      child: Text('Duplicar'),
                    ),
                  ],
                ),
                onTap: () => _openGmNote(note),
              ),
            ),
          );
        },
      ),
    ),
  ];

  List<CampaignRecord> _sortSessions(
    List<CampaignRecord> records,
    _ChronicleOrder preference,
  ) {
    if (preference == _ChronicleOrder.manual) {
      return orderCards(records, (record) => record.orderIndex(chronicleOrder));
    }
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
      final order = preference == _ChronicleOrder.recent
          ? second.compareTo(first)
          : first.compareTo(second);
      return order == 0 ? a.index.compareTo(b.index) : order;
    });
    return rows.map((row) => row.record).toList(growable: false);
  }

  List<Widget> _syncNotices() => [
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
  ];

  Widget _sectionIndex(Notebook notebook, List<NotebookDraft> drafts) {
    final sections = {
      ..._notebookSections.keys,
      for (final record in notebook.records)
        record.category ?? _uncategorizedView,
      for (final draft in drafts) draft.category,
    };
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ..._syncNotices(),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Seções do caderno',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              PopupMenuButton<_NotebookTool>(
                enabled: !_readingWord && !_trashBusy,
                tooltip: _readingWord
                    ? 'Lendo Word…'
                    : 'Ferramentas do caderno',
                icon: _readingWord
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.more_vert),
                onSelected: (_) => _openWord(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _NotebookTool.importWord,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.upload_file_outlined),
                      title: Text('Importar Word'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        for (final section in sections) _sectionCard(section),
      ],
    );
  }

  Widget _sectionCard(String section) {
    final art = _notebookSectionArt[section];
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Stack(
        children: [
          if (art != null)
            Positioned.fill(
              child: Image.asset(
                'assets/notebook/$art.webp',
                fit: BoxFit.cover,
              ),
            ),
          if (art != null)
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xdd18110e),
                      Color(0x9c18110e),
                      Color(0x2418110e),
                    ],
                    stops: [0, 0.64, 1],
                  ),
                ),
              ),
            ),
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              minTileHeight: 102,
              textColor: art == null ? null : const Color(0xfff8ecda),
              iconColor: art == null ? null : const Color(0xfff8d8a3),
              leading: Icon(_notebookSectionIcons[section] ?? Icons.notes),
              titleTextStyle: Theme.of(context).textTheme.titleLarge,
              title: Text(
                _notebookSections[section] ?? section,
                style: art == null
                    ? null
                    : const TextStyle(color: Color(0xfff8ecda)),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSection(section),
            ),
          ),
        ],
      ),
    );
  }

  Widget _completionTabs(bool selected, ValueChanged<bool> onChanged) =>
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Ativas')),
          ButtonSegment(value: true, label: Text('Concluídas')),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (value) => onChanged(value.single),
      );

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
    if (!isSession && _category == null) {
      return _sectionIndex(notebook, allDrafts);
    }
    final isMissionSection = _category == 'Missão';
    final isInvestigationSection = _category == 'Investigação';
    final terms = removeDiacritics(_search.text.trim().toLowerCase())
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty);
    final searching = terms.isNotEmpty;

    bool matches(
      NotebookText text,
      String? category,
      List<String> dates,
      MissionPlan? mission,
      HypothesisResolution resolution,
    ) {
      if (!isSession && (category ?? _uncategorizedView) != _category) {
        return false;
      }
      if (isInvestigationSection &&
          resolution.closed != _showClosedInvestigations) {
        return false;
      }
      if (isMissionSection &&
          (mission?.completed ?? false) != _showCompletedMissions) {
        return false;
      }
      if (terms.isEmpty) return true;
      final content = removeDiacritics(
        [
          text.title,
          text.body,
          text.answer,
          text.confidence,
          category ?? '',
          if (isInvestigationSection && resolution.closed) resolution.reason,
          ...dates.map(sessionDateLabel),
          if (mission != null)
            for (final step in mission.steps) ...[step.title, step.details],
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
          draft.mission ?? draft.original?.mission,
          draft.resolution ??
              draft.original?.resolution ??
              const HypothesisResolution(),
        ))
          draft.id: draft,
    };
    final draftIds = allDrafts.map((draft) => draft.id).toSet();
    final matchingEntries = allEntries
        .where(
          (record) =>
              !draftIds.contains(record.id) &&
              matches(
                record.text,
                record.category,
                record.dates,
                record.mission,
                record.resolution,
              ),
        )
        .toList(growable: false);
    final preference =
        _chroniclePreference ??
        (allEntries.any((entry) => entry.orderIndex(chronicleOrder) != null)
            ? _ChronicleOrder.manual
            : _ChronicleOrder.recent);
    List<CampaignRecord> sortCards(List<CampaignRecord> source) => isSession
        ? _sortSessions(source, preference)
        : orderCards(source, (record) => record.orderIndex(notebookOrder));
    final ranked = sortCards(matchingEntries);
    final positions = {
      if (_draggedTab == _tab && _notebookOrderPreview != null)
        for (final (rank, id) in _notebookOrderPreview!.indexed) id: rank,
    };
    final entries = positions.isEmpty
        ? ranked
        : orderCards(ranked, (record) => positions[record.id]);
    final movable =
        entries.length > 1 && entries.every((record) => record.id != null);
    final drag = (
      notebook: notebook,
      sessions: isSession,
      all: [for (final record in sortCards(allEntries)) ?record.id],
      visible: [for (final record in entries) ?record.id],
    );
    final header = <Widget>[
      ..._syncNotices(),
      if (isMissionSection || isInvestigationSection)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _completionTabs(
            isMissionSection
                ? _showCompletedMissions
                : _showClosedInvestigations,
            (value) => setState(() {
              if (isMissionSection) {
                _showCompletedMissions = value;
              } else {
                _showClosedInvestigations = value;
              }
            }),
          ),
        ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if ((!isMissionSection || !_showCompletedMissions) &&
              (!isInvestigationSection || !_showClosedInvestigations))
            FilledButton.icon(
              onPressed: () => _edit(notebook),
              icon: const Icon(Icons.add),
              label: Text(
                isSession
                    ? 'Nova crônica'
                    : isMissionSection
                    ? 'Nova missão'
                    : 'Novo registro',
              ),
            ),
          const Spacer(),
          if (movable)
            IconButton(
              tooltip: 'Organizar cartões',
              icon: const Icon(Icons.swap_vert),
              onPressed: _trashBusy
                  ? null
                  : () => _organizeNotebook(notebook, entries, drag),
            ),
          if (isSession)
            PopupMenuButton<_ChronicleOrder>(
              icon: const Icon(Icons.sort),
              tooltip: 'Ordenar por data',
              initialValue: preference,
              onSelected: (value) =>
                  setState(() => _chroniclePreference = value),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _ChronicleOrder.recent,
                  child: Text('Mais recentes primeiro'),
                ),
                PopupMenuItem(
                  value: _ChronicleOrder.oldest,
                  child: Text('Mais antigas primeiro'),
                ),
                PopupMenuItem(
                  value: _ChronicleOrder.manual,
                  child: Text('Ordem manual'),
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
      for (final draft in drafts.values)
        Card(
          child: ListTile(
            leading: const Icon(Icons.edit_note_outlined),
            title: Text(
              draft.text.title.trim().isEmpty ? 'Sem título' : draft.text.title,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(switch (draft.status) {
                  DraftStatus.editing => 'Rascunho neste aparelho',
                  DraftStatus.queued => 'Aguardando envio',
                  DraftStatus.review => 'Revisar edição',
                }),
                if ((draft.resolution ?? draft.original?.resolution)
                    case final conclusion?
                    when conclusion.closed && isInvestigationSection)
                  InvestigationConclusion(
                    resolution: conclusion,
                    hypothesis: draft.text.confidence == 'Hipótese',
                    compact: true,
                  ),
                if (draft.mission ?? draft.original?.mission
                    case final mission?) ...[
                  MissionSummary(plan: mission),
                  if (mission.steps.isNotEmpty) MissionChecklist(plan: mission),
                ],
              ],
            ),
            onTap: draft.status == DraftStatus.queued
                ? null
                : () => _edit(notebook, draft: draft),
          ),
        ),
    ];
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      buildDefaultDragHandles: false,
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: header,
      ),
      itemCount: entries.isEmpty && drafts.isEmpty ? 1 : entries.length,
      onReorderStart: (_) => _dragBasis = drag,
      onReorderItem: (from, to) {
        final basis = _dragBasis ?? drag;
        _dragBasis = null;
        if (movable) unawaited(_dropNotebookCard(basis, from, to));
      },
      itemBuilder: (context, index) {
        if (entries.isEmpty) {
          return Padding(
            key: const ValueKey('empty-notebook-list'),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                searching
                    ? 'Nenhum resultado para esta busca.'
                    : isMissionSection
                    ? (_showCompletedMissions
                          ? 'Nenhuma missão concluída.'
                          : 'Nenhuma missão ativa.')
                    : isInvestigationSection
                    ? (_showClosedInvestigations
                          ? 'Nenhum registro concluído.'
                          : 'Nenhum registro ativo.')
                    : 'Nenhum registro nesta seção.',
              ),
            ),
          );
        }
        final record = entries[index];
        final plan = record.mission;
        final isHypothesis = record.confidence == 'Hipótese';
        final canChange =
            record.id != null && !_recordWrites.contains(record.id);
        final card = Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (record.coverHash case final hash?)
                InkWell(
                  onTap: () => _readRecord(notebook, record),
                  child: AspectRatio(
                    aspectRatio: notebookCoverAspectRatio,
                    child: NotebookCoverImage(
                      repository: widget.repository,
                      campaignId: widget.campaign.id,
                      hash: hash,
                      layout: record.presentation.cover,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (plan != null)
                          Tooltip(
                            message: plan.completed
                                ? 'Reabrir missão'
                                : 'Marcar missão como concluída',
                            child: Checkbox(
                              value: plan.completed,
                              onChanged: canChange
                                  ? (checked) => _changeMission(
                                      notebook,
                                      record,
                                      plan.copyWith(
                                        status: checked == true
                                            ? MissionStatus.completed
                                            : MissionStatus.inProgress,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        if (isInvestigationSection)
                          Tooltip(
                            message: record.resolution.closed
                                ? (isHypothesis
                                      ? 'Reabrir hipótese'
                                      : 'Reabrir registro')
                                : (isHypothesis
                                      ? 'Concluir hipótese'
                                      : 'Concluir registro'),
                            child: Checkbox(
                              value: record.resolution.closed,
                              onChanged: canChange
                                  ? (_) =>
                                        _changeInvestigation(notebook, record)
                                  : null,
                            ),
                          ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _readRecord(notebook, record),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                record.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ),
                        ),
                        if (record.id != null)
                          IconButton(
                            onPressed: () => _edit(notebook, record: record),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Editar',
                          ),
                        if (record.id != null)
                          PopupMenuButton<_RecordAction>(
                            enabled: !_trashBusy,
                            tooltip: 'Opções do registro',
                            onSelected: (action) {
                              switch (action) {
                                case _RecordAction.duplicate:
                                  _duplicate((id) async {
                                    await widget.repository.duplicateRecord(
                                      widget.campaign.id,
                                      notebook,
                                      record,
                                      id,
                                    );
                                    await _sync.refreshAfterChange();
                                  }, () {});
                                case _RecordAction.trash:
                                  _moveToTrash(record.title, () async {
                                    await _setRecordTrash(
                                      notebook,
                                      record,
                                      trashed: true,
                                    );
                                    await _sync.refreshAfterChange();
                                  }, () {});
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: _RecordAction.duplicate,
                                child: Text('Duplicar'),
                              ),
                              PopupMenuItem(
                                value: _RecordAction.trash,
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
                    if (plan != null) MissionSummary(plan: plan),
                    if (record.confidence case final confidence?
                        when !isHypothesis || !record.resolution.closed)
                      Text('Confiança · $confidence'),
                    if (isInvestigationSection && record.resolution.closed)
                      InvestigationConclusion(
                        resolution: record.resolution,
                        hypothesis: isHypothesis,
                        compact: true,
                      ),
                    if (record.body.isNotEmpty)
                      InkWell(
                        onTap: () => _readRecord(notebook, record),
                        child: Text(
                          record.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (plan != null)
                      MissionChecklist(
                        plan: plan,
                        onChanged: canChange
                            ? (updated) =>
                                  _changeMission(notebook, record, updated)
                            : null,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
        return ReorderableDelayedDragStartListener(
          key: ValueKey(record.id ?? 'notebook-$index'),
          index: index,
          enabled: movable && !_trashBusy,
          child: Listener(behavior: HitTestBehavior.opaque, child: card),
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
        if (!popped) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _back),
          title: Text(
            _notebookSections[_category] ?? _category ?? widget.campaign.name,
          ),
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
            if (_tab == _NotebookTab.sessions)
              IconButton(
                tooltip: 'Exportar todas as crônicas em PDF',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed:
                    _exportingChronicles ||
                        _sync.notebook?.sessions.isNotEmpty != true
                    ? null
                    : _exportChronicles,
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
