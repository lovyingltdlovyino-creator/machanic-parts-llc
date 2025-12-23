import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:carousel_slider/carousel_slider.dart' as carousel;
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'services/notification_service.dart';
import 'services/revenuecat_service.dart';
import 'widgets/footer.dart';
import 'pages/billing_page.dart';
import 'pages/admin_page.dart';
import 'pages/paywall_page.dart';
import 'pages/about_page.dart';
import 'pages/contact_page.dart';
import 'pages/privacy_page.dart';
import 'pages/terms_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/categories_page.dart';

const String kSupabaseUrlFromDefine = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const String kSupabaseAnonFromDefine = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
const String kRevenuecatIosKeyFromDefine = String.fromEnvironment('REVENUECAT_IOS_PUBLIC_SDK_KEY', defaultValue: '');
// A simple error screen to show fatal errors instead of a blank page (used on web too)
class ErrorScreen extends StatelessWidget {
  final String error;
  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Something went wrong', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(error, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable clean URLs without hash for web only (doesn't affect iOS/Android)
  if (kIsWeb) {
    usePathUrlStrategy();
  }

  // Capture all uncaught Flutter and zone errors, show a friendly screen on web
  FlutterError.onError = (FlutterErrorDetails details) {
    // Present the error to the console but do NOT replace the whole app.
    // This avoids full-screen error screens on minor widget errors (e.g., transient nulls).
    FlutterError.presentError(details);
  };
  // Also capture errors that escape FlutterError and zones (helps on web release)
  ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    // ignore: avoid_print
    print('[GlobalError] $error');
    // Keep the app running; let local widgets handle their own errors.
    return true;
  };
  // Replace red error boxes with a readable widget if a build fails
  ErrorWidget.builder = (FlutterErrorDetails details) {
    // ignore: avoid_print
    print('[BuildError] ${details.exceptionAsString()}');
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: Text('Error: ${details.exceptionAsString()}')),
    );
  };
  
  // Load environment variables (optional). Skip on Web to avoid fetching assets/.env
  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // ignore in production builds where .env may not exist
    }
    // ErrorScreen moved to top-level
  }
  
  // Read from --dart-define first; fallback to .env only if dotenv is initialized
  final supabaseUrl = (kSupabaseUrlFromDefine.isNotEmpty
          ? kSupabaseUrlFromDefine
          : (dotenv.isInitialized ? dotenv.env['SUPABASE_URL'] : null))
      ?.trim() ?? '';
  final supabaseAnonKey = (kSupabaseAnonFromDefine.isNotEmpty
          ? kSupabaseAnonFromDefine
          : (dotenv.isInitialized ? dotenv.env['SUPABASE_ANON_KEY'] : null))
      ?.trim() ?? '';
  // Minimal debug prints (no secrets)
  try {
    final host = Uri.tryParse(supabaseUrl)?.host ?? '';
    // ignore: avoid_print
    print('[Init] isWeb=$kIsWeb supabaseHost=$host anonLen=${supabaseAnonKey.length}');
  } catch (_) {}
  
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Missing configuration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                SizedBox(height: 12),
                Text(
                  'SUPABASE_URL or SUPABASE_ANON_KEY is not provided.\n' 
                  'On Netlify, set them in Site → Build & deploy → Environment and redeploy.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    return;
  }

  try {
    // ignore: avoid_print
    print('[Init] Starting Supabase.initialize');
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    // ignore: avoid_print
    print('[Init] Supabase initialized');
  } catch (e) {
    // ignore: avoid_print
    print('[Init] Supabase init failed: $e');
    runApp(ErrorScreen(error: 'Supabase init failed: $e'));
    return;
  }
  // Listen for password recovery deep links and navigate to reset page
  try {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        // ignore: avoid_print
        print('[Auth] Password recovery event detected');
        try {
          _router.go('/reset-password');
        } catch (e) {
          // ignore: avoid_print
          print('[Auth] Navigation to /reset-password failed: $e');
        }
      }
    });
  } catch (_) {}
  
  // Initialize notification service (skip during screenshot builds)
  const skipNotifications = String.fromEnvironment('SKIP_NOTIFICATIONS', defaultValue: 'false');
  if (skipNotifications != 'true') {
    // ignore: avoid_print
    print('[Init] Init NotificationService');
    await NotificationService().initialize();
    // ignore: avoid_print
    print('[Init] NotificationService initialized');
  } else {
    // ignore: avoid_print
    print('[Init] Skipping NotificationService for screenshot build');
  }

  // Initialize RevenueCat (strictly iOS only)
  // ignore: avoid_print
  print('[Init] Init RevenueCat');
  try {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final rcKey = (kRevenuecatIosKeyFromDefine.isNotEmpty
              ? kRevenuecatIosKeyFromDefine
              : (dotenv.isInitialized ? (dotenv.env['REVENUECAT_IOS_PUBLIC_SDK_KEY'] ?? '') : ''))
          .trim();
      if (rcKey.isEmpty) {
        // ignore: avoid_print
        print('[Init] RevenueCat key missing; skipping initialization');
      } else {
        await RevenueCatService.instance.initialize(rcKey);
        // ignore: avoid_print
        print('[Init] RevenueCat initialized (iOS)');
      }

      final currentUser = Supabase.instance.client.auth.currentUser;
      // ignore: avoid_print
      print('[Init] currentUser=${currentUser != null}');
      if (currentUser != null) {
        await RevenueCatService.instance.identify(currentUser.id);
        // ignore: avoid_print
        print('[Init] RevenueCat identify done');
      }

      // Set up auth listener
      Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
        final user = data.session?.user;
        if (user != null) {
          await RevenueCatService.instance.identify(user.id);
        } else {
          await RevenueCatService.instance.logout();
        }
      });
    } else {
      // ignore: avoid_print
      print('[Init] RevenueCat skipped (not iOS or web)');
    }

    // ignore: avoid_print
    print('[Init] Before runApp');
  } catch (e) {
    // ignore: avoid_print
    print('[Boot] post-init error: $e');
    runApp(ErrorScreen(error: 'Boot error: $e'));
    return;
  }
  runZonedGuarded(() {
    try {
      // ignore: avoid_print
      print('[Init] runApp start');
      runApp(const MechanicPartApp());
    } catch (e) {
      // ignore: avoid_print
      print('runApp sync error: $e');
      // Do not replace the app; keep running.
    }
  }, (error, stack) {
    // ignore: avoid_print
    print('Uncaught zone error: $error');
    // Keep the app running to avoid full-screen crash on transient errors.
  });
}

// Branding
class AppColors {
  static const primary = Color(0xFF0052CC); // Deep Blue
  static const secondary = Color(0xFFD72638); // Crimson
  static const neutralDark = Color(0xFF2C2C2C);
  static const neutralLight = Color(0xFFF5F5F5);
  static const success = Color(0xFF00897B); // Teal
}

class MechanicPartApp extends StatelessWidget {
  const MechanicPartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mechanic Part LLC',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.neutralLight,
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.neutralDark,
        ),
      ),
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => kIsWeb ? const WebHomeShell() : const HomeShell(),
    ),
    GoRoute(
      path: '/my-products',
      builder: (context, state) => kIsWeb ? const WebHomeShell(initialIndex: 1) : const HomeShell(initialIndex: 1),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthPage(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordPage(),
    ),
    GoRoute(
      path: '/complete-profile',
      builder: (context, state) => const CompleteProfilePage(),
    ),
    GoRoute(
      path: '/billing',
      builder: (context, state) => const _SellerOnly(child: BillingPage()),
    ),
    GoRoute(
      path: '/paywall',
      builder: (context, state) => const PaywallPage(),
    ),
    GoRoute(
      path: '/categories',
      builder: (context, state) => const CategoriesPage(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminPage(),
    ),
    GoRoute(
      path: '/about',
      builder: (context, state) => const AboutPage(),
    ),
    GoRoute(
      path: '/contact',
      builder: (context, state) => const ContactPage(),
    ),
    GoRoute(
      path: '/privacy',
      builder: (context, state) => const PrivacyPage(),
    ),
    GoRoute(
      path: '/terms',
      builder: (context, state) => const TermsPage(),
    ),
  ],
);

// Simple route guard widget: allows only sellers to view the child, otherwise redirects guidance
class _SellerOnly extends StatefulWidget {
  final Widget child;
  const _SellerOnly({required this.child, super.key});

  @override
  State<_SellerOnly> createState() => _SellerOnlyState();
}

class _SellerOnlyState extends State<_SellerOnly> {
  bool _loading = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) context.go('/auth');
      return;
    }
    try {
      final prof = await supabase
          .from('profiles')
          .select('user_type')
          .eq('id', user.id)
          .maybeSingle();
      final type = (prof != null ? prof['user_type'] : null) ?? (user.userMetadata?['user_type'] ?? 'buyer');
      if (mounted) setState(() { _allowed = type == 'seller'; _loading = false; });
    } catch (_) {
      final type = user.userMetadata?['user_type'] ?? 'buyer';
      if (mounted) setState(() { _allowed = type == 'seller'; _loading = false; });
    }
  }

  // Note: _SellerOnlyState is a simple route-guard. Plan/usage and listing actions
  // are implemented in seller pages (e.g., MyProductsPage), not here.

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_allowed) return widget.child;
    return Scaffold(
      appBar: AppBar(title: const Text('Billing')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 40, color: Colors.orange),
            const SizedBox(height: 12),
            const Text('Billing is available to sellers only.', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                final homeShell = context.findAncestorStateOfType<_HomeShellState>();
                if (homeShell != null) {
                  homeShell.switchToTab(3); // Profile tab
                } else {
                  context.go('/home');
                }
              },
              icon: const Icon(Icons.person_outline),
              label: const Text('Go to Profile'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            )
          ],
        ),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A), // Deep blue
              Color(0xFF3B82F6), // Medium blue
              Color(0xFF60A5FA), // Light blue
              Color(0xFF93C5FD), // Very light blue
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo container with subtle shadow and glow effect
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo_new.png',
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to old logo if new one doesn't exist yet
                      return Image.asset(
                        'assets/images/logo.png',
                        height: 120,
                        fit: BoxFit.contain,
                      );
                    },
                  ),
                ).animate().fadeIn(duration: 800.ms).scale(
                  begin: const Offset(0.8, 0.8), 
                  end: const Offset(1.0, 1.0), 
                  curve: Curves.elasticOut,
                ),
                
                const SizedBox(height: 32),
                
                // App title with elegant styling
                Text(
                  'MECHANIC PART LLC',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms, duration: 600.ms).slideY(
                  begin: 0.3, 
                  end: 0, 
                  curve: Curves.easeOut,
                ),
                
                const SizedBox(height: 12),
                
                // Subtitle with refined styling
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    'Find the parts you need',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 600.ms).slideY(
                  begin: 0.2, 
                  end: 0, 
                  curve: Curves.easeOut,
                ),
                
                const SizedBox(height: 40),
                
                // Loading indicator with custom styling
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 1000.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  final int initialIndex;
  
  const HomeShell({super.key, this.initialIndex = 0});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _currentIndex;
  bool _isSeller = false;
  bool _loadedUserType = false;
  int _unreadCount = 0;
  final Map<dynamic, RealtimeChannel> _messageChannels = {};

  Future<void> _loadUserType() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _isSeller = false;
          _loadedUserType = true;
        });
        return;
      }
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('user_type')
          .eq('id', user.id)
          .maybeSingle();
      final type = (profile != null && profile['user_type'] != null)
        ? profile['user_type']
        : (user.userMetadata?['user_type'] ?? 'buyer');
      setState(() {
        _isSeller = type == 'seller';
        _loadedUserType = true;
        if (!_isSeller && _currentIndex == 1) {
          _currentIndex = 0;
        }
      });
    } catch (_) {
      // Fallback to auth metadata if profiles query/column is unavailable
      final metaType = Supabase.instance.client.auth.currentUser?.userMetadata?['user_type'] ?? 'buyer';
      setState(() {
        _isSeller = metaType == 'seller';
        _loadedUserType = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadUserType();
    _loadUnreadCountAndSubscribe();
  }

  void switchToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _loadUnreadCountAndSubscribe() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _unreadCount = 0;
      });
      _disposeMessageChannels();
      return;
    }

    try {
      final resp = await Supabase.instance.client
          .rpc('get_conversations_with_details', params: {'user_uuid': user.id});
      final list = List<Map<String, dynamic>>.from(resp ?? []);
      int total = 0;
      final ids = <dynamic>{};
      for (final c in list) {
        final uc = c['unread_count'];
        if (uc is int) total += uc; else if (uc is String) total += int.tryParse(uc) ?? 0;
        final cid = c['conversation_id'] ?? c['id'];
        if (cid != null) ids.add(cid);
      }
      if (mounted) {
        setState(() {
          _unreadCount = total;
        });
      }
      _setupMessageSubscriptions(ids);
    } catch (_) {
      if (mounted) {
        setState(() {
          _unreadCount = 0;
        });
      }
    }
  }

  void _setupMessageSubscriptions(Set<dynamic> conversationIds) {
    _disposeMessageChannels();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    for (final cid in conversationIds) {
      final channel = Supabase.instance.client
          .channel('messages_$cid')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: cid,
            ),
            callback: (payload) {
              final rec = payload.newRecord;
              if (rec == null) return;
              final sender = rec['sender_id'];
              if (sender == user.id) return;
              if (mounted) {
                setState(() {
                  _unreadCount += 1;
                });
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: cid,
            ),
            callback: (payload) {
              final oldR = payload.oldRecord;
              final newR = payload.newRecord;
              if (newR == null) return;
              final user = Supabase.instance.client.auth.currentUser;
              if (user == null) return;
              if ((oldR?['read_at'] == null) && (newR['read_at'] != null) && newR['sender_id'] != user.id) {
                if (mounted) {
                  setState(() {
                    _unreadCount = (_unreadCount - 1).clamp(0, 1 << 31);
                  });
                }
              }
            },
          )
          .subscribe();
      _messageChannels[cid] = channel;
    }
  }

  void _disposeMessageChannels() {
    for (final ch in _messageChannels.values) {
      ch.unsubscribe();
    }
    _messageChannels.clear();
  }

  Widget _buildBadge(int count) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  void dispose() {
    _disposeMessageChannels();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedUserType) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> pages = _isSeller
        ? [
            const BrowsePage(),
            const MyProductsPage(),
            const ChatPage(),
            const ProfilePage(),
          ]
        : [
            const BrowsePage(),
            const ChatPage(),
            const ProfilePage(),
          ];

    final List<BottomNavigationBarItem> items = _isSeller
        ? [
            const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Browse'),
            const BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'My Products'),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat),
                  if (_unreadCount > 0)
                    Positioned(right: -6, top: -2, child: _buildBadge(_unreadCount)),
                ],
              ),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ]
        : [
            const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Browse'),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat),
                  if (_unreadCount > 0)
                    Positioned(right: -6, top: -2, child: _buildBadge(_unreadCount)),
                ],
              ),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ];

    final safeIndex = _currentIndex.clamp(0, pages.length - 1);

    return Scaffold(
      body: pages[safeIndex],
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: safeIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              selectedItemColor: AppColors.primary,
              unselectedItemColor: Colors.grey,
              items: items,
            ),
            const Footer(),
          ],
        ),
      ),
    );
  }
}

// ===== Web: Professional Shell =====
class WebHomeShell extends StatefulWidget {
  final int initialIndex;
  const WebHomeShell({super.key, this.initialIndex = 0});

  @override
  State<WebHomeShell> createState() => _WebHomeShellState();
}

