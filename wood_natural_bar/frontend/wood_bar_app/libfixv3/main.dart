import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'core/theme/app_theme.dart';
import 'core/network/app_router.dart';
import 'presentation/providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep screen on for POS use
  await WakelockPlus.enable();

  // Allow landscape for tablets
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  // Initialize local storage
  await Hive.initFlutter();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const WoodBarApp(),
    ),
  );
}

class WoodBarApp extends ConsumerWidget {
  const WoodBarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final branding = ref.watch(brandingProvider);

    // Update theme colors from server branding
    branding.whenData((b) {
      AppColors.primary = b.primaryColorValue;
      AppColors.accent = b.accentColorValue;
    });

    return MaterialApp.router(
      title: branding.whenData((b) => b.restaurantName).value ?? 'Wood Natural Bar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
