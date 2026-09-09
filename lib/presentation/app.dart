import 'package:flutter/material.dart';
import '../domain/models.dart';

const ink = Color(0xFF173B35);
const paper = Color(0xFFF5F3EC);

class CarnetApp extends StatefulWidget {
  final AuthenticationRepository auth;
  final ContentRepository Function(String) repositoryFor;
  final Map<String, dynamic>? initialSession;
  const CarnetApp({
    super.key,
    required this.auth,
    required this.repositoryFor,
    this.initialSession,
  });
  @override
  State<CarnetApp> createState() => _CarnetAppState();
}

class _CarnetAppState extends State<CarnetApp> {
  late Map<String, dynamic>? session = widget.initialSession;
  final messenger = GlobalKey<ScaffoldMessengerState>();
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Carnet',
    debugShowCheckedModeBanner: false,
    scaffoldMessengerKey: messenger,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: ink, surface: paper),
      scaffoldBackgroundColor: paper,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
      ),
    ),
    home: session == null
        ? AuthScreen(
            auth: widget.auth,
            onSession: (s) => setState(() => session = s),
          )
        : HomeScreen(
            key: ValueKey(session!['user']['id']),
            name: session!['user']['name'] as String,
            repository: widget.repositoryFor('${session!['user']['id']}'),
            onLogout: () async {
              final revoked = await widget.auth.logout();
              if (!mounted) return;
              setState(() => session = null);
              if (!revoked) {
                messenger.currentState?.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Déconnexion locale effectuée. La révocation sur le serveur n’a pas pu être confirmée.',
                    ),
                  ),
                );
              }
            },
          ),
  );
}

class AuthScreen extends StatefulWidget {
  final AuthenticationRepository auth;
  final ValueChanged<Map<String, dynamic>> onSession;
  const AuthScreen({super.key, required this.auth, required this.onSession});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool register = false, busy = false, obscure = true;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final session = await widget.auth.authenticate(
        email: email.text,
        password: password.text,
        name: register ? name.text : null,
      );
      if (mounted) widget.onSession(session);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is AppFailure
              ? e.message
              : 'Impossible d’enregistrer la session. Réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AutofillGroup(
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.auto_stories_rounded,
                      size: 58,
                      color: ink,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'carnet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: ink,
                        letterSpacing: -2,
                      ),
                    ),
                    const Text(
                      'Vos découvertes vous suivent partout.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    Text(
                      register
                          ? 'Une nouvelle page'
                          : 'Heureux de vous retrouver',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      register
                          ? 'Créez votre compte pour commencer.'
                          : 'Connectez-vous à votre espace personnel.',
                    ),
                    const SizedBox(height: 24),
                    if (register) ...[
                      TextFormField(
                        controller: name,
                        enabled: !busy,
                        autofillHints: const [AutofillHints.name],
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nom',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                            (v?.trim().length ?? 0) < 2 || v!.trim().length > 80
                            ? 'Entre 2 et 80 caractères.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: email,
                      enabled: !busy,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (v) =>
                          RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Saisissez un email valide.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: password,
                      enabled: !busy,
                      obscureText: obscure,
                      autofillHints: [
                        register
                            ? AutofillHints.newPassword
                            : AutofillHints.password,
                      ],
                      onFieldSubmitted: (_) => submit(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: obscure
                              ? 'Afficher le mot de passe'
                              : 'Masquer le mot de passe',
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) => (v?.length ?? 0) < 8 || v!.length > 128
                          ? 'Entre 8 et 128 caractères.'
                          : null,
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          semanticsLabel: 'Erreur : $error',
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: busy ? null : submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(18),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              register ? 'Créer mon compte' : 'Se connecter',
                            ),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              register = !register;
                              error = null;
                              form.currentState?.reset();
                            }),
                      child: Text(
                        register
                            ? 'Déjà un compte ? Se connecter'
                            : 'Nouveau ici ? Créer un compte',
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.offline_pin_outlined, size: 18),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Vos lectures restent disponibles hors ligne.',
                          ),
                        ),
                      ],
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

