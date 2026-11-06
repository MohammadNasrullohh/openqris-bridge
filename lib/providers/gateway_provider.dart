import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/manager/invoice_manager.dart';
import '../core/manager/unique_code_allocator.dart';
import '../core/models/invoice.dart';
import '../core/models/payment_mutation.dart';
import '../core/parsers/notification_parser_registry.dart';
import '../core/server/bridge_server.dart';
import '../services/native_bridge_service.dart';
import '../services/storage_service.dart';
import '../services/webhook_dispatcher.dart';

class GatewayProvider extends ChangeNotifier {
  final StorageService storageService;
  final NativeBridgeService nativeBridgeService;

  late GatewayConfig config;
  late UniqueCodeAllocator uniqueCodeAllocator;
  late InvoiceManager invoiceManager;
  late NotificationParserRegistry parserRegistry;
  late WebhookDispatcher webhookDispatcher;
  BridgeServer? bridgeServer;

  bool isListenerPermissionGranted = false;
  bool isForegroundServiceRunning = false;
  bool isServerRunning = false;
  int? activeServerPort;
  String? localIpAddress;

  StreamSubscription? _nativeNotificationSub;

  GatewayProvider({
    required this.storageService,
    required this.nativeBridgeService,
  }) {
    _init();
  }

  Future<void> _init() async {
    config = storageService.loadConfig();

    // 1. Initialize Allocator
    uniqueCodeAllocator = UniqueCodeAllocator(
      strategy: config.uniqueCodeStrategy,
      minCode: config.minUniqueCode,
      maxCode: config.maxUniqueCode,
    );

    // 2. Initialize Invoice Manager
    invoiceManager = InvoiceManager(allocator: uniqueCodeAllocator);

    // 3. Initialize Parsers
    parserRegistry = NotificationParserRegistry();
    if (config.customRules.isNotEmpty) {
      parserRegistry.setCustomRules(config.customRules);
    }

    // 4. Initialize Webhook Dispatcher
    webhookDispatcher = WebhookDispatcher(
      webhookUrl: config.webhookUrl,
      secretKey: config.webhookSecretKey,
      isEnabled: config.webhookEnabled,
    );

    // 5. Connect Paid listener to Webhook Dispatcher
    invoiceManager.addOnPaidListener((invoice) {
      PaymentMutation? mutation;
      if (invoice.matchedMutationId != null) {
        final matches = invoiceManager.allMutations
            .where((m) => m.id == invoice.matchedMutationId)
            .toList();
        if (matches.isNotEmpty) {
          mutation = matches.first;
        }
      }
      webhookDispatcher.dispatchInvoicePaid(
        invoice: invoice,
        mutation: mutation,
      );
      notifyListeners();
    });

    invoiceManager.addOnCreatedListener((_) => notifyListeners());
    invoiceManager.addOnExpiredListener((_) => notifyListeners());
    invoiceManager.addOnMutationListener((_) => notifyListeners());

    // 6. Check Android permission
    await checkPermission();

    // 7. Subscribe to Native Notifications
    _listenToNativeNotifications();

    // 8. Start embedded server if enabled
    if (config.serverEnabled) {
      await startServer();
    }

    notifyListeners();
  }

  void _listenToNativeNotifications() {
    _nativeNotificationSub?.cancel();
    _nativeNotificationSub = nativeBridgeService.notificationStream.listen(
      (data) {
        final packageName = data['package_name'] as String? ?? '';
        final title = data['title'] as String? ?? '';
        final message = data['message'] as String? ?? '';
        final timestampMs = data['timestamp'] as num?;
        final timestamp = timestampMs != null
            ? DateTime.fromMillisecondsSinceEpoch(timestampMs.toInt())
            : DateTime.now();

        final mutation = parserRegistry.parseNotification(
          packageName: packageName,
          title: title,
          message: message,
          timestamp: timestamp,
        );

        if (mutation != null) {
          // Check if provider is enabled
          final isEnabled = config.enabledProviders.contains(mutation.provider.displayName);
          if (isEnabled) {
            invoiceManager.processIncomingMutation(mutation);
            notifyListeners();
          }
        }
      },
      onError: (err) {
        debugPrint('Error in notification stream: $err');
      },
    );
  }

  Future<void> checkPermission() async {
    isListenerPermissionGranted =
        await nativeBridgeService.isNotificationPermissionGranted();
    notifyListeners();
  }

  Future<void> requestPermission() async {
    await nativeBridgeService.openPermissionSettings();
    await Future.delayed(const Duration(seconds: 1));
    await checkPermission();
  }

  Future<void> toggleForegroundService() async {
    if (isForegroundServiceRunning) {
      await nativeBridgeService.stopForegroundService();
      isForegroundServiceRunning = false;
    } else {
      final success = await nativeBridgeService.startForegroundService();
      isForegroundServiceRunning = success;
    }
    notifyListeners();
  }

  /// Start or restart embedded HTTP/WebSocket server
  Future<void> startServer() async {
    await stopServer();
    bridgeServer = BridgeServer(
      invoiceManager: invoiceManager,
      parserRegistry: parserRegistry,
      getStaticQris: () => config.staticQris,
      port: config.serverPort,
    );
    try {
      activeServerPort = await bridgeServer!.start();
      isServerRunning = true;
    } catch (e) {
      debugPrint('Failed to start bridge server: $e');
      isServerRunning = false;
    }
    notifyListeners();
  }

  Future<void> stopServer() async {
    if (bridgeServer != null) {
      await bridgeServer!.stop();
      bridgeServer = null;
      isServerRunning = false;
      activeServerPort = null;
      notifyListeners();
    }
  }

  /// Creates a manual or POS invoice
  Invoice createInvoice({
    required double baseAmount,
    String? referenceId,
    int? expiryMinutes,
  }) {
    final invoice = invoiceManager.createInvoice(
      baseAmount: baseAmount,
      staticQris: config.staticQris,
      referenceId: referenceId,
      expiryMinutes: expiryMinutes ?? config.invoiceExpiryMinutes,
    );
    notifyListeners();
    return invoice;
  }

  /// Ingests a simulated payment notification for development & testing
  Invoice? simulateIncomingNotification({
    required String packageName,
    required String title,
    required String message,
  }) {
    final mutation = parserRegistry.parseNotification(
      packageName: packageName,
      title: title,
      message: message,
    );

    if (mutation != null) {
      final matched = invoiceManager.processIncomingMutation(mutation);
      notifyListeners();
      return matched;
    }
    return null;
  }

  /// Updates configuration and saves to persistent storage
  Future<void> updateConfig(GatewayConfig newConfig) async {
    config = newConfig;
    await storageService.saveConfig(config);

    // Update dependencies
    uniqueCodeAllocator = UniqueCodeAllocator(
      strategy: config.uniqueCodeStrategy,
      minCode: config.minUniqueCode,
      maxCode: config.maxUniqueCode,
    );

    webhookDispatcher.webhookUrl = config.webhookUrl;
    webhookDispatcher.secretKey = config.webhookSecretKey;
    webhookDispatcher.isEnabled = config.webhookEnabled;

    parserRegistry.setCustomRules(config.customRules);

    if (config.serverEnabled && !isServerRunning) {
      await startServer();
    } else if (!config.serverEnabled && isServerRunning) {
      await stopServer();
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _nativeNotificationSub?.cancel();
    invoiceManager.dispose();
    bridgeServer?.stop();
    super.dispose();
  }
}
