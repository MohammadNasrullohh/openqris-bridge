import 'dart:async';
import 'package:uuid/uuid.dart';
import '../emvco/qris_converter.dart';
import '../models/invoice.dart';
import '../models/payment_mutation.dart';
import 'unique_code_allocator.dart';

typedef InvoiceCallback = void Function(Invoice invoice);
typedef MutationCallback = void Function(PaymentMutation mutation);

/// Manages invoice lifecycle, unique code assignment, expiration, and mutation matching.
class InvoiceManager {
  final Map<String, Invoice> _invoices = {};
  final List<PaymentMutation> _mutations = [];
  final UniqueCodeAllocator allocator;
  Timer? _expirationTimer;

  // Event callbacks
  final List<InvoiceCallback> _onCreatedListeners = [];
  final List<InvoiceCallback> _onPaidListeners = [];
  final List<InvoiceCallback> _onExpiredListeners = [];
  final List<MutationCallback> _onMutationListeners = [];

  static const _uuid = Uuid();

  InvoiceManager({
    UniqueCodeAllocator? allocator,
  }) : allocator = allocator ?? UniqueCodeAllocator() {
    _startExpirationWatcher();
  }

  void addOnCreatedListener(InvoiceCallback listener) => _onCreatedListeners.add(listener);
  void addOnPaidListener(InvoiceCallback listener) => _onPaidListeners.add(listener);
  void addOnExpiredListener(InvoiceCallback listener) => _onExpiredListeners.add(listener);
  void addOnMutationListener(MutationCallback listener) => _onMutationListeners.add(listener);

  void removeOnPaidListener(InvoiceCallback listener) => _onPaidListeners.remove(listener);

  List<Invoice> get allInvoices => _invoices.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Invoice> get pendingInvoices =>
      _invoices.values.where((i) => i.isPending).toList();

  List<PaymentMutation> get allMutations => List.unmodifiable(_mutations.reversed);

  Invoice? getInvoice(String id) => _invoices[id];

  /// Set of active payable totals currently reserved by pending invoices
  Set<double> get activePayableTotals => _invoices.values
      .where((i) => i.isPending)
      .map((i) => i.totalAmount)
      .toSet();

  /// Creates a new invoice with an allocated unique code and dynamic QRIS string.
  Invoice createInvoice({
    required double baseAmount,
    required String staticQris,
    String? referenceId,
    int expiryMinutes = 15,
    Map<String, dynamic> metadata = const {},
  }) {
    final now = DateTime.now();
    final invoiceId = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${_uuid.v4().substring(0, 6).toUpperCase()}';

    // 1. Allocate unique code
    final uniqueCode = allocator.allocate(
      baseAmount: baseAmount,
      existingActiveTotals: activePayableTotals,
    );

    final totalAmount = baseAmount + uniqueCode;

    // 2. Generate Dynamic QRIS with exact total amount
    String dynamicQris = '';
    if (staticQris.trim().isNotEmpty) {
      try {
        dynamicQris = QrisConverter.convertToDynamic(
          staticQris: staticQris,
          amount: totalAmount,
          invoiceNumber: invoiceId,
        );
      } catch (_) {
        dynamicQris = staticQris; // Fallback to static if conversion error
      }
    }

    final invoice = Invoice(
      id: invoiceId,
      referenceId: referenceId,
      baseAmount: baseAmount,
      uniqueCode: uniqueCode,
      totalAmount: totalAmount,
      qrisRaw: dynamicQris,
      status: InvoiceStatus.pending,
      createdAt: now,
      expiresAt: now.add(Duration(minutes: expiryMinutes)),
      metadata: metadata,
    );

    _invoices[invoiceId] = invoice;

    for (final listener in _onCreatedListeners) {
      listener(invoice);
    }

    return invoice;
  }

  /// Ingests a new incoming financial mutation and matches it against pending invoices.
  Invoice? processIncomingMutation(PaymentMutation mutation) {
    _mutations.add(mutation);

    for (final listener in _onMutationListeners) {
      listener(mutation);
    }

    // Match against pending invoices by exact total amount
    final matchCandidates = _invoices.values.where((inv) {
      if (!inv.isPending) return false;
      return (inv.totalAmount - mutation.amount).abs() < 0.01;
    }).toList();

    if (matchCandidates.isEmpty) {
      return null;
    }

    // If multiple matches exist, pick the oldest pending invoice
    matchCandidates.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final matchedInvoice = matchCandidates.first;

    // Update invoice to PAID
    final paidInvoice = matchedInvoice.copyWith(
      status: InvoiceStatus.paid,
      paidAt: DateTime.now(),
      matchedMutationId: mutation.id,
    );
    _invoices[matchedInvoice.id] = paidInvoice;

    // Update mutation to matched
    final mutationIndex = _mutations.indexWhere((m) => m.id == mutation.id);
    if (mutationIndex != -1) {
      _mutations[mutationIndex] = mutation.copyWith(
        isMatched: true,
        matchedInvoiceId: paidInvoice.id,
      );
    }

    for (final listener in _onPaidListeners) {
      listener(paidInvoice);
    }

    return paidInvoice;
  }

  /// Manually reconciles an invoice with a mutation
  bool manualMatch({required String invoiceId, required String mutationId}) {
    final invoice = _invoices[invoiceId];
    final mutationIdx = _mutations.indexWhere((m) => m.id == mutationId);
    if (invoice == null || mutationIdx == -1) return false;

    final mutation = _mutations[mutationIdx];
    final paidInvoice = invoice.copyWith(
      status: InvoiceStatus.paid,
      paidAt: DateTime.now(),
      matchedMutationId: mutation.id,
    );
    _invoices[invoiceId] = paidInvoice;

    _mutations[mutationIdx] = mutation.copyWith(
      isMatched: true,
      matchedInvoiceId: invoiceId,
    );

    for (final listener in _onPaidListeners) {
      listener(paidInvoice);
    }

    return true;
  }

  /// Cancels a pending invoice
  bool cancelInvoice(String invoiceId) {
    final invoice = _invoices[invoiceId];
    if (invoice == null || !invoice.isPending) return false;

    _invoices[invoiceId] = invoice.copyWith(status: InvoiceStatus.cancelled);
    return true;
  }

  /// Checks for expired pending invoices
  void checkExpirations() {
    final now = DateTime.now();
    for (final entry in _invoices.entries) {
      final inv = entry.value;
      if (inv.isPending && now.isAfter(inv.expiresAt)) {
        final expiredInv = inv.copyWith(status: InvoiceStatus.expired);
        _invoices[entry.key] = expiredInv;
        for (final listener in _onExpiredListeners) {
          listener(expiredInv);
        }
      }
    }
  }

  void _startExpirationWatcher() {
    _expirationTimer?.cancel();
    _expirationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      checkExpirations();
    });
  }

  void dispose() {
    _expirationTimer?.cancel();
  }
}
