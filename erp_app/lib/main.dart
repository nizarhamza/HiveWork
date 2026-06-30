import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/forgot_password_page.dart';
import 'auth/login_page.dart';
import 'auth/signup_page.dart';
import 'auth/verify_email_page.dart';
import 'core/config/app_config.dart';
import 'core/supabase_secure_storage.dart';
import 'core/module/modules.dart';
import 'gallery/gallery_page.dart';
import 'modules/org/create_org_page.dart';
import 'modules/org/org_selector_page.dart';
import 'modules/settings/settings_page.dart';
import 'shell/app_shell.dart';
import 'theme/linear_tokens.dart';
import 'theme/theme_providers.dart';
import 'ui/organisms/command_palette.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  assert(
    AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty,
    'Supabase env vars missing — pass --dart-define-from-file=.env.json',
  );
  // Dep-1: Use platform-secure storage for the Supabase session token
  // (Keychain / Keystore / DPAPI on native, localStorage on web).
  await Supabase.initialize(
    url:            AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
    authOptions:    FlutterAuthClientOptions(
      localStorage:   SupabaseSecureStorage(),
      authFlowType:   AuthFlowType.pkce,
    ),
  );
  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
      options.tracesSampleRate = 0.2;
    },
    appRunner: () => runApp(const ProviderScope(child: ErpApp())),
  );
}

// ── Auth-state change notifier for GoRouter.refreshListenable ─────────────────

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(SupabaseClient client) {
    _session = client.auth.currentSession;
    _sub = client.auth.onAuthStateChange.listen(
      (event) {
        _session = event.session;
        _scheduleNotify();
      },
      // Stale PKCE verifier on web hot-restart — safe to ignore.
      onError: (_) {},
    );
  }

  StreamSubscription<AuthState>? _sub;
  Session? _session;
  bool _notifyPending = false;

  bool get isLoggedIn => _session != null;

  /// Supabase sets emailConfirmedAt once the user clicks the confirmation link.
  bool get isEmailConfirmed => _session?.user.emailConfirmedAt != null;

  // Coalesces rapid auth-state events (OAuth code exchange fires several in a
  // row) into a single GoRouter refresh, preventing the Navigator from
  // processing two route-changes in the same frame.
  void _scheduleNotify() {
    if (_notifyPending) return;
    _notifyPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyPending = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// ── App ────────────────────────────────────────────────────────────────────────

class ErpApp extends ConsumerStatefulWidget {
  const ErpApp({super.key});

  @override
  ConsumerState<ErpApp> createState() => _ErpAppState();
}

class _ErpAppState extends ConsumerState<ErpApp> {
  late final _RouterNotifier _notifier;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _notifier = _RouterNotifier(Supabase.instance.client);
    _router   = _buildRouter();
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  GoRouter _buildRouter() {
    final registry = ref.read(moduleRegistryProvider);

    return GoRouter(
      initialLocation: '/org',
      refreshListenable: _notifier,
      redirect: (context, state) {
        final loc    = state.matchedLocation;
        final isAuth = loc.startsWith('/auth/');

        if (!_notifier.isLoggedIn) {
          return isAuth ? null : '/auth/login';
        }
        if (!_notifier.isEmailConfirmed) {
          return loc == '/auth/verify-email' ? null : '/auth/verify-email';
        }
        // Signed in + confirmed → bounce away from auth pages to org check.
        if (isAuth) return '/org';
        return null;
      },
      routes: [
        // ── Auth (no app shell) ────────────────────────────────────────────
        GoRoute(
          path: '/auth/login',
          builder: (_, _) => const LoginPage(),
        ),
        GoRoute(
          path: '/auth/signup',
          builder: (_, _) => const SignupPage(),
        ),
        GoRoute(
          path: '/auth/forgot-password',
          builder: (_, _) => const ForgotPasswordPage(),
        ),
        GoRoute(
          path: '/auth/verify-email',
          builder: (_, _) => const VerifyEmailPage(),
        ),

        // ── Org selection (no app shell) ───────────────────────────────────
        GoRoute(
          path: '/org',
          pageBuilder: (_, state) => NoTransitionPage(
            key: state.pageKey,
            child: const OrgSelectorPage(),
          ),
        ),
        GoRoute(
          path: '/org/create',
          pageBuilder: (_, state) => NoTransitionPage(
            key: state.pageKey,
            child: const CreateOrgPage(),
          ),
        ),

        // ── Dev gallery (no app shell, debug only) ─────────────────────────
        if (kDebugMode)
          GoRoute(
            path: '/gallery',
            builder: (_, _) => const GalleryPage(),
          ),

        // ── Main ERP app (wrapped in AppShell sidebar) ─────────────────────
        ShellRoute(
          pageBuilder: (context, state, child) => NoTransitionPage(
            key: state.pageKey,
            child: AppShell(child: child),
          ),
          routes: [
            ...registry.allRoutes,
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsPage(),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent      = ref.watch(accentColorProvider);
    final themeMode   = ref.watch(themeModeProvider);
    final darkShade   = kDarkShadePresets[ref.watch(darkShadeProvider)];
    final lightShade  = kLightShadePresets[ref.watch(lightShadeProvider)];
    final fontFamily  = ref.watch(fontFamilyProvider);
    final fontScale   = kFontSizePresets[ref.watch(fontSizeProvider)].scale;
    return MaterialApp.router(
      title: 'ERP',
      debugShowCheckedModeBanner: false,
      theme: buildLinearLightTheme(
        accent:        accent,
        pageBg:        lightShade.pageBg,
        surfaceBase:   lightShade.surfaceBase,
        surfaceRaised: lightShade.surfaceRaised,
        fontFamily:    fontFamily,
        fontScale:     fontScale,
      ),
      darkTheme: buildLinearDarkTheme(
        accent:        accent,
        pageBg:        darkShade.pageBg,
        surfaceBase:   darkShade.surfaceBase,
        surfaceRaised: darkShade.surfaceRaised,
        fontFamily:    fontFamily,
        fontScale:     fontScale,
      ),
      themeMode:    themeMode,
      routerConfig: _router,
    );
  }
}

// ── Command palette seeds ──────────────────────────────────────────────────────

/// Seeds the global command registry with app-level navigation actions.
/// Call once from a widget that has access to GoRouter.
void seedCommandPalette(WidgetRef ref, BuildContext context) {
  ref.read(commandRegistryProvider.notifier).registerAll([
    CommandAction(
      id: 'nav.crm.contacts',
      label: 'Go to Contacts',
      icon: Icons.person_outline,
      group: 'CRM',
      onExecute: () => GoRouter.of(context).go('/crm/contacts'),
    ),
    CommandAction(
      id: 'nav.sales.pipeline',
      label: 'Go to Pipeline',
      icon: Icons.trending_up,
      group: 'Sales',
      onExecute: () => GoRouter.of(context).go('/sales/pipeline'),
    ),
    CommandAction(
      id: 'nav.invoicing',
      label: 'Go to Invoices',
      icon: Icons.receipt_long_outlined,
      group: 'Invoicing',
      onExecute: () => GoRouter.of(context).go('/invoicing/invoices'),
    ),
    CommandAction(
      id: 'nav.projects',
      label: 'Go to Projects',
      icon: Icons.folder_outlined,
      group: 'Projects',
      onExecute: () => GoRouter.of(context).go('/projects/all'),
    ),
    if (kDebugMode)
      CommandAction(
        id: 'nav.gallery',
        label: 'Component gallery',
        icon: Icons.palette_outlined,
        group: 'Dev',
        onExecute: () => GoRouter.of(context).go('/gallery'),
      ),
  ]);
}