class _WebHomeShellState extends State<WebHomeShell> {
  late int _currentIndex;
  bool _isSeller = false;
  bool _isAdmin = false;
  bool _loadedUserType = false;
  final _searchController = TextEditingController();
  final GlobalKey<_WebBrowsePageState> _browseKey = GlobalKey<_WebBrowsePageState>();
  int _unreadCount = 0;
  final Map<dynamic, RealtimeChannel> _messageChannels = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadUserType();
    _loadUnreadCountAndSubscribe();
  }

  Future<void> _loadUserType() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _isSeller = false;
          _isAdmin = false;
          _loadedUserType = true;
        });
        return;
      }
      dynamic profile = await Supabase.instance.client
          .from('profiles')
          .select('user_type, role, is_admin')
          .eq('id', user.id)
          .maybeSingle();
      if (profile == null) {
        // Fallback for schemas that use 'uid' instead of 'id'
        profile = await Supabase.instance.client
            .from('profiles')
            .select('user_type, role, is_admin')
            .eq('uid', user.id)
            .maybeSingle();
      }
      final type = (profile != null && profile['user_type'] != null)
          ? profile['user_type']
          : (user.userMetadata?['user_type'] ?? 'buyer');
      final isAdminFlag = profile != null ? profile['is_admin'] : null; // strict: UI shows Admin only if true
      setState(() {
        _isSeller = type == 'seller';
        _isAdmin = isAdminFlag == true;
        _loadedUserType = true;
        if (!_isSeller && _currentIndex == 1) {
          _currentIndex = 0;
        }
      });
    } catch (_) {
      // Fallback to auth metadata if profiles query/column is unavailable
      final metaType = Supabase.instance.client.auth.currentUser?.userMetadata?['user_type'] ?? 'buyer';
      setState(() {
        _isSeller = metaType == 'seller';
        _isAdmin = false;
        _loadedUserType = true;
      });
    }
  }

  void _triggerSearch(String value) {
    setState(() => _currentIndex = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _browseKey.currentState?.searchByKeyword(value.trim());
    });
  }

  Future<void> _loadUnreadCountAndSubscribe() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _unreadCount = 0);
      _disposeMessageChannels();
      return;
    }
    try {
      final resp = await Supabase.instance.client
          .rpc('get_conversations_with_details', params: {'user_uuid': user.id});
      final list = List<Map<String, dynamic>>.from(resp ?? []);
      int total = 0;
      final ids = <dynamic>{};
      for (final c in list) {
        final uc = c['unread_count'];
        if (uc is int) total += uc; else if (uc is String) total += int.tryParse(uc) ?? 0;
        final cid = c['conversation_id'] ?? c['id'];
        if (cid != null) ids.add(cid);
      }
      if (mounted) setState(() => _unreadCount = total);
      _setupMessageSubscriptions(ids);
    } catch (_) {
      if (mounted) setState(() => _unreadCount = 0);
    }
  }

  void _setupMessageSubscriptions(Set<dynamic> conversationIds) {
    _disposeMessageChannels();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    for (final cid in conversationIds) {
      final channel = Supabase.instance.client
          .channel('messages_$cid')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: cid,
            ),
            callback: (payload) {
              final rec = payload.newRecord;
              if (rec == null) return;
              if (rec['sender_id'] == user.id) return;
              if (mounted) setState(() => _unreadCount += 1);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: cid,
            ),
            callback: (payload) {
              final oldR = payload.oldRecord;
              final newR = payload.newRecord;
              if (newR == null) return;
              final wasUnread = oldR?['read_at'] == null;
              final nowRead = newR['read_at'] != null;
              if (wasUnread && nowRead && newR['sender_id'] != user.id) {
                if (mounted) setState(() => _unreadCount = (_unreadCount - 1).clamp(0, 1 << 31));
              }
            },
          )
          .subscribe();
      _messageChannels[cid] = channel;
    }
  }

  void _disposeMessageChannels() {
    for (final ch in _messageChannels.values) {
      ch.unsubscribe();
    }
    _messageChannels.clear();
  }

  Widget _buildBadge(int count) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  void dispose() {
    _disposeMessageChannels();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedUserType) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 900;

    final List<Widget> pages = _isSeller
        ? [
            WebBrowsePage(key: _browseKey),
            const MyProductsPage(),
            const ChatPage(),
            const ProfilePage(),
          ]
        : [
            WebBrowsePage(key: _browseKey),
            const ChatPage(),
            const ProfilePage(),
          ];

    final safeIndex = _currentIndex.clamp(0, pages.length - 1);

    if (isNarrow) {
      // Mobile-friendly web layout: bottom navigation + footer
      final items = _isSeller
          ? const [
              BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Browse'),
              BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'My Products'),
              BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ]
          : const [
              BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Browse'),
              BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ];

      return Scaffold(
        appBar: AppBar(
          title: const Text('Mechanic Part LLC'),
          backgroundColor: Colors.white,
          elevation: 1,
          foregroundColor: AppColors.neutralDark,
        ),
        body: pages[safeIndex],
        bottomNavigationBar: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BottomNavigationBar(
                currentIndex: safeIndex,
                onTap: (i) => setState(() => _currentIndex = i),
                items: items,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: Colors.grey,
                showUnselectedLabels: true,
              ),
              const Footer(),
            ],
          ),
        ),
      );
    }

    // Wide web layout: left rail + footer
    final railDestinations = _isSeller
        ? [
            const NavigationRailDestination(icon: Icon(Icons.search), label: Text('Browse')),
            const NavigationRailDestination(icon: Icon(Icons.inventory_2), label: Text('My Products')),
            NavigationRailDestination(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat),
                  if (_unreadCount > 0)
                    Positioned(right: -6, top: -2, child: _buildBadge(_unreadCount)),
                ],
              ),
              label: const Text('Chat'),
            ),
            const NavigationRailDestination(icon: Icon(Icons.person), label: Text('Profile')),
          ]
        : [
            const NavigationRailDestination(icon: Icon(Icons.search), label: Text('Browse')),
            NavigationRailDestination(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat),
                  if (_unreadCount > 0)
                    Positioned(right: -6, top: -2, child: _buildBadge(_unreadCount)),
                ],
              ),
              label: const Text('Chat'),
            ),
            const NavigationRailDestination(icon: Icon(Icons.person), label: Text('Profile')),
          ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        toolbarHeight: 72,
        titleSpacing: 0,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              children: [
                // Brand
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.build_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Mechanic Part LLC',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutralDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Search (stretches)
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: _triggerSearch,
                      decoration: InputDecoration(
                        hintText: 'Search parts, vehicles, sellers... ',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Actions
                IconButton(
                  tooltip: 'Notifications',
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_outlined),
                      if (_unreadCount > 0)
                        Positioned(right: -4, top: -4, child: _buildBadge(_unreadCount)),
                    ],
                  ),
                  onPressed: () {
                    final user = Supabase.instance.client.auth.currentUser;
                    if (user == null) {
                      context.go('/auth');
                    } else {
                      setState(() => _currentIndex = _isSeller ? 2 : 1); // Go to Chat
                    }
                  },
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final user = Supabase.instance.client.auth.currentUser;
                    return Row(
                      children: [
                        if (_isAdmin)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: OutlinedButton.icon(
                              onPressed: () => context.go('/admin'),
                              icon: const Icon(Icons.admin_panel_settings_outlined),
                              label: const Text('Admin'),
                            ),
                          ),
                        if (_isSeller)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final user = Supabase.instance.client.auth.currentUser;
                                if (user == null) {
                                  context.go('/auth');
                                } else {
                                  context.go('/billing');
                                }
                              },
                              icon: const Icon(Icons.credit_card_outlined),
                              label: const Text('Billing'),
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: () {
                            final user = Supabase.instance.client.auth.currentUser;
                            if (user == null) {
                              context.go('/auth');
                            } else {
                              setState(() => _currentIndex = _isSeller ? 3 : 2);
                            }
                          },
                          icon: const Icon(Icons.person_outline),
                          label: Text(Supabase.instance.client.auth.currentUser == null ? 'Sign In' : 'Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: safeIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            labelType: NavigationRailLabelType.all,
            destinations: railDestinations,
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: pages[safeIndex],
          ),
        ],
      ),
      bottomNavigationBar: const Footer(),
    );
  }
}

// ===== Web: Browse Page =====
class WebBrowsePage extends StatefulWidget {
  const WebBrowsePage({super.key});

  @override
  State<WebBrowsePage> createState() => _WebBrowsePageState();
}

