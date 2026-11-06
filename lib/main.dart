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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _navigateToIndex,
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.border,
          elevation: 0,
          height: 60,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view, size: 18),
              selectedIcon: Icon(Icons.grid_view_rounded, size: 18, color: AppTheme.textPrimary),
              label: 'Console',
            ),
            NavigationDestination(
              icon: Icon(Icons.point_of_sale_outlined, size: 18),
              selectedIcon: Icon(Icons.point_of_sale, size: 18, color: AppTheme.textPrimary),
              label: 'POS',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_outlined, size: 18),
              selectedIcon: Icon(Icons.receipt, size: 18, color: AppTheme.textPrimary),
              label: 'Ledger',
            ),
            NavigationDestination(
              icon: Icon(Icons.terminal_outlined, size: 18),
              selectedIcon: Icon(Icons.terminal, size: 18, color: AppTheme.textPrimary),
              label: 'Bench',
            ),
            NavigationDestination(
              icon: Icon(Icons.stream_outlined, size: 18),
              selectedIcon: Icon(Icons.stream, size: 18, color: AppTheme.textPrimary),
              label: 'Stream',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined, size: 18),
              selectedIcon: Icon(Icons.tune, size: 18, color: AppTheme.textPrimary),
              label: 'Config',
            ),
          ],
        ),
      ),
    );
  }
}
