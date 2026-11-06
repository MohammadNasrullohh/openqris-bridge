/// Indonesian Payment & E-Wallet Providers supported out of the box.
enum ProviderType {
  dana('DANA', 'id.dana', 'DANA E-Wallet'),
  shopeePay('ShopeePay', 'com.shopee.id', 'Shopee / ShopeePay'),
  goPay('GoPay', 'com.gojek.app', 'GoPay / GoBiz Merchant'),
  ovo('OVO', 'ovo.id', 'OVO E-Wallet'),
  bca('BCA', 'com.bca', 'BCA Mobile / myBCA'),
  mandiri('Mandiri', 'id.co.bankmandiri.livin', 'Livin\' by Mandiri'),
  bri('BRI', 'id.co.bri.brimo', 'BRImo'),
  seabank('SeaBank', 'com.seabank.id', 'SeaBank'),
  generic('Custom', 'custom.bridge', 'Custom Provider / SMS');

  final String displayName;
  final String packageName;
  final String description;

  const ProviderType(this.displayName, this.packageName, this.description);

  /// Find provider by package name or display name
  static ProviderType fromPackageOrName(String identifier) {
    final lower = identifier.toLowerCase();
    for (final p in ProviderType.values) {
      if (lower.contains(p.packageName.toLowerCase()) ||
          lower.contains(p.displayName.toLowerCase())) {
        return p;
      }
    }
    return ProviderType.generic;
  }
}