class _WebBrowsePageState extends State<WebBrowsePage> {
  final TextEditingController _inlineSearch = TextEditingController();
  List<Map<String, dynamic>> _listings = [];
  List<Map<String, dynamic>> _featuredListings = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadListings();
    _loadFeaturedListings();
  }

  Future<void> _loadFeaturedListings() async {
    try {
      // Step 1: fetch ranked IDs from the view
      final ranked = await Supabase.instance.client
          .from('listings_ranked')
          .select('id')
          .eq('is_featured', true)
          .order('score', ascending: false)
          .limit(12);

      final ids = List<Map<String, dynamic>>.from(ranked ?? [])
          .map((e) => e['id'])
          .where((e) => e != null)
          .toList();

      if (ids.isEmpty) {
        setState(() => _featuredListings = []);
        return;
      }

      // Step 2: load full rows with photos and reorder by ranked ids
      final details = await Supabase.instance.client
          .from('listings')
          .select('''
            *,
            listing_photos(storage_path, sort_order)
          ''')
          .inFilter('id', ids);

      var listings = List<Map<String, dynamic>>.from(details ?? []);
      final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
      listings.sort((a, b) => (order[a['id']] ?? 1<<30).compareTo(order[b['id']] ?? 1<<30));

      await _loadProfilesForListings(listings);

      // Track impressions for the featured set
      for (final it in listings) {
        final id = it['id'];
        if (id != null) {
          try {
            await Supabase.instance.client
                .rpc('track_event', params: {'_listing_id': id, '_type': 'impression'});
          } catch (_) {}
        }
      }

      setState(() {
        _featuredListings = listings;
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadListings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Step 1: ranked IDs
      final ranked = await Supabase.instance.client
          .from('listings_ranked')
          .select('id')
          .order('score', ascending: false)
          .limit(30);

      final ids = List<Map<String, dynamic>>.from(ranked ?? [])
          .map((e) => e['id'])
          .where((e) => e != null)
          .toList();

      // Step 2: full listings with photos
      List<Map<String, dynamic>> listings = [];
      if (ids.isNotEmpty) {
        final details = await Supabase.instance.client
            .from('listings')
            .select('''
              *,
              listing_photos(storage_path, sort_order)
            ''')
            .inFilter('id', ids);
        listings = List<Map<String, dynamic>>.from(details ?? []);
        final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
        listings.sort((a, b) => (order[a['id']] ?? 1<<30).compareTo(order[b['id']] ?? 1<<30));
      }
      
      // Load profile data for all listings
      await _loadProfilesForListings(listings);

      // Track impressions for loaded results
      for (final it in listings) {
        final id = it['id'];
        if (id != null) {
          try {
            await Supabase.instance.client
                .rpc('track_event', params: {'_listing_id': id, '_type': 'impression'});
          } catch (_) {}
        }
      }
      
      setState(() {
        _listings = listings;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load listings: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadProfilesForListings(List<Map<String, dynamic>> listings) async {
    final ownerIds = listings
        .map((listing) => listing['owner_id']?.toString())
        .where((id) => id != null && !ListingCard._profileCache.containsKey(id))
        .cast<String>()
        .toSet();
    
    if (ownerIds.isEmpty) return;
    
    try {
      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id, city, state, business_name, contact_person, rating')
          .inFilter('id', ownerIds.toList());
      
      for (final profile in profiles) {
        ListingCard._profileCache[profile['id']] = profile;
      }
    } catch (e) {
      // If profile loading fails, set null for these IDs so we don't keep trying
      for (final id in ownerIds) {
        ListingCard._profileCache[id] = null;
      }
    }
  }

  Future<void> performAdvancedSearch(Map<String, dynamic> filters) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      dynamic response;

      // If ZIP provided, use RPC to compute distances
      if (filters.containsKey('zip') && filters['zip'] != null && filters['zip'].toString().isNotEmpty) {
        response = await Supabase.instance.client.rpc('search_listings_by_zip', params: {
          'search_zip': filters['zip'],
          'radius_miles': filters['radius'] ?? 25,
        });

        var results = List<Map<String, dynamic>>.from(response ?? []);

        // Normalize/round distance and apply additional filters client-side
        for (final item in results) {
          if (item['distance'] == null && item['distance_miles'] != null) {
            final d = item['distance_miles'];
            if (d is num) item['distance'] = d.toDouble();
          }
        }

        // Apply category/condition filters client-side (RPC may not support directly)
        if (filters['type'] != null && filters['type'].toString().isNotEmpty) {
          results = results.where((e) => (e['type'] ?? '').toString().toLowerCase() == filters['type'].toString().toLowerCase()).toList();
        }
        if (filters['category'] != null && filters['category'].toString().isNotEmpty && filters['category'] != 'all') {
          results = results.where((e) => (e['category'] ?? '').toString().toLowerCase() == filters['category'].toString().toLowerCase()).toList();
        }
        if (filters['condition'] != null && filters['condition'].toString().isNotEmpty && filters['condition'] != 'all') {
          results = results.where((e) => (e['condition'] ?? '').toString().toLowerCase() == filters['condition'].toString().toLowerCase()).toList();
        }
        if (filters['part_name'] != null && filters['part_name'].toString().isNotEmpty) {
          final q = filters['part_name'].toString().toLowerCase();
          results = results.where((e) {
            final t = (e['title'] ?? '').toString().toLowerCase();
            final d = (e['description'] ?? '').toString().toLowerCase();
            return t.contains(q) || d.contains(q);
          }).toList();
        }

        // Attach listing_photos for these listing IDs (RPC usually doesn't include nested)
        final ids = results.map((e) => e['id']).where((id) => id != null).toList();
        if (ids.isNotEmpty) {
          final photosResp = await Supabase.instance.client
              .from('listing_photos')
              .select('listing_id, storage_path, sort_order')
              .inFilter('listing_id', ids)
              .order('sort_order');
          final photos = List<Map<String, dynamic>>.from(photosResp ?? []);
          final Map<dynamic, List<Map<String, dynamic>>> byListing = {};
          for (final p in photos) {
            final lid = p['listing_id'];
            byListing.putIfAbsent(lid, () => []);
            byListing[lid]!.add({'storage_path': p['storage_path'], 'sort_order': p['sort_order']});
          }
          for (final item in results) {
            item['listing_photos'] = byListing[item['id']] ?? [];
          }
        }

        setState(() {
          _listings = results;
          _loading = false;
        });
      } else {
        // Non-location search (ranked): query IDs from listings_ranked with filters, then hydrate with photos
        final supabase = Supabase.instance.client;
        var ranked = supabase
            .from('listings_ranked')
            .select('id');

        if (filters['type'] != null && filters['type'] != 'all') {
          ranked = ranked.eq('type', filters['type']);
        }

        if (filters['category'] != null && filters['category'] != 'all') {
          ranked = ranked.eq('category', filters['category']);
        }
        if (filters['condition'] != null && filters['condition'] != 'all') {
          ranked = ranked.eq('condition', filters['condition']);
        }
        if (filters['part_name'] != null && filters['part_name'].toString().isNotEmpty) {
          final q = filters['part_name'];
          ranked = ranked.or('title.ilike.%$q%,description.ilike.%$q%');
        }
        if (filters['make'] != null && filters['make'].toString().isNotEmpty) {
          ranked = ranked.ilike('make', '%${filters['make']}%');
        }
        if (filters['model'] != null && filters['model'].toString().isNotEmpty) {
          ranked = ranked.ilike('model', '%${filters['model']}%');
        }
        if (filters['year'] != null) {
          ranked = ranked.eq('year', filters['year']);
        }

        final rankedIdsResp = await ranked.order('score', ascending: false).limit(60);
        final ids = List<Map<String, dynamic>>.from(rankedIdsResp ?? [])
            .map((e) => e['id'])
            .where((e) => e != null)
            .toList();

        List<Map<String, dynamic>> listings = [];
        if (ids.isNotEmpty) {
          final details = await supabase
              .from('listings')
              .select('''
                *,
                listing_photos(storage_path, sort_order)
              ''')
              .inFilter('id', ids);
          listings = List<Map<String, dynamic>>.from(details ?? []);
          final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
          listings.sort((a, b) => (order[a['id']] ?? 1<<30).compareTo(order[b['id']] ?? 1<<30));
          await _loadProfilesForListings(listings);
          // Impressions
          for (final it in listings) {
            final id = it['id'];
            if (id != null) {
              try { await supabase
                  .rpc('track_event', params: {'_listing_id': id, '_type': 'impression'}); } catch (_) {}
            }
          }
        }

        setState(() {
          _listings = listings;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Search failed: ${e.toString()}';
        _loading = false;
      });
    }
  }

  // Public so the shell can invoke it
  Future<void> searchByKeyword(String query) async {
    if (query.isEmpty) {
      return _loadListings();
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Ranked search via view
      final ranked = await Supabase.instance.client
          .from('listings_ranked')
          .select('id')
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('score', ascending: false)
          .limit(30);

      final ids = List<Map<String, dynamic>>.from(ranked ?? [])
          .map((e) => e['id'])
          .where((e) => e != null)
          .toList();

      List<Map<String, dynamic>> listings = [];
      if (ids.isNotEmpty) {
        final details = await Supabase.instance.client
            .from('listings')
            .select('''
              *,
              listing_photos(storage_path, sort_order)
            ''')
            .inFilter('id', ids);
        listings = List<Map<String, dynamic>>.from(details ?? []);
        final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
        listings.sort((a, b) => (order[a['id']] ?? 1<<30).compareTo(order[b['id']] ?? 1<<30));
        await _loadProfilesForListings(listings);
        // Track impressions
        for (final it in listings) {
          final id = it['id'];
          if (id != null) {
            try { await Supabase.instance.client
                .rpc('track_event', params: {'_listing_id': id, '_type': 'impression'}); } catch (_) {}
          }
        }
      }
      setState(() { _listings = listings; _loading = false; });
    } catch (e) {
      setState(() {
        _error = 'Search failed: $e';
        _loading = false;
      });
    }
  }

  int _columnsForWidth(double w) {
    if (w >= 1280) return 4;
    if (w >= 992) return 3;
    if (w >= 640) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero header
          Container(
            height: 240,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Find Quality Auto Parts Faster',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Browse thousands of listings from verified sellers across the country.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _inlineSearch,
                          onSubmitted: searchByKeyword,
                          decoration: InputDecoration(
                            hintText: 'Search by part name, vehicle or keyword',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Advanced Filters (Category, Condition, ZIP & Radius)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SearchPanel(onSearch: performAdvancedSearch),
              ),
            ),
          ),

          // Featured
          if (_featuredListings.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Featured Listings',
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = _columnsForWidth(constraints.maxWidth);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _featuredListings.length.clamp(0, 8),
                  itemBuilder: (context, index) => ListingCard(listing: _featuredListings[index]),
                );
              },
            ),
          ],

          // All listings
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Latest Listings',
                  style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                if (_loading) const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final cols = _columnsForWidth(constraints.maxWidth);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _listings.length,
                  itemBuilder: (context, index) => ListingCard(listing: _listings[index]),
                );
              },
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _listings = [];
  List<Map<String, dynamic>> _featuredListings = [];
  bool _loading = false;
  String? _error;
  String? _lastSearchZip;
  double? _lastSearchRadius;
  int _currentCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadListings();
    _loadFeaturedListings();
  }

  Future<void> _loadFeaturedListings() async {
    try {
      // Ranked IDs from the view, restrict to featured
      final ranked = await Supabase.instance.client
          .from('listings_ranked')
          .select('id')
          .eq('is_featured', true)
          .order('score', ascending: false)
          .limit(5);

      final ids = List<Map<String, dynamic>>.from(ranked ?? [])
          .map((e) => e['id'])
          .where((e) => e != null)
          .toList();

      if (ids.isEmpty) {
        setState(() => _featuredListings = []);
        return;
      }

      final details = await Supabase.instance.client
          .from('listings')
          .select('''
            *,
            listing_photos(storage_path, sort_order)
          ''')
          .inFilter('id', ids);

      var listings = List<Map<String, dynamic>>.from(details ?? []);
      final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
      listings.sort((a, b) => (order[a['id']] ?? 1<<30).compareTo(order[b['id']] ?? 1<<30));

      await _loadProfilesForListings(listings);

      // Track impressions
      for (final it in listings) {
        final id = it['id'];
        if (id != null) {
          try {
            await Supabase.instance.client
                .rpc('track_event', params: {'_listing_id': id, '_type': 'impression'});
          } catch (_) {}
        }
      }

      setState(() { _featuredListings = listings; });
    } catch (e) {
      print('Failed to load featured listings: $e');
    }
  }

  Future<void> _loadListings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ranked = await Supabase.instance.client
          .from('listings_ranked')
          .select('id')
          .order('score', ascending: false)
          .limit(20);

      final ids = List<Map<String, dynamic>>.from(ranked ?? [])
          .map((e) => e['id'])
          .where((e) => e != null)
          .toList();

      List<Map<String, dynamic>> listings = [];
      if (ids.isNotEmpty) {
        final details = await Supabase.instance.client
            .from('listings')
            .select('''
              *,
              listing_photos(storage_path, sort_order)
            ''')
            .inFilter('id', ids);
        listings = List<Map<String, dynamic>>.from(details ?? []);
        final order = {for (var i = 0; i < ids.length; i++) ids[i]: i};
        listings.sort((a, b) => (order[a['id']] ?? 1<<30).compareTo(order[b['id']] ?? 1<<30));
      }

      await _loadProfilesForListings(listings);

      // Impressions
      for (final it in listings) {
        final id = it['id'];
        if (id != null) {
          try { await Supabase.instance.client
              .rpc('track_event', params: {'_listing_id': id, '_type': 'impression'}); } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _listings = listings;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load listings: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadProfilesForListings(List<Map<String, dynamic>> listings) async {
    final ownerIds = listings
        .map((listing) => listing['owner_id']?.toString())
        .where((id) => id != null && !ListingCard._profileCache.containsKey(id))
        .cast<String>()
        .toSet();
    
    if (ownerIds.isEmpty) return;
    
    try {
      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id, city, state, business_name, contact_person, rating')
          .inFilter('id', ownerIds.toList());
      
      for (final profile in profiles) {
        ListingCard._profileCache[profile['id']] = profile;
      }
    } catch (e) {
      // If profile loading fails, set null for these IDs so we don't keep trying
      for (final id in ownerIds) {
        ListingCard._profileCache[id] = null;
      }
    }
  }

  Future<void> performAdvancedSearch(Map<String, dynamic> filters) async {
    setState(() {
      _loading = true;
      _error = null;
      _lastSearchZip = filters['zip'];
      _lastSearchRadius = filters['radius'];
    });

    try {
      dynamic response;

      if (filters.containsKey('zip') && filters['zip'] != null && filters['zip'].toString().isNotEmpty) {
        // Location-based search using RPC
        response = await Supabase.instance.client.rpc('search_listings_by_zip', params: {
          'search_zip': filters['zip'],
          'radius_miles': filters['radius'] ?? 25,
        });
      } else {
        // General search using direct query (include nested photos)
        var query = Supabase.instance.client
            .from('listings')
            .select('''
              *,
              listing_photos(storage_path, sort_order)
            ''')
            .eq('status', 'active');

        // Apply filters
        if (filters['part_name'] != null && filters['part_name'].toString().isNotEmpty) {
          query = query.or('title.ilike.%${filters['part_name']}%,description.ilike.%${filters['part_name']}%');
        }
        if (filters['type'] != null && filters['type'].toString().isNotEmpty) {
          query = query.eq('type', filters['type']);
        }
        if (filters['category'] != null && filters['category'].toString().isNotEmpty) {
          query = query.eq('category', filters['category']);
        }
        if (filters['condition'] != null && filters['condition'].toString().isNotEmpty && filters['condition'] != 'all') {
          query = query.eq('condition', filters['condition']);
        }
        if (filters['make'] != null && filters['make'].toString().isNotEmpty) {
          query = query.ilike('make', '%${filters['make']}%');
        }
        if (filters['model'] != null && filters['model'].toString().isNotEmpty) {
          query = query.ilike('model', '%${filters['model']}%');
        }
        if (filters['year'] != null) {
          query = query.eq('year', filters['year']);
        }

        final resultsResp = await query.order('created_at', ascending: false);
        final results = List<Map<String, dynamic>>.from(resultsResp ?? []);

        // Track impressions
        for (final it in results) {
          final id = it['id'];
          if (id != null) {
            try {
              await Supabase.instance.client
                  .rpc('track_event', params: {'_listing_id': id, '_type': 'impression'});
            } catch (_) {}
          }
        }

        if (mounted) {
          setState(() {
            _listings = results;
            _loading = false;
          });
        }
        return;
      }

      // ZIP path: apply client-side filters and attach photos
      var loaded = List<Map<String, dynamic>>.from(response ?? []);

      // Normalize distance if present
      for (final item in loaded) {
        if (item['distance'] == null && item['distance_miles'] != null) {
          final d = item['distance_miles'];
          if (d is num) item['distance'] = d.toDouble();
        }
      }

      // Apply optional filters client-side
      if (filters['type'] != null && filters['type'].toString().isNotEmpty) {
        loaded = loaded
            .where((e) => (e['type'] ?? '').toString().toLowerCase() ==
                filters['type'].toString().toLowerCase())
            .toList();
      }
      if (filters['category'] != null && filters['category'].toString().isNotEmpty && filters['category'] != 'all') {
        loaded = loaded
            .where((e) => (e['category'] ?? '').toString().toLowerCase() ==
                filters['category'].toString().toLowerCase())
            .toList();
      }
      if (filters['condition'] != null && filters['condition'].toString().isNotEmpty && filters['condition'] != 'all') {
        loaded = loaded
            .where((e) => (e['condition'] ?? '').toString().toLowerCase() ==
                filters['condition'].toString().toLowerCase())
            .toList();
      }
      if (filters['part_name'] != null && filters['part_name'].toString().isNotEmpty) {
        final q = filters['part_name'].toString().toLowerCase();
        loaded = loaded.where((e) {
          final t = (e['title'] ?? '').toString().toLowerCase();
          final d = (e['description'] ?? '').toString().toLowerCase();
          return t.contains(q) || d.contains(q);
        }).toList();
      }
      if (filters['make'] != null && filters['make'].toString().isNotEmpty) {
        final q = filters['make'].toString().toLowerCase();
        loaded = loaded.where((e) => (e['make'] ?? '').toString().toLowerCase().contains(q)).toList();
      }
      if (filters['model'] != null && filters['model'].toString().isNotEmpty) {
        final q = filters['model'].toString().toLowerCase();
        loaded = loaded.where((e) => (e['model'] ?? '').toString().toLowerCase().contains(q)).toList();
      }
      if (filters['year'] != null) {
        loaded = loaded.where((e) => e['year'] == filters['year']).toList();
      }

      // Attach listing_photos for RPC results
      final ids = loaded.map((e) => e['id']).where((id) => id != null).toList();
      if (ids.isNotEmpty) {
        final photosResp = await Supabase.instance.client
            .from('listing_photos')
            .select('listing_id, storage_path, sort_order')
            .inFilter('listing_id', ids)
            .order('sort_order');
        final photos = List<Map<String, dynamic>>.from(photosResp ?? []);
        final Map<dynamic, List<Map<String, dynamic>>> byListing = {};
        for (final p in photos) {
          final lid = p['listing_id'];
          byListing.putIfAbsent(lid, () => []);
          byListing[lid]!.add({'storage_path': p['storage_path'], 'sort_order': p['sort_order']});
        }
        for (final item in loaded) {
          item['listing_photos'] = byListing[item['id']] ?? [];
        }
      }

      // Track impressions for RPC results
      for (final it in loaded) {
        final id = it['id'];
        if (id != null) {
          try {
            await Supabase.instance.client
                .rpc('track_event', params: {'_listing_id': id, '_type': 'impression'});
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _listings = loaded;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Search failed: ${e.toString()}';
        _loading = false;
      });
    }
  }

  Future<void> filterByCategoryOrType({String? type, String? category}) async {
    final filters = <String, dynamic>{};
    if (type != null && type.isNotEmpty) filters['type'] = type;
    if (category != null && category.isNotEmpty) filters['category'] = category;
    await performAdvancedSearch(filters);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with gradient and top icons
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withOpacity(0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top bar with icons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Menu icon
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                            ),
                            // Right side icons
                            Row(
                              children: [
                                // Help icon
                                IconButton(
                                  onPressed: () {},
                                  icon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade400,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.help_outline, color: Colors.white, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Notification icon with badge
                                _buildNotificationIcon(),
                                const SizedBox(width: 8),
                                // Profile icon
                                _buildProfileIcon(),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Welcome text
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Find Quality Auto Parts Faster',
                                style: GoogleFonts.poppins(
                                  fontSize: MediaQuery.of(context).size.width < 360 ? 18 : 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Browse thousands of listings from verified sellers across the country.',
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width < 360 ? 12 : 14,
                                  color: Colors.white.withOpacity(0.9),
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Categories Section
          SliverToBoxAdapter(
            child: _buildCategoriesSection(),
          ),
          
          // Hero Carousel Section
          SliverToBoxAdapter(
            child: _buildHeroCarousel(),
          ),
          
          // Promoted Products Grid
          SliverToBoxAdapter(
            child: _buildPromotedGrid(),
          ),
          
          // Search Panel
          SliverToBoxAdapter(
            child: SearchPanel(onSearch: performAdvancedSearch),
          ),
          
          // All Listings Grid
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'All Listings',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralDark,
                ),
              ),
            ),
          ),
          
          // Results
          _loading
              ? const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              : _error != null
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadListings,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _listings.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No listings found'),
                                SizedBox(height: 8),
                                Text('Try adjusting your search filters', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        )
                      : SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final width = MediaQuery.of(context).size.width;
                            int cols;
                            if (width < 360) {
                              cols = 1;
                            } else if (width < 600) {
                              cols = 2;
                            } else {
                              cols = 3;
                            }
                            // Compute a safe height: image (16:10) + content block
                            const double padding = 16.0; // matches SliverPadding below
                            const double spacing = 12.0;
                            final double availableWidth = width - (padding * 2);
                            final double tileWidth = (availableWidth - spacing * (cols - 1)) / cols;
                            final double mainExtent = (tileWidth * (10 / 16)) + 180; // increased content allowance to avoid overflow
                            return SliverPadding(
                              padding: const EdgeInsets.all(16),
                              sliver: SliverGrid(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  mainAxisExtent: mainExtent,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => ListingCard(listing: _listings[index]),
                                  childCount: _listings.length,
                                ),
                              ),
                            );
                          },
                        ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      children: [
        IconButton(
          onPressed: () {
            // Navigate to notifications page
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationsPage()),
            );
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
          ),
        ),
        // Notification badge
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(
              minWidth: 16,
              minHeight: 16,
            ),
            child: const Text(
              '3',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileIcon() {
    final user = Supabase.instance.client.auth.currentUser;
    
    return IconButton(
      onPressed: () {
        if (user == null) {
          // Navigate to auth page
          context.go('/auth');
        } else {
          // Navigate to profile page
          final homeShell = context.findAncestorStateOfType<_HomeShellState>();
          if (homeShell != null) {
            homeShell.switchToTab(homeShell._isSeller ? 3 : 2); // Profile tab
          }
        }
      },
      icon: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: user != null ? Colors.green.shade400 : Colors.grey.shade400,
          shape: BoxShape.circle,
        ),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white,
          child: user != null
              ? Text(
                  (user.userMetadata?['name'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                )
              : const Icon(
                  Icons.person_outline,
                  color: Colors.grey,
                  size: 16,
                ),
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final categories = [
      {'name': 'Vehicles & Cars', 'icon': Icons.directions_car, 'color': Colors.blue},
      {'name': 'Engine Parts', 'icon': Icons.settings, 'color': Colors.orange},
      {'name': 'Tires & Wheels', 'icon': Icons.album, 'color': Colors.green},
      {'name': 'Electronics', 'icon': Icons.electrical_services, 'color': Colors.purple},
      {'name': 'Body Parts', 'icon': Icons.build, 'color': Colors.red},
    ];

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Categories',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralDark,
                ),
              ),
              TextButton(
                onPressed: () async {
                  final selection = await context.push<String>('/categories');
                  if (selection == null || selection.isEmpty) return;
                  if (selection.startsWith('TYPE:')) {
                    final type = selection.split(':').last;
                    await filterByCategoryOrType(type: type);
                  } else if (selection.startsWith('CAT:')) {
                    final cat = selection.split(':').last;
                    await filterByCategoryOrType(type: 'part', category: cat);
                  }
                },
                child: Text(
                  'View More',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 4),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return GestureDetector(
                  onTap: () async {
                    final selection = await context.push<String>('/categories');
                    if (selection == null || selection.isEmpty) return;
                    if (selection.startsWith('TYPE:')) {
                      final type = selection.split(':').last;
                      await filterByCategoryOrType(type: type);
                    } else if (selection.startsWith('CAT:')) {
                      final cat = selection.split(':').last;
                      await filterByCategoryOrType(type: 'part', category: cat);
                    }
                  },
                  child: Container(
                    width: 85,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Container(
                          width: 65,
                          height: 65,
                          decoration: BoxDecoration(
                            color: (category['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (category['color'] as Color).withOpacity(0.2),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (category['color'] as Color).withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            category['icon'] as IconData,
                            color: category['color'] as Color,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          category['name'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.neutralDark,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.3, end: 0),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCarousel() {
    if (_featuredListings.isEmpty) return const SizedBox.shrink();
    
    final carouselItems = _featuredListings.take(5).toList();
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          carousel.CarouselSlider.builder(
            itemCount: carouselItems.length,
            options: carousel.CarouselOptions(
              height: 280,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 5),
              autoPlayAnimationDuration: const Duration(milliseconds: 800),
              autoPlayCurve: Curves.fastOutSlowIn,
              enlargeCenterPage: true,
              viewportFraction: 0.85,
              aspectRatio: 16/9,
              onPageChanged: (index, reason) {
                setState(() => _currentCarouselIndex = index);
              },
            ),
            itemBuilder: (context, index, realIndex) {
              final listing = carouselItems[index];
              return _buildCarouselCard(listing);
            },
          ),
          const SizedBox(height: 16),
          AnimatedSmoothIndicator(
            activeIndex: _currentCarouselIndex,
            count: carouselItems.length,
            effect: WormEffect(
              dotHeight: 8,
              dotWidth: 8,
              activeDotColor: AppColors.primary,
              dotColor: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselCard(Map<String, dynamic> listing) {
    final photos = listing['listing_photos'] as List? ?? [];
    final firstPhoto = photos.isNotEmpty ? photos.first['storage_path'] : null;
    final title = listing['title'] ?? 'No Title';
    final price = listing['price'];
    final condition = listing['condition'] ?? '';
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsPage(listing: listing),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              if (firstPhoto != null)
                FutureBuilder<String>(
                  future: Supabase.instance.client.storage
                      .from('listing-photos')
                      .createSignedUrl(firstPhoto, 3600),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return Image.network(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported, size: 50),
                        ),
                      );
                    }
                    return Container(color: Colors.grey.shade200);
                  },
                )
              else
                Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.directions_car, size: 80, color: Colors.grey),
                ),
              
              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
              
              // Content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (condition.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getConditionColor(condition),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            condition.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              price != null ? '\$${price.toStringAsFixed(2)}' : 'Contact for price',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Featured Badge
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'FEATURED',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).scale(delay: 100.ms);
  }

  Color _getConditionColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'new':
        return Colors.green;
      case 'like new':
        return Colors.lightGreen;
      case 'good':
        return Colors.blue;
      case 'fair':
        return Colors.orange;
      case 'for parts':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPromotedGrid() {
    if (_featuredListings.length <= 5) return const SizedBox.shrink();
    
    final gridItems = _featuredListings.skip(5).take(6).toList();
    
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'More Featured Items',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralDark,
                ),
              ),
              if (_featuredListings.length > 11)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PromotedProductsPage(listings: _featuredListings),
                      ),
                    );
                  },
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cols = w < 360 ? 1 : 2;
              final aspect = cols == 1 ? 1.1 : 0.8;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  childAspectRatio: aspect,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: gridItems.length,
                itemBuilder: (context, index) {
                  return PromotedCard(listing: gridItems[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class SellPage extends StatefulWidget {
  const SellPage({super.key});

  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  bool _checkingProfile = true;
  bool _profileCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkProfileCompletion();
  }

  Future<void> _checkProfileCompletion() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('profile_completed')
            .eq('id', user.id)
            .maybeSingle();

        setState(() {
          _profileCompleted = response?['profile_completed'] ?? false;
          _checkingProfile = false;
        });
      } catch (e) {
        setState(() {
          _profileCompleted = false;
          _checkingProfile = false;
        });
      }
    } else {
      setState(() {
        _checkingProfile = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user == null) {
      return _buildAuthPrompt();
    }

    if (_checkingProfile) {
      return _buildLoadingScreen();
    }
    
    // Check if user is a seller
    final userType = user.userMetadata?['user_type'] ?? 'buyer';
    if (userType != 'seller') {
      return _buildSellerPrompt();
    }
    
    // Always show My Products page for sellers, but check profile completion when creating listings
    return MyProductsPage();
  }
  
  Widget _buildLoadingScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Parts'),
        backgroundColor: Colors.transparent,
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildProfilePrompt() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Parts'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 64,
                color: Colors.orange.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Complete Your Profile',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need to complete your seller profile before you can create listings.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final homeShell = context.findAncestorStateOfType<_HomeShellState>();
                    if (homeShell != null) {
                      homeShell.switchToTab(3);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.edit),
                  label: Text(
                    'Complete Profile',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthPrompt() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Parts'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.store,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Sign In Required',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need to sign in to list items for sale',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/auth'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSellerPrompt() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sell Parts'),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.store_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Seller Account Required',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You need a seller account to list items for sale. Create a new seller account to get started.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/auth'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Create Seller Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildListingForm() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Listing'),
        backgroundColor: Colors.transparent,
      ),
      body: const ListingForm(),
    );
  }
}

