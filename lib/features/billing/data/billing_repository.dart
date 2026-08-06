import 'dart:async';

import 'package:purchases_flutter/purchases_flutter.dart';

import '../domain/billing_models.dart';
import '../domain/product_ids.dart';
import 'billing_config.dart';

/// Wraps `purchases_flutter` (RevenueCat) so the rest of the app never talks
/// to the SDK directly. Offerings are returned using RevenueCat's own
/// [Offerings]/[Package]/[StoreProduct] types (they already carry formatted,
/// localized prices, which the paywall screen needs) — but purchase and
/// entitlement *events* are mapped to this feature's own [PurchaseEvent] /
/// [PremiumStatus] models before being exposed, so [PurchaseEventHandler]
/// and [AdPolicy] never need to import purchases_flutter at all.
abstract class BillingRepository {
  /// Initializes the RevenueCat SDK. Call once at app start (before
  /// [identify]). No-ops if [BillingConfig.revenueCatApiKey] hasn't been
  /// supplied, so the app can still build and run before the PM has
  /// provisioned RevenueCat.
  Future<void> configure();

  /// Identifies the RevenueCat customer as [uid] — the same `user_id`
  /// Agent A's Firebase Auth issues (spec 8.3: "Agent Aが発行するuser_idに
  /// 紐づけてRevenueCat上の顧客IDを管理"). Call this once, right after
  /// Firebase sign-in resolves. This repository never reaches into
  /// features/auth itself; the app-shell is expected to call this from its
  /// auth-state listener.
  Future<void> logIn(String uid);

  /// Clears the RevenueCat identity on sign-out (reverts to an anonymous id).
  Future<void> logOut();

  /// Current RevenueCat offerings (products/prices for the paywall screen).
  Future<Offerings> getOfferings();

  /// Purchases the package identified by [packageIdentifier] (a
  /// [Package.identifier] from [getOfferings], e.g. `$rc_monthly` or a
  /// custom identifier configured in the dashboard). Throws if the package
  /// can't be found in the current offerings, or whatever
  /// [Purchases.purchasePackage] throws (including user cancellation).
  Future<void> purchase(String packageIdentifier);

  Future<void> restorePurchases();

  /// Last-known premium status. [PremiumStatus.unknown] until the first
  /// CustomerInfo snapshot has been received.
  PremiumStatus get currentPremiumStatus;

  /// Emits every time [currentPremiumStatus] changes (including the initial
  /// snapshot once RevenueCat delivers it).
  Stream<PremiumStatus> premiumStatusChanges();

  /// Emits one [PurchaseEvent] per credit-worthy purchase/entitlement
  /// change, for [PurchaseEventHandler] to consume.
  Stream<PurchaseEvent> purchaseEvents();

  /// Releases the RevenueCat listener and closes internal streams.
  void dispose();
}

class RevenueCatBillingRepository implements BillingRepository {
  RevenueCatBillingRepository();

  final StreamController<PremiumStatus> _premiumStatusController =
      StreamController<PremiumStatus>.broadcast();
  final StreamController<PurchaseEvent> _purchaseEventController =
      StreamController<PurchaseEvent>.broadcast();

  PremiumStatus _lastPremiumStatus = PremiumStatus.unknown;
  bool _listenerAttached = false;

  @override
  Future<void> configure() async {
    if (!BillingConfig.isConfigured) {
      // RevenueCat API key not supplied yet — leave the SDK unconfigured.
      // Every other method below already no-ops or is simply never called
      // by app-shell code guarded on BillingConfig.isConfigured.
      return;
    }
    await Purchases.setLogLevel(LogLevel.warn);
    await Purchases.configure(
      PurchasesConfiguration(BillingConfig.revenueCatApiKey),
    );
    if (!_listenerAttached) {
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdate);
      _listenerAttached = true;
    }
  }

  @override
  Future<void> logIn(String uid) async {
    if (!BillingConfig.isConfigured) return;
    await Purchases.logIn(uid);
    final customerInfo = await Purchases.getCustomerInfo();
    _onCustomerInfoUpdate(customerInfo);
  }

  @override
  Future<void> logOut() async {
    if (!BillingConfig.isConfigured) return;
    await Purchases.logOut();
    _lastPremiumStatus = PremiumStatus.unknown;
  }

  @override
  Future<Offerings> getOfferings() => Purchases.getOfferings();

  @override
  Future<void> purchase(String packageIdentifier) async {
    final offerings = await Purchases.getOfferings();
    final package = _findPackage(offerings, packageIdentifier);
    if (package == null) {
      throw StateError(
        'Package "$packageIdentifier" was not found in the current '
        'RevenueCat offerings. Has it been configured in the RevenueCat '
        'dashboard yet?',
      );
    }
    // purchases_flutter 10 wraps the response: purchasePackage now returns a
    // PurchaseResult (customerInfo + the store transaction) instead of the
    // CustomerInfo directly.
    final result = await Purchases.purchasePackage(package);
    _onCustomerInfoUpdate(result.customerInfo);

    // Consumables (ai_tickets_5/15) aren't modeled as entitlements at all in
    // RevenueCat, so a CustomerInfo diff would never surface them — we know
    // what was just bought because we initiated the purchase ourselves.
    final productId = package.storeProduct.identifier;
    if (ProductIds.consumables.contains(productId)) {
      _purchaseEventController.add(ConsumableProductPurchased(productId));
    }
  }

  Package? _findPackage(Offerings offerings, String packageIdentifier) {
    for (final offering in offerings.all.values) {
      final match = offering.getPackage(packageIdentifier);
      if (match != null) return match;
    }
    return null;
  }

  @override
  Future<void> restorePurchases() async {
    final customerInfo = await Purchases.restorePurchases();
    _onCustomerInfoUpdate(customerInfo);
  }

  @override
  PremiumStatus get currentPremiumStatus => _lastPremiumStatus;

  @override
  Stream<PremiumStatus> premiumStatusChanges() =>
      _premiumStatusController.stream;

  @override
  Stream<PurchaseEvent> purchaseEvents() => _purchaseEventController.stream;

  void _onCustomerInfoUpdate(CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.all[EntitlementIds.premium];
    final isActive = entitlement?.isActive ?? false;
    final newStatus = isActive ? PremiumStatus.active : PremiumStatus.inactive;
    final changed = newStatus != _lastPremiumStatus;
    _lastPremiumStatus = newStatus;
    _premiumStatusController.add(newStatus);
    if (changed) {
      _purchaseEventController.add(
        EntitlementStateChanged(
          entitlementId: EntitlementIds.premium,
          isActive: isActive,
        ),
      );
    }
  }

  @override
  void dispose() {
    if (_listenerAttached) {
      Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdate);
    }
    _premiumStatusController.close();
    _purchaseEventController.close();
  }
}
