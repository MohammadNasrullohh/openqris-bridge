import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qris_bridge/main.dart';
import 'package:qris_bridge/providers/gateway_provider.dart';
import 'package:qris_bridge/services/native_bridge_service.dart';
import 'package:qris_bridge/services/storage_service.dart';

void main() {
  testWidgets('OpenQrisBridgeApp renders main navigation shell', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storageService = await StorageService.init();
    final nativeService = NativeBridgeService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => GatewayProvider(
              storageService: storageService,
              nativeBridgeService: nativeService,
            ),
          ),
        ],
        child: const OpenQrisBridgeApp(),
      ),
    );

    await tester.pump();
    expect(find.text('OpenQris Bridge'), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Kasir'), findsOneWidget);
  });
}