class ListingForm extends StatefulWidget {
  const ListingForm({super.key});

  @override
  State<ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends State<ListingForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _zipController = TextEditingController();
  final _vinController = TextEditingController();
  
  String _category = 'part';
  String _condition = 'used';
  String _selectedPartCategory = 'engine';
  String? _selectedMake;
  String? _selectedModel;
  String? _selectedYear;
  String? _selectedFuelType;
  List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  String? _error;

  // Part categories matching the database
  final Map<String, String> _partCategories = {
    'engine': 'Engine',
    'tyres': 'Tyres',
    'brakes': 'Brakes',
    'suspension': 'Suspension',
    'interior': 'Interior',
    'exterior': 'Exterior',
    'accessories': 'Accessories',
    'wheels': 'Wheels',
    'electronics': 'Electronics',
    'audio': 'Audio',
    'lighting': 'Lighting',
  };

  // Car makes and their models
  final Map<String, List<String>> _carMakes = {
    'Toyota': ['Camry', 'Corolla', 'Prius', 'RAV4', 'Highlander', 'Tacoma', 'Tundra', 'Sienna', 'Avalon', 'Venza'],
    'Honda': ['Civic', 'Accord', 'CR-V', 'Pilot', 'Odyssey', 'Fit', 'HR-V', 'Passport', 'Ridgeline', 'Insight'],
    'Ford': ['F-150', 'Mustang', 'Explorer', 'Escape', 'Focus', 'Fusion', 'Edge', 'Expedition', 'Ranger', 'Bronco'],
    'Chevrolet': ['Silverado', 'Equinox', 'Malibu', 'Traverse', 'Tahoe', 'Suburban', 'Camaro', 'Corvette', 'Cruze', 'Impala'],
    'BMW': ['3 Series', '5 Series', '7 Series', 'X3', 'X5', 'X7', 'Z4', 'i3', 'i8', 'M3'],
    'Mercedes-Benz': ['C-Class', 'E-Class', 'S-Class', 'GLC', 'GLE', 'GLS', 'A-Class', 'CLA', 'GLA', 'AMG GT'],
    'Audi': ['A3', 'A4', 'A6', 'A8', 'Q3', 'Q5', 'Q7', 'Q8', 'TT', 'R8'],
    'Nissan': ['Altima', 'Sentra', 'Maxima', 'Rogue', 'Murano', 'Pathfinder', 'Titan', 'Frontier', '370Z', 'GT-R'],
    'Hyundai': ['Elantra', 'Sonata', 'Tucson', 'Santa Fe', 'Palisade', 'Veloster', 'Genesis', 'Kona', 'Ioniq', 'Accent'],
    'Kia': ['Forte', 'Optima', 'Sportage', 'Sorento', 'Telluride', 'Soul', 'Stinger', 'Rio', 'Niro', 'Cadenza'],
  };

  // Years from 1990 to current year + 1
  List<String> get _years {
    final currentYear = DateTime.now().year;
    return List.generate(currentYear - 1989, (index) => (currentYear + 1 - index).toString());
  }

  // Fuel types
  final List<String> _fuelTypes = [
    'Gasoline',
    'Diesel',
    'Hybrid',
    'Electric',
    'Plug-in Hybrid',
    'Compressed Natural Gas',
    'Ethanol',
    'Hydrogen',
  ];

  // Condition options
  final Map<String, String> _conditionOptions = {
    'new': 'New',
    'like_new': 'Like New',
    'used': 'Used',
    'fair': 'Fair',
    'salvage': 'Salvage',
  };

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
          // Limit to 5 images
          if (_selectedImages.length > 5) {
            _selectedImages = _selectedImages.take(5).toList();
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick images: ${e.toString()}';
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _zipController.dispose();
    _vinController.dispose();
    super.dispose();
  }