class HomeScreen extends StatefulWidget {
  final String name;
  final ContentRepository repository;
  final Future<void> Function() onLogout;
  const HomeScreen({
    super.key,
    required this.name,
    required this.repository,
    required this.onLogout,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;
  bool leaving = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'carnet.',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 30),
      ),
      actions: [
        IconButton(
          tooltip: 'Se déconnecter',
          onPressed: leaving
              ? null
              : () async {
                  setState(() => leaving = true);
                  try {
                    await widget.onLogout();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('La déconnexion a échoué. Réessayez.'),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => leaving = false);
                  }
                },
          icon: const Icon(Icons.logout),
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: IndexedStack(
      index: index,
      children: [
        FeedScreen(
          category: 'articles',
          title: 'Explorer',
          subtitle: 'Bonjour ${widget.name}. Faites place aux idées.',
          icon: Icons.auto_stories_outlined,
          repository: widget.repository,
        ),
        FeedScreen(
          category: 'products',
          title: 'La sélection',
          subtitle: 'Des objets utiles pour le quotidien.',
          icon: Icons.shopping_bag_outlined,
          repository: widget.repository,
        ),
        FeedScreen(
          category: 'tasks',
          title: 'À faire',
          subtitle: 'Quelques idées pour une journée bien remplie.',
          icon: Icons.checklist_rounded,
          repository: widget.repository,
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (v) => setState(() => index = v),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore),
          label: 'Explorer',
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_bag_outlined),
          selectedIcon: Icon(Icons.shopping_bag),
          label: 'Catalogue',
        ),
        NavigationDestination(icon: Icon(Icons.checklist), label: 'Tâches'),
      ],
    ),
  );
}

class FeedScreen extends StatefulWidget {
  final String category, title, subtitle;
  final IconData icon;
  final ContentRepository repository;
  const FeedScreen({
    super.key,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.repository,
  });
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  Feed? feed;
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await widget.repository.fetch(widget.category);
      if (mounted) setState(() => feed = data);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is AppFailure
              ? e.message
              : 'Une erreur est survenue. Réessayez.';
          feed = null;
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: refresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          widget.title,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: ink,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.subtitle),
        const SizedBox(height: 24),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 44),
                  const SizedBox(height: 16),
                  Text(error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: refresh,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
        if (feed != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: feed!.cached
                  ? const Color(0xFFFFE8B6)
                  : const Color(0xFFDEEAE2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  feed!.cached ? Icons.cloud_off : Icons.cloud_done_outlined,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    feed!.cached
                        ? 'Hors ligne / serveur indisponible · données du ${stamp(feed!.savedAt)}'
                        : 'À jour · ${stamp(feed!.savedAt)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (feed!.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Aucun élément pour le moment.'),
            ),
          ...feed!.items.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                color: Colors.white,
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DetailScreen(
                        entry: entry,
                        icon: widget.icon,
                        cached: feed!.cached,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(widget.icon, color: ink),
                            const Spacer(),
                            const Icon(
                              Icons.arrow_outward,
                              size: 20,
                              color: ink,
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          entry.label,
                          style: const TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          entry.title,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          entry.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            height: 1.5,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
  String stamp(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class DetailScreen extends StatelessWidget {
  final Entry entry;
  final IconData icon;
  final bool cached;
  const DetailScreen({
    super.key,
    required this.entry,
    required this.icon,
    required this.cached,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Votre carnet')),
    body: ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFFDEEAE2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(icon, size: 70, color: ink),
        ),
        const SizedBox(height: 30),
        Text(
          entry.label,
          style: const TextStyle(
            color: ink,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          entry.title,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        const SizedBox(height: 22),
        Text(entry.body, style: const TextStyle(fontSize: 18, height: 1.7)),
        if (cached)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Text('Version enregistrée · consultation hors ligne'),
          ),
      ],
    ),
  );
}
