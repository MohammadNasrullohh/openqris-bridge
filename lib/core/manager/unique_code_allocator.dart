import 'dart:math';

enum UniqueCodeStrategy {
  random('Random (1 - 999)'),
  sequential('Sequential (+1, +2, +3...)'),
  discount('Discount (-1 to -999)'),
  none('None (Exact Amount)');

  final String label;
  const UniqueCodeStrategy(this.label);
}

/// Allocates non-colliding unique codes for pending transactions.
class UniqueCodeAllocator {
  final UniqueCodeStrategy strategy;
  final int minCode;
  final int maxCode;
  int _lastSequential = 0;
  final Random _random = Random();

  UniqueCodeAllocator({
    this.strategy = UniqueCodeStrategy.random,
    this.minCode = 1,
    this.maxCode = 999,
  });

  /// Allocates a unique code for [baseAmount] ensuring [baseAmount + code] does not
  /// collide with any [existingActiveTotals].
  int allocate({
    required double baseAmount,
    required Set<double> existingActiveTotals,
  }) {
    if (strategy == UniqueCodeStrategy.none) {
      return 0;
    }

    final maxAttempts = (maxCode - minCode + 1).clamp(10, 1000);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final code = _generateCandidate();
      final total = baseAmount + (strategy == UniqueCodeStrategy.discount ? -code : code);

      if (!existingActiveTotals.contains(total)) {
        return strategy == UniqueCodeStrategy.discount ? -code : code;
      }
    }

    // Fallback: incremental scan from minCode upwards
    for (int code = minCode; code <= maxCode; code++) {
      final effectiveCode = strategy == UniqueCodeStrategy.discount ? -code : code;
      final total = baseAmount + effectiveCode;
      if (!existingActiveTotals.contains(total)) {
        return effectiveCode;
      }
    }

    // Ultimate fallback: random code
    return _random.nextInt(maxCode - minCode + 1) + minCode;
  }

  int _generateCandidate() {
    switch (strategy) {
      case UniqueCodeStrategy.random:
      case UniqueCodeStrategy.discount:
        return _random.nextInt(maxCode - minCode + 1) + minCode;
      case UniqueCodeStrategy.sequential:
        if (_lastSequential < minCode || _lastSequential >= maxCode) {
          _lastSequential = minCode;
        } else {
          _lastSequential += 1;
        }
        return _lastSequential;
      case UniqueCodeStrategy.none:
        return 0;
    }
  }
}