  Future<void> _submitListing() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          _loading = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to create a listing')),
          );
          context.go('/auth');
        }
        return;
      }
      // On iOS, require any active subscription entitlement before creating a listing
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        final hasSub = await RevenueCatService.instance.hasAnyEntitlement({
          'basic_access', 'premium_access', 'vip_access', 'vipgold_access',
        });
        if (!hasSub) {
          if (mounted) {
            _loading = false;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('A subscription is required to create listings on iOS.')),
            );
            context.go('/paywall');
          }
          return;
        }
      }

      // Create listing data matching the actual database schema
      final listingData = <String, dynamic>{
        'owner_id': user.id,
        'type': _category == 'vehicle' ? 'car' : 'part',
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price_usd': double.parse(_priceController.text.trim()),
        'condition': _condition,
      };

      // Add category for parts
      if (_category == 'part') {
        listingData['category'] = _selectedPartCategory;
      }
      
      // Add vehicle-specific fields if category is vehicle (car)
      if (_category == 'vehicle') {
        if (_selectedMake != null) {
          listingData['make'] = _selectedMake!;
        }
        if (_selectedModel != null) {
          listingData['model'] = _selectedModel!;
        }
        if (_selectedYear != null) {
          listingData['model_year'] = int.parse(_selectedYear!);
        }
        // VIN is required for cars
        listingData['vin'] = _vinController.text.trim();
      }
      
      // Use actual ZIP code entered by user, fallback to valid ZIP if needed
      final userZip = _zipController.text.trim();
      listingData['zip'] = userZip.isNotEmpty ? userZip : '00601';
      
      final response = await Supabase.instance.client
          .from('listings')
          .insert(listingData)
          .select()
          .single();
      
      // Upload images if any are selected
      if (_selectedImages.isNotEmpty) {
        final listingId = response['id'];
        await _uploadImages(listingId);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Listing created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        
        // Clear form
        _formKey.currentState?.reset();
        _titleController.clear();
        _descriptionController.clear();
        _priceController.clear();
        _zipController.clear();
        _vinController.clear();
        setState(() {
          _category = 'part';
          _condition = 'used';
          _selectedPartCategory = 'engine';
          _selectedMake = null;
          _selectedModel = null;
          _selectedYear = null;
          _selectedFuelType = null;
          _selectedImages = [];
        });
        
        // Navigate to My Product page after successful creation
        // Prefer switching tabs if we're inside the HomeShell, otherwise fall back to a route
        final homeShell = context.findAncestorStateOfType<_HomeShellState>();
        if (homeShell != null) {
          // Switch to the My Products tab (index 1 for sellers)
          homeShell.switchToTab(1);
          // If this form was pushed modally, pop back to the shell
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        } else {
          // Fallback: use router to go to the My Products route
          context.go('/my-products');
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to create listing: ${e.toString()}';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _uploadImages(String listingId) async {
    for (int i = 0; i < _selectedImages.length; i++) {
      final image = _selectedImages[i];
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
      final storagePath = 'listings/$listingId/$fileName';
      
      try {
        // Upload to Supabase Storage
        await Supabase.instance.client.storage
            .from('listing-images')
            .uploadBinary(storagePath, await image.readAsBytes());
        
        // Save photo record to database
        await Supabase.instance.client.from('listing_photos').insert({
          'listing_id': listingId,
          'storage_path': storagePath,
          'sort_order': i,
        });
      } catch (e) {
        print('Failed to upload image $i: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Error message
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g., 2020 Toyota Camry Engine',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Type and Condition selection
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    decoration: InputDecoration(
                      labelText: 'Type *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'part', child: Text('Auto Part')),
                      DropdownMenuItem(value: 'vehicle', child: Text('Vehicle')),
                    ],
                    onChanged: (value) => setState(() => _category = value!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _condition,
                    decoration: InputDecoration(
                      labelText: 'Condition *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _conditionOptions.entries.map((entry) {
                      return DropdownMenuItem(value: entry.key, child: Text(entry.value));
                    }).toList(),
                    onChanged: (value) => setState(() => _condition = value!),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Part category (only show for parts)
            if (_category == 'part') ...[
              DropdownButtonFormField<String>(
                value: _selectedPartCategory,
                decoration: InputDecoration(
                  labelText: 'Part Category *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _partCategories.entries.map((entry) {
                  return DropdownMenuItem(value: entry.key, child: Text(entry.value));
                }).toList(),
                onChanged: (value) => setState(() => _selectedPartCategory = value!),
              ),
              const SizedBox(height: 16),
            ],
            
            // Vehicle-specific fields
            if (_category == 'vehicle') ...[
              const SizedBox(height: 16),
              // Make dropdown
              DropdownButtonFormField<String>(
                value: _selectedMake,
                decoration: InputDecoration(
                  labelText: 'Make',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                hint: const Text('Select Make'),
                items: _carMakes.keys.map((make) {
                  return DropdownMenuItem(value: make, child: Text(make));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMake = value;
                    _selectedModel = null; // Reset model when make changes
                  });
                },
              ),
              
              const SizedBox(height: 16),
              
              // Model dropdown (only show if make is selected)
              DropdownButtonFormField<String>(
                value: _selectedModel,
                decoration: InputDecoration(
                  labelText: 'Model',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                hint: const Text('Select Model'),
                items: _selectedMake != null
                    ? ((_carMakes[_selectedMake!] ?? const <String>[]) as List<String>)
                        .map((model) => DropdownMenuItem(value: model, child: Text(model)))
                        .toList()
                    : const [],
                onChanged: _selectedMake != null
                    ? (value) {
                        setState(() {
                          _selectedModel = value;
                        });
                      }
                    : null,
              ),
              
              const SizedBox(height: 16),
              
              // Year and Fuel Type row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedYear,
                      decoration: InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      hint: const Text('Select Year'),
                      items: _years.map((year) {
                        return DropdownMenuItem(value: year, child: Text(year));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedYear = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedFuelType,
                      decoration: InputDecoration(
                        labelText: 'Fuel Type',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      hint: const Text('Select Fuel Type'),
                      items: _fuelTypes.map((fuelType) {
                        return DropdownMenuItem(value: fuelType, child: Text(fuelType));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFuelType = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              
              // VIN field for vehicles
              const SizedBox(height: 16),
              TextFormField(
                controller: _vinController,
                decoration: InputDecoration(
                  labelText: 'VIN *',
                  hintText: '17-character Vehicle Identification Number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a VIN';
                  }
                  final vin = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
                  if (vin.length < 11 || vin.length > 17) {
                    return 'VIN must be between 11-17 characters';
                  }
                  return null;
                },
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Price and ZIP
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'Price *',
                      hintText: '1500.00',
                      prefixText: '\$',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a price';
                      }
                      final price = double.tryParse(value.trim());
                      if (price == null || price <= 0) {
                        return 'Please enter a valid price';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _zipController,
                    decoration: InputDecoration(
                      labelText: 'ZIP Code *',
                      hintText: '90210',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a ZIP code';
                      }
                      if (value.trim().length != 5 || !RegExp(r'^\d{5}$').hasMatch(value.trim())) {
                        return 'ZIP code must be exactly 5 digits';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Image Upload Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.photo_camera, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Photos (${_selectedImages.length}/5)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _selectedImages.length < 5 ? _pickImages : null,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Add Photos'),
                      ),
                    ],
                  ),
                  if (_selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: kIsWeb
                                      ? Image.network(
                                          _selectedImages[index].path,
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 100,
                                              height: 100,
                                              color: Colors.grey.shade300,
                                              child: const Icon(Icons.image, color: Colors.grey),
                                            );
                                          },
                                        )
                                      : Image.file(
                                          File(_selectedImages[index].path),
                                          width: 100,
                                          height: 100,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Add up to 5 photos to showcase your item',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description *',
                hintText: 'Describe the item condition, features, etc.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Submit button
            ElevatedButton(
              onPressed: _loading ? null : _submitListing,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Create Listing',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            
            const SizedBox(height: 16),
            
            // Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your listing will be visible to buyers immediately after creation.',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    // Check if buyer has completed profile before accessing chat
    final userType = user.userMetadata?['user_type'] ?? 'buyer';
    if (userType == 'buyer') {
      try {
        final profileResponse = await Supabase.instance.client
            .from('profiles')
            .select('profile_completed')
            .eq('id', user.id)
            .maybeSingle();
        
        final profileCompleted = profileResponse?['profile_completed'] ?? false;
        if (!profileCompleted) {
          setState(() => _loading = false);
          return;
        }
      } catch (e) {
        // If error checking profile, continue loading conversations
      }
    }

    try {
      final response = await Supabase.instance.client
          .rpc('get_conversations_with_details', params: {'user_uuid': user.id});

      if (mounted) {
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(response ?? []);
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading conversations: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chat'),
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign In Required',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutralDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You need to sign in to view your conversations.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/auth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Check if buyer needs to complete profile
    final userType = user.userMetadata?['user_type'] ?? 'buyer';
    if (userType == 'buyer' && !_loading && _conversations.isEmpty) {
      // Check if this is because profile is incomplete
      return FutureBuilder<bool>(
        future: _checkProfileCompletion(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Messages'),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          
          final profileCompleted = snapshot.data ?? true;
          if (!profileCompleted) {
            return _buildProfilePrompt();
          }
          
          return _buildMainChatPage();
        },
      );
    }

    return _buildMainChatPage();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Conversations Yet',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.neutralDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation by contacting a seller from a product listing.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainChatPage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  child: ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = _conversations[index];
                      return ConversationTile(
                        conversation: conversation,
                        onTap: () => _openConversation(conversation),
                      );
                    },
                  ),
                ),
    );
  }

  void _openConversation(Map<String, dynamic> conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationPage(conversation: conversation),
      ),
    ).then((_) {
      // Refresh conversations when returning from chat
      _loadConversations();
    });
  }

  Future<bool> _checkProfileCompletion(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('profile_completed')
          .eq('id', userId)
          .maybeSingle();
      
      return response?['profile_completed'] ?? false;
    } catch (e) {
      return true; // If error, assume profile is complete
    }
  }

  Widget _buildProfilePrompt() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_outline,
                size: 64,
                color: Colors.orange.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Complete Your Profile',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete your profile to start chatting with sellers and get the best deals.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final homeShell = context.findAncestorStateOfType<_HomeShellState>();
                    if (homeShell != null) {
                      homeShell.switchToTab(3); // Profile tab
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.edit),
                  label: Text(
                    'Complete Profile',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unreadCount = conversation['unread_count'] ?? 0;
    final lastMessage = conversation['last_message'] ?? '';
    final otherUserName = conversation['other_user_name'] ?? 'Unknown User';
    final listingTitle = conversation['listing_title'] ?? 'Unknown Item';
    final listingPrice = conversation['listing_price']?.toDouble() ?? 0.0;
    final lastMessageAt = conversation['last_message_at'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherUserName,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Re: $listingTitle (\$${listingPrice.toStringAsFixed(0)})',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (lastMessageAt != null)
              Text(
                _formatTimestamp(lastMessageAt),
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        onTap: onTap,
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }
}

class ConversationPage extends StatefulWidget {
  final Map<String, dynamic> conversation;

  const ConversationPage({super.key, required this.conversation});

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _otherUserTyping = false;
  RealtimeChannel? _channel;
  RealtimeChannel? _typingChannel;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markMessagesAsRead();
    _setupRealtimeSubscription();
    _setupTypingIndicators();
  }

  void _setupRealtimeSubscription() {
    final conversationId = widget.conversation['conversation_id'];
    print('Setting up realtime subscription for conversation: $conversationId');
    
    _channel = Supabase.instance.client
        .channel('messages_$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            print('Received realtime message: ${payload.newRecord}');
            final newMessage = payload.newRecord;
            if (newMessage != null && mounted) {
              _loadSingleMessage(newMessage['id']);
              _handleNewMessageNotification(newMessage);
            }
          },
        )
        .subscribe((status, [error]) {
          print('Subscription status: $status, error: $error');
          if (status == RealtimeSubscribeStatus.closed && mounted) {
            // Attempt to reconnect after a delay
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                print('Attempting to reconnect realtime subscription...');
                _setupRealtimeSubscription();
              }
            });
          }
        });
  }

  Future<void> _handleNewMessageNotification(Map<String, dynamic> newMessage) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Only show notification if message is from another user
    final senderId = newMessage['sender_id'];
    if (senderId == user.id) return;

    // Always show notification for messages from other users
    final shouldShowNotification = true;

    if (shouldShowNotification) {
      try {
        // Get sender name
        String senderName = widget.conversation['other_user_name'] ?? 'Unknown User';
        
        // Get message content
        final content = newMessage['content'] ?? 'New message';
        
        // Show notification with sound
        await _notificationService.showMessageNotification(
          senderName: senderName,
          message: content,
          conversationId: widget.conversation['conversation_id'],
          playSound: true,
        );
      } catch (e) {
        print('Error showing notification: $e');
      }
    }
  }

  void _setupTypingIndicators() {
    final conversationId = widget.conversation['conversation_id'];
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _typingChannel = Supabase.instance.client
        .channel('typing_$conversationId')
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final senderId = payload['sender_id'];
            final isTyping = payload['is_typing'] ?? false;
            
            // Only show typing indicator if it's from the other user
            if (senderId != user.id && mounted) {
              setState(() {
                _otherUserTyping = isTyping;
              });
              
              // Auto-hide typing indicator after 3 seconds
              if (isTyping) {
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) {
                    setState(() {
                      _otherUserTyping = false;
                    });
                  }
                });
              }
            }
          },
        )
        .subscribe();
  }

  void _sendTypingIndicator(bool isTyping) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _typingChannel == null) return;

    _typingChannel!.sendBroadcastMessage(
      event: 'typing',
      payload: {
        'sender_id': user.id,
        'is_typing': isTyping,
      },
    );
  }

  Future<void> _loadSingleMessage(String messageId) async {
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select('id, conversation_id, sender_id, content, created_at, read_at')
          .eq('id', messageId)
          .single();

      // Load sender name
      try {
        final senderResponse = await Supabase.instance.client
            .from('profiles')
            .select('contact_person')
            .eq('id', response['sender_id'])
            .single();
        response['sender_name'] = senderResponse['contact_person'];
      } catch (e) {
        response['sender_name'] = 'Unknown';
      }

      if (mounted) {
        setState(() {
          // Check if message already exists to avoid duplicates
          final existingIndex = _messages.indexWhere((m) => m['id'] == messageId);
          if (existingIndex == -1) {
            _messages.add(response);
            _messages.sort((a, b) => DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));
          }
        });
        
        // Scroll to bottom when new message arrives
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      print('Error loading single message: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe();
    _typingChannel?.unsubscribe();
    // Cancel notifications for this conversation when leaving
    _notificationService.cancelNotification(widget.conversation['conversation_id']);
    super.dispose();
  }

  Future<void> _loadMessages({int limit = 50, int offset = 0}) async {
    try {
      final response = await Supabase.instance.client
          .from('messages')
          .select('id, conversation_id, sender_id, content, created_at, read_at')
          .eq('conversation_id', widget.conversation['conversation_id'])
          .order('created_at', ascending: false)
          .limit(limit)
          .range(offset, offset + limit - 1);

      // Load sender names separately
      final messages = List<Map<String, dynamic>>.from(response ?? []);
      for (var message in messages) {
        try {
          final senderResponse = await Supabase.instance.client
              .from('profiles')
              .select('contact_person')
              .eq('id', message['sender_id'])
              .single();
          message['sender_name'] = senderResponse['contact_person'];
        } catch (e) {
          message['sender_name'] = 'Unknown';
        }
      }

      // Reverse to show oldest first
      messages.sort((a, b) => DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));

      if (mounted) {
        setState(() {
          if (offset == 0) {
            _messages = messages;
          } else {
            _messages.insertAll(0, messages);
          }
          _loading = false;
        });
      }

      // Scroll to bottom after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Error loading messages: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('messages')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('conversation_id', widget.conversation['conversation_id'])
          .neq('sender_id', user.id)
          .isFilter('read_at', null);
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _sending) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _sending = true);

    try {
      final messageData = {
        'conversation_id': widget.conversation['conversation_id'],
        'sender_id': user.id,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      print('Sending message: $messageData');
      
      final response = await Supabase.instance.client
          .from('messages')
          .insert(messageData)
          .select('id, conversation_id, sender_id, content, created_at, read_at')
          .single();
      
      print('Message sent successfully: $response');

      // Add sender name to the response
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        try {
          final profileResponse = await Supabase.instance.client
              .from('profiles')
              .select('contact_person')
              .eq('id', currentUser.id)
              .single();
          response['sender_name'] = profileResponse['contact_person'];
        } catch (e) {
          response['sender_name'] = 'You';
        }
      }

      _messageController.clear();
      
      // Add message immediately to UI for instant feedback
      if (mounted) {
        setState(() {
          _messages.add(response);
        });
        
        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        String errorMessage = 'Failed to send message';
        if (e.toString().contains('network') || e.toString().contains('connection')) {
          errorMessage = 'Network error. Please check your connection and try again.';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Request timed out. Please try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _sendMessage(),
            ),
          ),
        );
      }
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherUserName = widget.conversation['other_user_name'] ?? 'Unknown User';
    final listingTitle = widget.conversation['listing_title'] ?? 'Unknown Item';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              otherUserName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              'Re: $listingTitle',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(),
            tooltip: 'Search messages',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyMessages()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_otherUserTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _otherUserTyping) {
                            return _buildTypingIndicator();
                          }
                          final message = _messages[index];
                          return MessageBubble(message: message);
                        },
                      ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyMessages() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Start the conversation!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.neutralDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send your first message below.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              onChanged: (text) {
                // Send typing indicator when user starts typing
                if (text.isNotEmpty) {
                  _sendTypingIndicator(true);
                } else {
                  _sendTypingIndicator(false);
                }
              },
              onSubmitted: (_) {
                _sendTypingIndicator(false);
                _sendMessage();
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send),
              color: Colors.white,
              onPressed: _sending ? null : () {
                _sendTypingIndicator(false);
                _sendMessage();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: Text(
              (widget.conversation['other_user_name'] ?? '?')[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'typing',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Messages'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Enter search term...',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (query) {
                Navigator.pop(context);
                _searchMessages(query);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _searchMessages(String query) {
    if (query.trim().isEmpty) return;

    final searchResults = _messages.where((message) {
      final content = message['content']?.toString().toLowerCase() ?? '';
      return content.contains(query.toLowerCase());
    }).toList();

    if (searchResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No messages found')),
      );
      return;
    }

    // Find the first matching message and scroll to it
    final firstMatch = searchResults.first;
    final index = _messages.indexWhere((m) => m['id'] == firstMatch['id']);
    
    if (index != -1) {
      // Calculate approximate scroll position
      final itemHeight = 80.0; // Approximate height of a message bubble
      final scrollPosition = index * itemHeight;
      
      _scrollController.animateTo(
        scrollPosition,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${searchResults.length} message(s)'),
          action: SnackBarAction(
            label: 'Next',
            onPressed: () => _showNextSearchResult(query, 0),
          ),
        ),
      );
    }
  }

  void _showNextSearchResult(String query, int currentIndex) {
    final searchResults = _messages.where((message) {
      final content = message['content']?.toString().toLowerCase() ?? '';
      return content.contains(query.toLowerCase());
    }).toList();

    if (searchResults.isEmpty) return;

    final nextIndex = (currentIndex + 1) % searchResults.length;
    final nextMatch = searchResults[nextIndex];
    final messageIndex = _messages.indexWhere((m) => m['id'] == nextMatch['id']);
    
    if (messageIndex != -1) {
      final itemHeight = 80.0;
      final scrollPosition = messageIndex * itemHeight;
      
      _scrollController.animateTo(
        scrollPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Result ${nextIndex + 1} of ${searchResults.length}'),
          action: nextIndex < searchResults.length - 1
              ? SnackBarAction(
                  label: 'Next',
                  onPressed: () => _showNextSearchResult(query, nextIndex),
                )
              : null,
        ),
      );
    }
  }
}

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isMe = message['sender_id'] == user?.id;
    final content = message['content'] ?? '';
    final createdAt = message['created_at'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: Text(
                (message['sender_name'] ?? '?')[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppColors.neutralDark,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTimestamp(createdAt),
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      if (isMe && message['read_at'] != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: Colors.white70,
                        ),
                      ] else if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done,
                          size: 14,
                          color: Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.secondary,
              child: Text(
                'Me'[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _businessDescriptionController = TextEditingController();
  final _yearsInBusinessController = TextEditingController();
  final _specialtiesController = TextEditingController();
  
  String _businessType = 'individual';
  bool _isLoading = false;
  bool _hasProfile = false;
  bool _editMode = false;
  Map<String, dynamic>? _profile;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('id', user.id)
            .maybeSingle();

        if (response != null) {
          setState(() {
            _hasProfile = true;
            _profile = response;
            _businessNameController.text = response['business_name'] ?? '';
            _contactPersonController.text = response['contact_person'] ?? '';
            _phoneController.text = response['phone'] ?? '';
            _addressController.text = response['address'] ?? '';
            _cityController.text = response['city'] ?? '';
            _stateController.text = response['state'] ?? '';
            _zipController.text = response['zip_code'] ?? '';
            _businessDescriptionController.text = response['business_description'] ?? '';
            _yearsInBusinessController.text = response['years_in_business']?.toString() ?? '';
            _specialtiesController.text = response['specialties'] ?? '';
            _businessType = response['business_type'] ?? 'individual';
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
        });
      }
    }
  }

  bool _isProfileComplete() {
    return _businessNameController.text.trim().isNotEmpty &&
           _contactPersonController.text.trim().isNotEmpty &&
           _phoneController.text.trim().isNotEmpty &&
           _addressController.text.trim().isNotEmpty &&
           _cityController.text.trim().isNotEmpty &&
           _stateController.text.trim().isNotEmpty &&
           _zipController.text.trim().isNotEmpty;
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final isComplete = _isProfileComplete();
      
      final profileData = {
        'id': user.id,
        'business_name': _businessNameController.text.trim(),
        'contact_person': _contactPersonController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'zip_code': _zipController.text.trim(),
        'business_description': _businessDescriptionController.text.trim(),
        'years_in_business': int.tryParse(_yearsInBusinessController.text) ?? 0,
        'specialties': _specialtiesController.text.trim(),
        'business_type': _businessType,
        'rating': 5.0,
        'profile_completed': isComplete,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_hasProfile) {
        await Supabase.instance.client
            .from('profiles')
            .update(profileData)
            .eq('id', user.id);
      } else {
        await Supabase.instance.client
            .from('profiles')
            .insert(profileData);
        setState(() => _hasProfile = true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isComplete 
                ? 'Profile completed successfully! You can now create listings.' 
                : 'Profile saved! Complete all required fields to start selling.'),
            backgroundColor: isComplete ? Colors.green : Colors.orange,
          ),
        );
        setState(() {
          _editMode = false;
          _profile = {
            'business_name': _businessNameController.text.trim(),
            'contact_person': _contactPersonController.text.trim(),
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'city': _cityController.text.trim(),
            'state': _stateController.text.trim(),
            'zip_code': _zipController.text.trim(),
            'business_description': _businessDescriptionController.text.trim(),
            'years_in_business': int.tryParse(_yearsInBusinessController.text) ?? 0,
            'specialties': _specialtiesController.text.trim(),
            'business_type': _businessType,
          };
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Account',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete your account? This action cannot be undone.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('This will permanently delete:', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('• Your profile information'),
                    const Text('• All your listings'),
                    const Text('• Your chat messages'),
                    const Text('• Your subscription (if any)'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);

      // Delete user's listings first
      await Supabase.instance.client
          .from('listings')
          .delete()
          .eq('owner_id', user.id);

      // Delete user's messages
      await Supabase.instance.client
          .from('messages')
          .delete()
          .or('sender_id.eq.${user.id},recipient_id.eq.${user.id}');

      // Delete user's profile
      await Supabase.instance.client
          .from('profiles')
          .delete()
          .eq('id', user.id);

      // Finally, delete the auth user account
      // Note: This requires admin privileges or user confirmation via email
      // For now, we'll sign the user out. The actual account deletion
      // should be handled by your backend/Supabase Edge Function
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account data deleted successfully. You have been signed out.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value.isEmpty ? 'â€”' : value),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _helpAndLegalSection(BuildContext context, Map<String, dynamic> p) {
    final userType = ((p['user_type'] ?? Supabase.instance.client.auth.currentUser?.userMetadata?['user_type']) ?? 'buyer').toString();
    final isSeller = userType == 'seller';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Help & Legal', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('About Us'),
            onTap: () => context.push('/about'),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.support_agent_outlined),
            title: const Text('Contact Us'),
            onTap: () => context.push('/contact'),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => context.push('/privacy'),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            onTap: () => context.push('/terms'),
          ),
          const Divider(height: 24),
          if (!isSeller) ...[
            ElevatedButton(
              onPressed: () => context.go('/auth'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text('Become a Seller'),
            ),
            const SizedBox(height: 8),
          ],
          // Delete Account Button - required by Apple Guidelines
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _deleteAccount,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete Account'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSummary() {
    final p = _profile ?? {};
    final location = ((p['city'] ?? '') as String) + (((p['state'] ?? '') as String).isNotEmpty ? ', ${p['state']}' : '');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => setState(() => _editMode = true),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out successfully')),
                );
                context.go('/');
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: const Icon(Icons.person, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (p['business_name'] ?? p['contact_person'] ?? 'Your Profile').toString(),
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(location, style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Your Plan card (sellers only)
            if (((p['user_type'] ?? Supabase.instance.client.auth.currentUser?.userMetadata?['user_type']) ?? 'buyer') == 'seller')
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: Builder(
                  builder: (context) {
                    String planId = (p['active_plan_id'] as String?) ?? 'free';
                    final status = (p['subscription_status'] as String?) ?? 'inactive';
                    String label(String id) {
                      switch (id) {
                        case 'basic':
                          return 'Basic';
                        case 'premium':
                          return 'Premium';
                        case 'vip':
                          return 'VIP';
                        case 'vip_gold':
                          return 'VIP Gold';
                        default:
                          return 'Free';
                      }
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Plan', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green.shade900)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${label(planId)} (${status})',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                // On iOS, go directly to RevenueCat paywall
                                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
                                  context.go('/paywall');
                                } else {
                                  context.go('/billing');
                                }
                              },
                              icon: const Icon(Icons.manage_accounts),
                              label: const Text('Manage'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                // On iOS, go directly to RevenueCat paywall
                                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
                                  context.go('/paywall');
                                } else {
                                  context.go('/billing');
                                }
                              },
                              icon: const Icon(Icons.upgrade),
                              label: Text(planId == 'free' ? 'Upgrade' : 'Change Plan'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            _infoTile(Icons.phone, 'Phone', (p['phone'] ?? '').toString()),
            _infoTile(Icons.store, 'Business Type', (p['business_type'] ?? '').toString()),
            _infoTile(Icons.location_on, 'Address', (p['address'] ?? '').toString()),
            _infoTile(Icons.badge, 'Contact Person', (p['contact_person'] ?? '').toString()),
            _infoTile(Icons.calendar_month, 'Years in Business', (p['years_in_business'] ?? '').toString()),
            _infoTile(Icons.list_alt, 'Specialties', (p['specialties'] ?? '').toString()),
            _infoTile(Icons.description, 'Description', (p['business_description'] ?? '').toString()),
            const SizedBox(height: 16),
            _helpAndLegalSection(context, p),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    
    // Restrict access to authenticated users only
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.transparent,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign In Required',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutralDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You need to sign in to view and edit your profile.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/auth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // While loading profile data, avoid flashing the completion screen
    if (_loadingProfile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    // Always show profile page directly - no more flashing completion screen
    if (_hasProfile && !_editMode) {
      return _buildProfileSummary();
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_hasProfile ? (_editMode ? 'Edit Profile' : 'Your Profile') : 'Complete Your Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_hasProfile && _editMode)
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          if (_hasProfile)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signed out successfully')),
                  );
                  context.go('/home');
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seller Information',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neutralDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete your profile to start selling auto parts and build trust with buyers.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Business Type
              Text(
                'Business Type',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _businessType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'individual', child: Text('Individual Seller')),
                  DropdownMenuItem(value: 'auto_shop', child: Text('Auto Shop')),
                  DropdownMenuItem(value: 'parts_dealer', child: Text('Parts Dealer')),
                  DropdownMenuItem(value: 'salvage_yard', child: Text('Salvage Yard')),
                ],
                onChanged: (value) => setState(() => _businessType = value!),
              ),
              
              const SizedBox(height: 16),
              
              // Business/Shop Name
              TextFormField(
                controller: _businessNameController,
                decoration: InputDecoration(
                  labelText: 'Business/Shop Name *',
                  hintText: 'Enter your business or shop name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (value) => value?.isEmpty == true ? 'Business name is required' : null,
              ),
              
              const SizedBox(height: 16),
              
              // Contact Person
              TextFormField(
                controller: _contactPersonController,
                decoration: InputDecoration(
                  labelText: 'Contact Person *',
                  hintText: 'Your full name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (value) => value?.isEmpty == true ? 'Contact person is required' : null,
              ),
              
              const SizedBox(height: 16),
              
              // Phone
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: '(555) 123-4567',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty == true ? 'Phone number is required' : null,
              ),
              
              const SizedBox(height: 16),
              
              // Address
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Street Address *',
                  hintText: '123 Main Street',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (value) => value?.isEmpty == true ? 'Address is required' : null,
              ),
              
              const SizedBox(height: 16),
              
              // City, State, ZIP
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: 'City *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (value) => value?.isEmpty == true ? 'City is required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: InputDecoration(
                        labelText: 'State *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (value) => value?.isEmpty == true ? 'State is required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _zipController,
                      decoration: InputDecoration(
                        labelText: 'ZIP *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty == true ? 'ZIP is required' : null,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Years in Business
              TextFormField(
                controller: _yearsInBusinessController,
                decoration: InputDecoration(
                  labelText: 'Years in Business',
                  hintText: 'How many years have you been in business?',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                keyboardType: TextInputType.number,
              ),
              
              const SizedBox(height: 16),
              
              // Specialties
              TextFormField(
                controller: _specialtiesController,
                decoration: InputDecoration(
                  labelText: 'Specialties',
                  hintText: 'e.g., Honda parts, Engine components, Electrical systems',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: 2,
              ),
              
              const SizedBox(height: 16),
              
              // Business Description
              TextFormField(
                controller: _businessDescriptionController,
                decoration: InputDecoration(
                  labelText: 'Business Description',
                  hintText: 'Tell buyers about your business and experience',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: 3,
              ),
              
              const SizedBox(height: 32),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _hasProfile ? 'Update Profile' : 'Save Profile',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _businessDescriptionController = TextEditingController();
  final _yearsInBusinessController = TextEditingController();
  final _specialtiesController = TextEditingController();
  
  String _businessType = 'individual';
  bool _isLoading = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _businessDescriptionController.dispose();
    _yearsInBusinessController.dispose();
    _specialtiesController.dispose();
    super.dispose();
  }

  bool _isProfileComplete() {
    final user = Supabase.instance.client.auth.currentUser;
    final userType = user?.userMetadata?['user_type'] ?? 'buyer';
    
    if (userType == 'buyer') {
      // Buyers only need basic info
      return _contactPersonController.text.trim().isNotEmpty &&
             _phoneController.text.trim().isNotEmpty &&
             _cityController.text.trim().isNotEmpty &&
             _stateController.text.trim().isNotEmpty;
    } else {
      // Sellers need complete business info
      return _businessNameController.text.trim().isNotEmpty &&
             _contactPersonController.text.trim().isNotEmpty &&
             _phoneController.text.trim().isNotEmpty &&
             _addressController.text.trim().isNotEmpty &&
             _cityController.text.trim().isNotEmpty &&
             _stateController.text.trim().isNotEmpty &&
             _zipController.text.trim().isNotEmpty;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userType = user.userMetadata?['user_type'] ?? 'buyer';
      final isComplete = _isProfileComplete();
      
      final profileData = {
        'id': user.id,
        'user_type': userType,
        'contact_person': _contactPersonController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'profile_completed': isComplete,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Add seller-specific fields
      if (userType == 'seller') {
        profileData.addAll({
          'business_name': _businessNameController.text.trim(),
          'business_type': _businessType,
          'address': _addressController.text.trim(),
          'zip_code': _zipController.text.trim(),
          'business_description': _businessDescriptionController.text.trim(),
          'years_in_business': _yearsInBusinessController.text.trim().isNotEmpty 
              ? int.tryParse(_yearsInBusinessController.text.trim()) 
              : null,
          'specialties': _specialtiesController.text.trim(),
        });
      } else {
        // For buyers, set ZIP if provided
        if (_zipController.text.trim().isNotEmpty) {
          profileData['zip_code'] = _zipController.text.trim();
        }
      }

      await Supabase.instance.client
          .from('profiles')
          .upsert(profileData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isComplete 
                ? 'Profile completed successfully!' 
                : 'Profile saved! You can complete it later.'),
            backgroundColor: isComplete ? Colors.green : Colors.orange,
          ),
        );
        
        // Navigate to home after profile completion
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userType = user?.userMetadata?['user_type'] ?? 'buyer';
    final isSeller = userType == 'seller';

    return Scaffold(
      appBar: AppBar(
        title: Text('Complete Your Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome message
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      isSeller ? Icons.store : Icons.person,
                      size: 48,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome ${isSeller ? 'Seller' : 'Buyer'}!',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSeller 
                          ? 'Complete your business profile to start selling parts'
                          : 'Complete your profile to start browsing and buying parts',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Business Type (Sellers only)
              if (isSeller) ...[
                Text(
                  'Business Type *',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutralDark,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _businessType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'individual', child: Text('Individual Seller')),
                    DropdownMenuItem(value: 'shop', child: Text('Auto Shop')),
                    DropdownMenuItem(value: 'dealer', child: Text('Parts Dealer')),
                    DropdownMenuItem(value: 'salvage', child: Text('Salvage Yard')),
                  ],
                  onChanged: (value) => setState(() => _businessType = value!),
                ),
                const SizedBox(height: 16),

                // Business Name (Sellers only)
                TextFormField(
                  controller: _businessNameController,
                  decoration: InputDecoration(
                    labelText: 'Business/Shop Name *',
                    hintText: 'Enter your business name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Business name is required' : null,
                ),
                const SizedBox(height: 16),
              ],
              
              // Contact Person
              TextFormField(
                controller: _contactPersonController,
                decoration: InputDecoration(
                  labelText: 'Contact Person *',
                  hintText: 'Your full name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                validator: (value) => value?.isEmpty == true ? 'Contact person is required' : null,
              ),
              
              const SizedBox(height: 16),
              
              // Phone
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: '(555) 123-4567',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty == true ? 'Phone number is required' : null,
              ),
              
              const SizedBox(height: 16),
              
              // Address (Sellers only, required)
              if (isSeller) ...[
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Street Address *',
                    hintText: '123 Main Street',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Address is required for sellers' : null,
                ),
                const SizedBox(height: 16),
              ],
              
              // City, State, ZIP
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: 'City *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (value) => value?.isEmpty == true ? 'City is required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: InputDecoration(
                        labelText: 'State *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (value) => value?.isEmpty == true ? 'State is required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _zipController,
                      decoration: InputDecoration(
                        labelText: isSeller ? 'ZIP *' : 'ZIP',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      keyboardType: TextInputType.number,
                      validator: isSeller 
                          ? (value) => value?.isEmpty == true ? 'ZIP is required for sellers' : null
                          : null,
                    ),
                  ),
                ],
              ),
              
              // Seller-specific fields
              if (isSeller) ...[
                const SizedBox(height: 16),
                
                // Years in Business
                TextFormField(
                  controller: _yearsInBusinessController,
                  decoration: InputDecoration(
                    labelText: 'Years in Business',
                    hintText: 'How many years have you been in business?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  keyboardType: TextInputType.number,
                ),
                
                const SizedBox(height: 16),
                
                // Specialties
                TextFormField(
                  controller: _specialtiesController,
                  decoration: InputDecoration(
                    labelText: 'Specialties',
                    hintText: 'e.g., Engine parts, Transmission, Brakes',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: 2,
                ),
                
                const SizedBox(height: 16),
                
                // Business Description
                TextFormField(
                  controller: _businessDescriptionController,
                  decoration: InputDecoration(
                    labelText: 'Business Description',
                    hintText: 'Tell buyers about your business...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  maxLines: 3,
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Save Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Complete Profile',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
                          ],
          ),
        ),
      ),
    );
  }
}

class SearchPanel extends StatefulWidget {
  final Function(Map<String, dynamic>) onSearch;
  
  const SearchPanel({super.key, required this.onSearch});

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  final _partName = TextEditingController();
  final _zip = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  
  String _category = 'all';
  String _condition = 'all';
  double _radius = 25.0;
  bool _showAdvanced = false;

  void _onSearch() {
    final zip = _zip.text.trim();
    if (zip.isNotEmpty && (zip.length != 5 || !RegExp(r'^\d{5}$').hasMatch(zip))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 5-digit ZIP code')),
      );
      return;
    }
    
    // Build search filters
    final filters = <String, dynamic>{
      if (zip.isNotEmpty) 'zip': zip,
      if (zip.isNotEmpty) 'radius': _radius,
      if (_partName.text.trim().isNotEmpty) 'part_name': _partName.text.trim(),
      if (_category != 'all') 'category': _category,
      if (_condition != 'all') 'condition': _condition,
      if (_make.text.trim().isNotEmpty) 'make': _make.text.trim(),
      if (_model.text.trim().isNotEmpty) 'model': _model.text.trim(),
      if (_year.text.trim().isNotEmpty) 'year': int.tryParse(_year.text.trim()),
    };
    
    widget.onSearch(filters);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Primary search bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _partName,
                  decoration: InputDecoration(
                    hintText: 'Search parts, vehicles...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onSubmitted: (_) => _onSearch(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _onSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Search'),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Quick filters
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _category,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Categories')),
                    DropdownMenuItem(value: 'vehicle', child: Text('Vehicles')),
                    DropdownMenuItem(value: 'part', child: Text('Parts')),
                  ],
                  onChanged: (value) => setState(() => _category = value!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _condition,
                  decoration: InputDecoration(
                    labelText: 'Condition',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Any Condition')),
                    DropdownMenuItem(value: 'new', child: Text('New')),
                    DropdownMenuItem(value: 'like_new', child: Text('Like New')),
                    DropdownMenuItem(value: 'used', child: Text('Used')),
                    DropdownMenuItem(value: 'fair', child: Text('Fair')),
                    DropdownMenuItem(value: 'salvage', child: Text('Salvage')),
                  ],
                  onChanged: (value) => setState(() => _condition = value!),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Advanced filters toggle
          InkWell(
            onTap: () => setState(() => _showAdvanced = !_showAdvanced),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showAdvanced ? 'Hide Advanced Filters' : 'Show Advanced Filters',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
                Icon(
                  _showAdvanced ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          
          // Advanced filters
          if (_showAdvanced) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            
            // ZIP and radius
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _zip,
                    decoration: InputDecoration(
                      labelText: 'ZIP Code (optional)',
                      hintText: '12345',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Radius: ${_radius.round()} miles'),
                      Slider(
                        value: _radius,
                        min: 5,
                        max: 100,
                        divisions: 19,
                        activeColor: AppColors.primary,
                        onChanged: (value) => setState(() => _radius = value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Vehicle-specific filters
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _make,
                    decoration: InputDecoration(
                      labelText: 'Make (optional)',
                      hintText: 'Toyota, Ford...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _model,
                    decoration: InputDecoration(
                      labelText: 'Model (optional)',
                      hintText: 'Camry, F-150...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _year,
                    decoration: InputDecoration(
                      labelText: 'Year (optional)',
                      hintText: '2020',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// NotificationsPage for viewing notifications
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.neutralDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.neutralDark),
      ),
      body: Container(
        color: const Color(0xFFF8F9FA),
        child: const Center(
          child: Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}

// PromotedProductsPage for viewing all promoted products
class PromotedProductsPage extends StatelessWidget {
  final List<Map<String, dynamic>> listings;

  const PromotedProductsPage({super.key, required this.listings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Promoted Products',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: AppColors.neutralDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.neutralDark),
      ),
      body: Container(
        color: const Color(0xFFF8F9FA),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            int cols;
            if (w < 360) {
              cols = 1;
            } else if (w < 600) {
              cols = 2;
            } else if (w < 900) {
              cols = 3;
            } else {
              cols = 4;
            }
            final aspect = cols == 1 ? 1.1 : 0.85;
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                childAspectRatio: aspect,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: listings.length,
              itemBuilder: (context, index) {
                return PromotedCard(listing: listings[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

// PromotedCard widget for promoted products grid
class PromotedCard extends StatelessWidget {
  final Map<String, dynamic> listing;

  const PromotedCard({super.key, required this.listing});

  String _getImageUrl(Map<String, dynamic> listing) {
    // Check for actual uploaded images in listing_photos
    final photos = listing['listing_photos'] as List?;
    if (photos != null && photos.isNotEmpty) {
      final firstPhoto = photos.first;
      final storagePath = firstPhoto['storage_path'];
      if (storagePath != null) {
        return Supabase.instance.client.storage
            .from('listing-images')
            .getPublicUrl(storagePath);
      }
    }
    
    // Return sample image for demonstration
    return 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400&h=300&fit=crop';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _getImageUrl(listing);
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsPage(listing: listing),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Background Image
              Container(
                width: double.infinity,
                height: double.infinity,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
              
              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
              
              // Content
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing['title'] ?? 'No title',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatPrice(),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice() {
    final raw = listing['price_usd'] ?? listing['price'];
    if (raw is num) {
      final d = raw.toDouble();
      return '\$' + (d % 1 == 0 ? d.toStringAsFixed(0) : d.toStringAsFixed(2));
    }
    final parsed = double.tryParse(raw?.toString() ?? '');
    if (parsed == null) return '\$0';
    return '\$' + (parsed % 1 == 0 ? parsed.toStringAsFixed(0) : parsed.toStringAsFixed(2));
  }
  
  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.primary.withOpacity(0.1),
      child: Center(
        child: Icon(
          Icons.build,
          size: 40,
          color: AppColors.primary.withOpacity(0.5),
        ),
      ),
    );
  }
}

class ListingCard extends StatelessWidget {
  final Map<String, dynamic> listing;

  const ListingCard({super.key, required this.listing});

  String _getImageUrl(Map<String, dynamic> listing) {
    // Check for actual uploaded images in listing_photos
    final photos = listing['listing_photos'] as List?;
    if (photos != null && photos.isNotEmpty) {
      final firstPhoto = photos.first;
      final storagePath = firstPhoto['storage_path'];
      if (storagePath != null) {
        return Supabase.instance.client.storage
            .from('listing-images')
            .getPublicUrl(storagePath);
      }
    }
    
    // Return sample image for demonstration
    return 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400&h=300&fit=crop';
  }

  double _getSellerRating() {
    final ownerId = listing['owner_id'];
    if (ownerId != null && _profileCache.containsKey(ownerId)) {
      final profile = _profileCache[ownerId];
      if (profile != null && profile['rating'] != null) {
        return (profile['rating'] as num).toDouble();
      }
    }
    return 4.2; // Default rating
  }

  String _getSellerName() {
    final ownerId = listing['owner_id'];
    if (ownerId != null && _profileCache.containsKey(ownerId)) {
      final profile = _profileCache[ownerId];
      if (profile != null) {
        final businessName = profile['business_name']?.toString().trim() ?? '';
        final contactPerson = profile['contact_person']?.toString().trim() ?? '';
        
        if (businessName.isNotEmpty) {
          return businessName;
        } else if (contactPerson.isNotEmpty) {
          return contactPerson;
        }
      }
    }
    return 'Verified Seller'; // Default name
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageUrl = _getImageUrl(listing);
        final isCompact = constraints.maxWidth < 200;
        return GestureDetector(
          onTap: () async {
            final id = listing['id'];
            if (id != null) {
              try {
                await Supabase.instance.client
                    .rpc('track_event', params: {'_listing_id': id, '_type': 'click'});
              } catch (_) {}
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailsPage(listing: listing),
              ),
            );
          },
          child: isCompact
              ? _buildCompactCard(context, imageUrl)
              : _buildHorizontalCard(context, imageUrl),
        );
      },
    );
  }

  String _formatPrice() {
    final raw = listing['price'] ?? listing['price_usd'];
    if (raw is num) {
      final d = raw.toDouble();
      return '\$${d % 1 == 0 ? d.toStringAsFixed(0) : d.toStringAsFixed(2)}';
    }
    final parsed = double.tryParse(raw?.toString() ?? '');
    if (parsed == null) return '\$0';
    return '\$${parsed % 1 == 0 ? parsed.toStringAsFixed(0) : parsed.toStringAsFixed(2)}';
  }

  Widget _buildHorizontalCard(BuildContext context, String imageUrl) {
    final sellerRating = _getSellerRating();
    final sellerName = _getSellerName();
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 80,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing['title'] ?? 'No title',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing['condition'] ?? 'used',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatPrice(),
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  // Seller Info
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          sellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                      if (sellerRating > 0) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          sellerRating.toStringAsFixed(1),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Location
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                        SizedBox(width: kIsWeb ? 2 : 4),
                        Text(
                          _getLocationDisplay(listing),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context, String imageUrl) {
    final sellerName = _getSellerName();
    final sellerRating = _getSellerRating();
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top image
          AspectRatio(
            aspectRatio: 16 / 10,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing['title'] ?? 'No title',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  listing['condition'] ?? 'used',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatPrice(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.person, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        sellerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                    if (sellerRating > 0) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.star, size: 12, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        sellerRating.toStringAsFixed(1),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Location
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                    SizedBox(width: kIsWeb ? 2 : 4),
                    Flexible(
                      child: Text(
                        _getLocationDisplay(listing),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Icon(
        Icons.build,
        size: 40,
        color: Colors.grey.shade400,
      ),
    );
  }

  String _getLocationDisplay(Map<String, dynamic> listing) {
    // If distance is available (from location-based search), show distance
    if (listing['distance'] is num) {
      return '${(listing['distance'] as num).toStringAsFixed(1)} mi away';
    }
    
    // Try to get cached profile data
    final ownerId = listing['owner_id'];
    if (ownerId != null && _profileCache.containsKey(ownerId)) {
      final profile = _profileCache[ownerId];
      if (profile != null) {
        final city = profile['city']?.toString().trim() ?? '';
        final state = profile['state']?.toString().trim() ?? '';
        
        if (city.isNotEmpty && state.isNotEmpty) {
          return '$city, $state';
        } else if (city.isNotEmpty) {
          return city;
        } else if (state.isNotEmpty) {
          return state;
        }
      }
    }
    
    // Fallback to ZIP code
    final zipCode = (listing['zip_code'] ?? '').toString().trim();
    if (zipCode.isNotEmpty) {
      return zipCode;
    }
    
    return 'â€”';
  }

  // Cache for profile data - make it global and persistent
  static final Map<String, dynamic> _profileCache = <String, dynamic>{};

  Future<void> _loadProfileData(String ownerId) async {
    if (_profileCache.containsKey(ownerId)) return;
    
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('city, state, business_name, contact_person, rating')
          .eq('id', ownerId)
          .maybeSingle();
      
      _profileCache[ownerId] = response;
    } catch (e) {
      _profileCache[ownerId] = null;
    }
  }
}

class ProductDetailsPage extends StatefulWidget {
  final Map<String, dynamic> listing;

  const ProductDetailsPage({super.key, required this.listing});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  List<String> _imageUrls = [];
  int _currentImageIndex = 0;
  PageController _pageController = PageController();
  Map<String, dynamic>? _sellerProfile;
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _loadSellerProfile();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadImages() {
    // Check for storage paths in listing_photos (actual uploaded images)
    final photos = widget.listing['listing_photos'] as List?;
    if (photos != null && photos.isNotEmpty) {
      _imageUrls = photos.map((photo) {
        final storagePath = photo['storage_path'];
        if (storagePath != null) {
          return Supabase.instance.client.storage
              .from('listing-images')
              .getPublicUrl(storagePath);
        }
        return '';
      }).where((url) => url.isNotEmpty).toList();
      return;
    }
    // If not present on the listing object, fetch from DB using listing_id
    final listingId = widget.listing['id'];
    if (listingId != null) {
      _fetchListingPhotos(listingId);
      return;
    }
    // Fallback to sample imagery if nothing else is available
    _imageUrls = [
      'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&h=600&fit=crop',
      'https://images.unsplash.com/photo-1609521263047-f8f205293f24?w=800&h=600&fit=crop',
    ];
  }

  Future<void> _fetchListingPhotos(dynamic listingId) async {
    try {
      final resp = await Supabase.instance.client
          .from('listing_photos')
          .select('storage_path, sort_order')
          .eq('listing_id', listingId)
          .order('sort_order');
      final photos = List<Map<String, dynamic>>.from(resp ?? []);
      final urls = photos.map((p) {
        final sp = p['storage_path'];
        if (sp != null) {
          return Supabase.instance.client.storage
              .from('listing-images')
              .getPublicUrl(sp);
        }
        return '';
      }).where((u) => u.isNotEmpty).toList();
      if (mounted && urls.isNotEmpty) {
        setState(() {
          _imageUrls = urls;
        });
      }
    } catch (e) {
      // ignore errors and keep fallback
    }
  }

  Future<void> _loadSellerProfile() async {
    try {
      final ownerId = widget.listing['owner_id'];
      if (ownerId != null) {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .eq('id', ownerId)
            .maybeSingle();

        setState(() {
          _sellerProfile = response;
          _loadingProfile = false;
        });
      } else {
        setState(() {
          _loadingProfile = false;
        });
      }
    } catch (e) {
      print('Error loading seller profile: $e');
      setState(() {
        _loadingProfile = false;
      });
    }
  }

  double _getSellerRating() {
    if (_sellerProfile != null && _sellerProfile!['rating'] != null) {
      return (_sellerProfile!['rating'] as num).toDouble();
    }
    return 4.5; // Default rating for demo
  }

  String _getSellerName() {
    if (_sellerProfile != null) {
      final businessName = _sellerProfile!['business_name'];
      final contactPerson = _sellerProfile!['contact_person'];
      if (businessName != null && businessName.isNotEmpty) {
        return businessName;
      } else if (contactPerson != null && contactPerson.isNotEmpty) {
        return contactPerson;
      }
    }
    return 'AutoParts Pro'; // Default seller name for demo
  }

  String _getSellerLocation() {
    if (_sellerProfile != null) {
      final city = _sellerProfile!['city'] ?? '';
      final state = _sellerProfile!['state'] ?? '';
      if (city.isNotEmpty && state.isNotEmpty) {
        return '$city, $state';
      } else if (city.isNotEmpty) {
        return city;
      } else if (state.isNotEmpty) {
        return state;
      }
    }
    return 'Location not specified';
  }


  String _getSellerDescription() {
    if (_sellerProfile != null && _sellerProfile!['business_description'] != null) {
      return _sellerProfile!['business_description'];
    }
    return 'Experienced auto parts seller';
  }

  String _getSellerSpecialties() {
    if (_sellerProfile != null && _sellerProfile!['specialties'] != null) {
      return _sellerProfile!['specialties'];
    }
    return '';
  }

  int _getYearsInBusiness() {
    if (_sellerProfile != null && _sellerProfile!['years_in_business'] != null) {
      return _sellerProfile!['years_in_business'];
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final sellerRating = _getSellerRating();
    final sellerName = _getSellerName();
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Image Gallery
          SliverAppBar(
            expandedHeight: 350,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Main Image Gallery
                  _imageUrls.isNotEmpty
                      ? PageView.builder(
                          controller: _pageController,
                          itemCount: _imageUrls.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentImageIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            final url = _imageUrls[index];
                            if (url.startsWith('http')) {
                              return Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                              );
                            }
                            if (!kIsWeb) {
                              return Image.file(
                                File(url),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(),
                              );
                            }
                            return _buildImagePlaceholder();
                          },
                        )
                      : _buildImagePlaceholder(),
                  
                  // Image Counter
                  if (_imageUrls.length > 1)
                    Positioned(
                      top: 50,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1}/${_imageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  
                  // Navigation Arrows
                  if (_imageUrls.length > 1) ...[
                    // Previous Arrow
                    if (_currentImageIndex > 0)
                      Positioned(
                        left: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    // Next Arrow
                    if (_currentImageIndex < _imageUrls.length - 1)
                      Positioned(
                        right: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                  
                  // Dot Indicators
                  if (_imageUrls.length > 1)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_imageUrls.length, (index) {
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: index == _currentImageIndex ? 12 : 8,
                              height: index == _currentImageIndex ? 12 : 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index == _currentImageIndex
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.5),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Price
                  Text(
                    widget.listing['title'] ?? 'No title',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neutralDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${widget.listing['price_usd']?.toString() ?? '0'}',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Condition and Details
                  _buildDetailRow('Condition', widget.listing['condition'] ?? 'Used'),
                  if (widget.listing['distance'] is num)
                    _buildDetailRow('Distance', '${(widget.listing['distance'] as num).toStringAsFixed(1)} mi'),
                  if (widget.listing['category'] != null)
                    _buildDetailRow('Category', widget.listing['category']),
                  if (widget.listing['make'] != null)
                    _buildDetailRow('Make', widget.listing['make']),
                  if (widget.listing['model'] != null)
                    _buildDetailRow('Model', widget.listing['model']),
                  if (widget.listing['year'] != null)
                    _buildDetailRow('Year', widget.listing['year'].toString()),
                  if (widget.listing['vin'] != null)
                    _buildDetailRow('VIN', widget.listing['vin']),
                  
                  const SizedBox(height: 20),
                  
                  // Description
                  Text(
                    'Description',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.listing['description'] ?? 'No description available.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Seller Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: _loadingProfile
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Seller Information',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.neutralDark,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor: AppColors.primary.withOpacity(0.1),
                                    child: Icon(
                                      Icons.person,
                                      color: AppColors.primary,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sellerName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _getSellerLocation(),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (sellerRating > 0) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              ...List.generate(5, (index) {
                                                return Icon(
                                                  index < sellerRating.floor()
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color: Colors.amber,
                                                  size: 16,
                                                );
                                              }),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${sellerRating.toStringAsFixed(1)} rating',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              // Additional seller details
                              if (_sellerProfile != null) ...[
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 12),
                                
                                // Business description
                                if (_getSellerDescription().isNotEmpty) ...[
                                  Text(
                                    'About the Seller',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.neutralDark,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _getSellerDescription(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                
                                // Years in business and specialties
                                Row(
                                  children: [
                                    if (_getYearsInBusiness() > 0) ...[
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Experience',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              '${_getYearsInBusiness()} years',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.neutralDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                
                                // Specialties
                                if (_getSellerSpecialties().isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Specialties',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _getSellerSpecialties(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.neutralDark,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Chat Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final lid = widget.listing['id'];
                        if (lid != null) {
                          try {
                            await Supabase.instance.client
                                .rpc('track_event', params: {'_listing_id': lid, '_type': 'chat'});
                          } catch (_) {}
                        }
                        _showChatPrompt(context, widget.listing);
                      },
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: Text(
                        'Chat with Seller',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.primary.withOpacity(0.1),
      child: Center(
        child: Icon(
          Icons.build,
          size: 80,
          color: AppColors.primary.withOpacity(0.5),
        ),
      ),
    );
  }

  Future<void> _startChat(BuildContext context) async {
    await _showChatPrompt(context, widget.listing);
  }
}

// Helper functions
Widget _defaultImageWidget(Map<String, dynamic> listing) {
  return Container(
    width: 80,
    height: 80,
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      listing['category'] == 'vehicle' ? Icons.directions_car : Icons.build,
      color: Colors.grey.shade400,
      size: 32,
    ),
  );
}

String _formatPrice(String price) {
  final num = double.tryParse(price) ?? 0;
  if (num >= 1000) {
    return '${(num / 1000).toStringAsFixed(num % 1000 == 0 ? 0 : 1)}k';
  }
  return num.toStringAsFixed(0);
}

Future<void> _showChatPrompt(BuildContext context, Map<String, dynamic> listing) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    // Prompt to sign up/login
    final shouldAuth = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In Required'),
        content: const Text('You need to sign in to contact sellers and buy items.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign In')),
        ],
      ),
    );
    
    if (shouldAuth == true) {
      context.go('/auth');
    }
    return;
  }

  // 
  // Enforce profile completion for buyers before starting chat
  try {
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('profile_completed, user_type')
        .eq('id', user.id)
        .maybeSingle();
    final userType = (profile != null && profile['user_type'] != null)
        ? profile['user_type']
        : (user.userMetadata?['user_type'] ?? 'buyer');
    final completed = profile != null && profile['profile_completed'] == true;
    if (userType == 'buyer' && !completed) {
      final goComplete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete Your Profile'),
          content: const Text('Please complete your profile before contacting sellers.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Complete Profile')),
          ],
        ),
      );
      if (goComplete == true) {
        context.go('/complete-profile');
      }
      return;
    }
  } catch (_) {
    // If profile check fails, conservatively prompt buyer users based on auth metadata
    final metaType = user.userMetadata?['user_type'] ?? 'buyer';
    if (metaType == 'buyer') {
      final goComplete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Complete Your Profile'),
          content: const Text('Please complete your profile before contacting sellers.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Complete Profile')),
          ],
        ),
      );
      if (goComplete == true) {
        context.go('/complete-profile');
      }
      return;
    }
  }
// Check if user is trying to chat with themselves
  if (user.id == listing['owner_id']) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You cannot start a chat with yourself.'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  try {
    // Check if conversation already exists
    final existingConversation = await Supabase.instance.client
        .from('conversations')
        .select('*')
        .eq('buyer_id', user.id)
        .eq('seller_id', listing['owner_id'])
        .eq('listing_id', listing['id'])
        .maybeSingle();

    String conversationId;
    
    if (existingConversation != null) {
      conversationId = existingConversation['id'];
    } else {
      // Create new conversation
      final newConversation = await Supabase.instance.client
          .from('conversations')
          .insert({
            'buyer_id': user.id,
            'seller_id': listing['owner_id'],
            'listing_id': listing['id'],
          })
          .select()
          .single();
      
      conversationId = newConversation['id'];
    }

    // Get seller profile for name
    final sellerProfile = await Supabase.instance.client
        .from('profiles')
        .select('business_name, contact_person')
        .eq('id', listing['owner_id'])
        .maybeSingle();

    String sellerName = 'Seller';
    if (sellerProfile != null) {
      final businessName = sellerProfile['business_name'];
      final contactPerson = sellerProfile['contact_person'];
      if (businessName != null && businessName.isNotEmpty) {
        sellerName = businessName;
      } else if (contactPerson != null && contactPerson.isNotEmpty) {
        sellerName = contactPerson;
      }
    }

    // Navigate to conversation page
    final conversationData = {
      'conversation_id': conversationId,
      'buyer_id': user.id,
      'seller_id': listing['owner_id'],
      'listing_id': listing['id'],
      'listing_title': listing['title'],
      'other_user_name': sellerName,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationPage(conversation: conversationData),
      ),
    );
  } catch (e) {
    print('Error starting chat: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to start chat: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  String _userType = 'buyer'; // buyer or seller

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isSignUp) {
        // Sign up
        final response = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {
            'user_type': _userType,
          },
        );
        
        if (response.user != null) {
          // Sign out the user immediately after signup
          await Supabase.instance.client.auth.signOut();
          
          // Show email confirmation message
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Check Your Email'),
                content: Text(
                  'We\'ve sent a confirmation email to ${_emailController.text.trim()}.\n\n'
                  'Please check your email and click the confirmation link to activate your account.\n\n'
                  'After confirming, you can sign in to complete your profile.',
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/auth');
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      } else {
        // Sign in
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        
        if (mounted) {
          final user = response.user;
          if (user != null) {
            // Check if user has completed profile
            final profileResponse = await Supabase.instance.client
                .from('profiles')
                .select('profile_completed')
                .eq('id', user.id)
                .maybeSingle();
            
            if (profileResponse == null || profileResponse['profile_completed'] != true) {
              // User needs to complete profile
              context.go('/complete-profile');
            } else {
              // User has completed profile, go to home
              context.go('/home');
            }
          }
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }
 
  Future<void> _forgotPassword() async {
    String email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      final ctrl = TextEditingController(text: email);
      final entered = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reset password'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'your@email.com',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Send')),
          ],
        ),
      );
      email = (entered ?? '').trim();
    }
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email to reset your password.')),
      );
      return;
    }
    try {
      setState(() => _loading = true);
      // Use the current URL origin for web, or construct the reset password URL
      String? redirect;
      if (kIsWeb) {
        final origin = Uri.base.origin;
        // Ensure we're using the full URL with the reset-password path
        redirect = '$origin/reset-password';
      }
      await Supabase.instance.client.auth.resetPasswordForEmail(email, redirectTo: redirect);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Check your email'),
          content: Text("If an account exists for $email, we've sent a password reset link."),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reset email: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutralLight,
      appBar: AppBar(
        title: Text(_isSignUp ? 'Create Account' : 'Sign In'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo and title
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.build_circle,
                  size: 50,
                  color: Colors.white,
                ),
              ).animate().scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), duration: 600.ms, curve: Curves.elasticOut),
              
              const SizedBox(height: 24),
              
              Text(
                _isSignUp ? 'Join Mechanic Part' : 'Welcome Back',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralDark,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                _isSignUp 
                    ? 'Create your account to start buying and selling'
                    : 'Sign in to your account',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // User type selection (only for sign up)
              if (_isSignUp) ...[
                Text(
                  'Account Type',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutralDark,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _UserTypeCard(
                        title: 'Buyer',
                        description: 'Browse and purchase parts',
                        icon: Icons.shopping_cart,
                        selected: _userType == 'buyer',
                        onTap: () => setState(() => _userType = 'buyer'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _UserTypeCard(
                        title: 'Seller',
                        description: 'List and sell parts',
                        icon: Icons.store,
                        selected: _userType == 'seller',
                        onTap: () => setState(() => _userType = 'seller'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              
              // Email field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Password field
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (_isSignUp && value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              if (!_isSignUp) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : _forgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
              ],

              if (_isSignUp) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Confirm your password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Submit button
              ElevatedButton(
                onPressed: _loading ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _isSignUp ? 'Create Account' : 'Sign In',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              
              const SizedBox(height: 16),
              
              // Toggle between sign in and sign up
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUp 
                        ? 'Already have an account? '
                        : "Don't have an account? ",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _error = null;
                      });
                      _formKey.currentState?.reset();
                    },
                    child: Text(
                      _isSignUp ? 'Sign In' : 'Sign Up',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTypeCard extends StatelessWidget {
    final String title;
    final String description;
    final IconData icon;
    final bool selected;
    final VoidCallback onTap;

  const _UserTypeCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: selected ? AppColors.primary : Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.neutralDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
// ===== Seller: My Products Page =====
class MyProductsPage extends StatefulWidget {
  const MyProductsPage({super.key});

  @override
  State<MyProductsPage> createState() => _MyProductsPageState();
}

class _MyProductsPageState extends State<MyProductsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _myListings = [];
  // Plan/usage context
  String? _activePlanId;
  int _monthlyBoosts = 0;
  int _boostsUsed = 0;
  int _featuredSlots = 0;
  bool _busyAction = false;

  @override
  void initState() {
    super.initState();
    _loadMyListings();
    _loadPlanAndUsage();
  }

  Future<void> _loadMyListings() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _error = 'Please sign in to view your products';
            _loading = false;
          });
        }
        return;
      }
      final response = await Supabase.instance.client
          .from('listings')
          .select('''
            *,
            listing_photos(storage_path, sort_order)
          ''')
          .eq('owner_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _myListings = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load your listings: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> listing, String status) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) context.go('/auth');
        return;
      }
      // Validate allowed statuses
      const allowed = {'active', 'draft', 'sold'};
      if (!allowed.contains(status)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid status: $status')),
          );
        }
        return;
      }

      final client = Supabase.instance.client;
      // Try RPC first (security definer preferred); fallback to direct update if RPC is missing
      try {
        await client.rpc('update_listing_status', params: {
          '_id': listing['id'],
          '_status': status,
        });
      } catch (e) {
        final msg = e.toString();
        final fnMissing = msg.contains('42883') || msg.contains('function update_listing_status');
        // 42804: datatype mismatch (e.g., enum column vs text param)
        final enumTypeMismatch = msg.contains('42804') || msg.contains('is of type') && msg.contains('but expression is of type');
        if (fnMissing || enumTypeMismatch) {
          await client
              .from('listings')
              .update({'status': status})
              .eq('id', listing['id'])
              .eq('owner_id', user.id);
        } else {
          rethrow;
        }
      }
      await _loadMyListings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Listing status: ${status.toUpperCase()}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  void _openCreateListing() async {
    // Check if profile is completed before allowing listing creation
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('profile_completed')
            .eq('id', user.id)
            .maybeSingle();
        
        final profileCompleted = response?['profile_completed'] ?? false;
        
        if (!profileCompleted) {
          // Show dialog prompting to complete profile
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Complete Your Profile'),
                content: const Text(
                  'You need to complete your seller profile before creating listings. '
                  'This helps build trust with buyers.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Later'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to profile page
                      final homeShell = context.findAncestorStateOfType<_HomeShellState>();
                      if (homeShell != null) {
                        homeShell.switchToTab(3); // Profile tab
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Complete Profile'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      } catch (e) {
        // If error checking profile, still allow listing creation
      }
    }
    
    // Profile is complete or check failed, proceed with listing creation
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Create Listing')),
          body: const ListingForm(),
        ),
      ),
    ).then((_) => _loadMyListings());
  }

  void _openEditListing(Map<String, dynamic> listing) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditListingPage(listing: listing),
      ),
    ).then((_) => _loadMyListings());
  }

  Future<void> _loadPlanAndUsage() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      final prof = await Supabase.instance.client
          .from('profiles')
          .select('active_plan_id')
          .eq('id', user.id)
          .maybeSingle();
      final planId = (prof?['active_plan_id'] as String?) ?? 'free';
      final caps = await Supabase.instance.client
          .from('plan_capabilities')
          .select('monthly_boosts, featured_slots')
          .eq('plan_id', planId)
          .maybeSingle();
      final usage = await Supabase.instance.client
          .from('seller_usage')
          .select('boosts_used, period_start')
          .eq('seller_id', user.id)
          .order('period_start', ascending: false)
          .limit(1)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _activePlanId = planId;
        _monthlyBoosts = (caps?['monthly_boosts'] ?? 0) as int;
        _featuredSlots = (caps?['featured_slots'] ?? 0) as int;
        _boostsUsed = (usage?['boosts_used'] ?? 0) as int;
      });
    } catch (_) {
      // silent
    }
  }

  Future<void> _useBoost(Map<String, dynamic> listing) async {
    if (_busyAction) return;
    setState(() => _busyAction = true);
    try {
      await Supabase.instance.client
          .rpc('use_boost', params: {'_listing_id': listing['id']});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Boost applied')),
        );
      }
      await _loadPlanAndUsage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Boost failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _setFeatured(Map<String, dynamic> listing, bool enabled) async {
    if (_busyAction) return;
    setState(() => _busyAction = true);
    try {
      await Supabase.instance.client
          .rpc('set_featured', params: {'_listing_id': listing['id'], '_enabled': enabled});
      await _loadMyListings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(enabled ? 'Marked as Featured' : 'Removed from Featured')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Feature toggle failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Widget _buildThumb(Map<String, dynamic> listing) {
    final photos = listing['listing_photos'] as List?;
    String? url;
    if (photos != null && photos.isNotEmpty) {
      final storagePath = photos[0]['storage_path'];
      if (storagePath != null) {
        url = Supabase.instance.client.storage
            .from('listing-images')
            .getPublicUrl(storagePath);
      }
    }
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(url, width: 60, height: 60, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.inventory_2, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Products'),
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateListing,
        icon: const Icon(Icons.add),
        label: const Text('Add Listing'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _myListings.isEmpty
                  ? const Center(child: Text('You have not listed any products yet'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _myListings.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final featuredCount = _myListings.where((e) => (e['is_featured'] ?? false) == true).length;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  const Icon(Icons.workspace_premium, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Plan: ${_activePlanId ?? 'free'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text('Boosts: $_boostsUsed / $_monthlyBoosts  •  Featured used: $featuredCount / $_featuredSlots'),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _busyAction ? null : () => _loadPlanAndUsage(),
                                    child: const Text('Refresh'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        final listing = _myListings[index - 1];
                        return ListTile(
                          leading: _buildThumb(listing),
                          title: Text(listing['title'] ?? 'Untitled', maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('Status: ${listing['status'] ?? 'unknown'}  |  USD ${(listing['price_usd'] ?? 0).toString()}'),
                          onTap: () => _openEditListing(listing),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _openEditListing(listing);
                              } else if (value == 'sold') {
                                _updateStatus(listing, 'sold');
                              } else if (value == 'active') {
                                _updateStatus(listing, 'active');
                              } else if (value == 'draft') {
                                _updateStatus(listing, 'draft');
                              } else if (value == 'boost') {
                                _useBoost(listing);
                              } else if (value == 'feature_on') {
                                _setFeatured(listing, true);
                              } else if (value == 'feature_off') {
                                _setFeatured(listing, false);
                              }
                            },
                            itemBuilder: (context) {
                              final items = <PopupMenuEntry<String>>[
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(value: 'sold', child: Text('Mark as Sold')),
                                const PopupMenuItem(value: 'active', child: Text('Mark as Active')),
                                const PopupMenuItem(value: 'draft', child: Text('Mark as Draft')),
                                const PopupMenuDivider(),
                                const PopupMenuItem(value: 'boost', child: Text('Boost (24-72h)')),
                              ];
                              final isFeatured = (listing['is_featured'] ?? false) == true;
                              items.add(
                                PopupMenuItem(
                                  value: isFeatured ? 'feature_off' : 'feature_on',
                                  child: Text(isFeatured ? 'Remove Featured' : 'Mark as Featured'),
                                ),
                              );
                              return items;
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}

class EditListingPage extends StatefulWidget {
  final Map<String, dynamic> listing;
  const EditListingPage({super.key, required this.listing});

  @override
  State<EditListingPage> createState() => _EditListingPageState();
}

class _EditListingPageState extends State<EditListingPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  String _status = 'active';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.listing['title'] ?? '');
    _descriptionController = TextEditingController(text: widget.listing['description'] ?? '');
    _priceController = TextEditingController(text: (widget.listing['price_usd'] ?? '').toString());
    _status = widget.listing['status'] ?? 'active';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _saving = false);
          context.go('/auth');
        }
        return;
      }
      await Supabase.instance.client
          .from('listings')
          .update({
            'title': _titleController.text.trim(),
            'description': _descriptionController.text.trim(),
            'price_usd': double.tryParse(_priceController.text.trim()),
            'status': _status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.listing['id'])
          .eq('owner_id', user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing updated')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Listing'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price (USD)'),
                keyboardType: TextInputType.number,
                validator: (v) => (double.tryParse(v ?? '') == null) ? 'Enter a valid price' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'sold', child: Text('Sold')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'active'),
                decoration: const InputDecoration(labelText: 'Status'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



