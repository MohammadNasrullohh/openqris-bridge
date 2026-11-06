import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/gateway_provider.dart';
import 'services/native_bridge_service.dart';
import 'services/storage_service.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/invoices_screen.dart';
import 'ui/screens/mutations_screen.dart';
import 'ui/screens/pos_cashier_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/simulator_screen.dart';
import 'ui/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = await StorageService.init();
  final nativeBridgeService = NativeBridgeService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => GatewayProvider(
            storageService: storageService,
            nativeBridgeService: nativeBridgeService,
          ),
        ),
      ],
      child: const OpenQrisBridgeApp(),
    ),
  );
}

class OpenQrisBridgeApp extends StatelessWidget {
  const OpenQrisBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenQris Bridge',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  void _navigateToIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardScreen(onNavigate: _navigateToIndex),
      const PosCashierScreen(),
      const InvoicesScreen(),
      const SimulatorScreen(),
      const MutationsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex > 4 ? 4 : _currentIndex,
        onDestinationSelected: _navigateToIndex,
        backgroundColor: AppTheme.surfaceDark,
        indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primaryColor),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale_rounded, color: AppTheme.primaryColor),
            label: 'Kasir',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: AppTheme.primaryColor),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science_rounded, color: AppTheme.primaryColor),
            label: 'Simulator',
          ),
          NavigationDestination(
            icon: Icon(Icons.sync_alt_outlined),
            selectedIcon: Icon(Icons.sync_alt_rounded, color: AppTheme.primaryColor),
            label: 'Mutasi',
          ),
        ],
      ),
    );
  }
}
