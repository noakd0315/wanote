import 'dart:async';
import 'dart:developer' as developer;

import 'package:purchases_flutter/purchases_flutter.dart';

import '../domain/billing_models.dart';
import '../domain/product_ids.dart';
import 'billing_backend_client.dart';
import 'billing_config.dart';
import '../../../shared/config/app_config.dart';

/// Wraps `purchases_flutter` (RevenueCat) so the rest of the app never talks
/// to the SDK directly. Offerings are returned using RevenueCat's own
/// [Offerings]/[Package]/[StoreProduct] types (they already carry formatted,
/// localized prices, which the paywall screen needs) — but purchase and
/// entitlement *events* are mapped to this feature's own [PurchaseEvent] /
/// [PremiumStatus] models before being exposed, so [PurchaseEventHandler]
/// and [AdPolicy] never need to import purchases_flutter at all.
/// Thrown when the paywall is opened before RevenueCat has been provisioned.
///
/// This exists so the failure arrives as a *Dart* error. Reaching into the
/// SDK unconfigured is not a catchable exception on iOS -- RevenueCat's
/// Swift layer calls `fatalError` on `Purchases.shared`, which kills the
/// process before any Dart handler runs. The paywall crashed on the PM's
/// iPhone for exactly this reason (PM report, 2026-08-17): the app is built
/// without a RevenueCat key today, so `configure()` returned early and the
/// three methods below still called the SDK.
class BillingNotConfiguredException implements Exception {
  const BillingNotConfiguredException();

  @override
  String toString() =>
      'BillingNotConfiguredException: RevenueCat has no API key in this '
      'build, so the store cannot be reached.';
}

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
  /// [Purchases.purchase] throws (including user cancellation).
  Future<void> purchase(String packageIdentifier);

  Future<void> restorePurchases();

  /// Re-reads the entitlement state from RevenueCat.
  ///
  /// The SDK only learns about a purchase it made itself. A promotional
  /// entitlement granted server-side -- which is how a campaign or referral
  /// code delivers its free month -- arrives nowhere until something asks.
  /// Until then the app still believes the account is not premium: it shows
  /// ads, and the report screen stays locked, while the free month is
  /// already running (PM report, 2026-08-21).
  ///
  /// Not [restorePurchases]: that means "find purchases made on another
  /// device" and on iOS can prompt for an Apple Account password. This only
  /// re-reads what RevenueCat already holds.
  Future<void> refreshCustomerInfo();

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
  RevenueCatBillingRepository({BillingBackendClient? backendClient})
    : _backendClient = backendClient ?? BillingBackendClient.fromEnvironment();

  final BillingBackendClient _backendClient;

  final StreamController<PremiumStatus> _premiumStatusController =
      StreamController<PremiumStatus>.broadcast();
  final StreamController<PurchaseEvent> _purchaseEventController =
      StreamController<PurchaseEvent>.broadcast();

  PremiumStatus _lastPremiumStatus = PremiumStatus.unknown;
  bool _listenerAttached = false;

  @override
  Future<void> configure() async {
    // Debug-only override, so the unlocked behaviour can be seen before
    // there is a store to buy anything in. See AppConfig.pretendPremium --
    // it is inert in release builds.
    if (AppConfig.pretendPremium) {
      _lastPremiumStatus = PremiumStatus.active;
      _premiumStatusController.add(PremiumStatus.active);
      return;
    }
    if (!BillingConfig.isConfigured) {
      // RevenueCat API key not supplied yet — leave the SDK unconfigured.
      // Every other method below already no-ops or is simply never called
      // by app-shell code guarded on BillingConfig.isConfigured.
      //
      // Report "not premium" rather than "unknown". Unknown means an answer
      // is still coming; here there is no question outstanding, because with
      // no billing system nobody can hold an entitlement at all. Leaving it
      // unknown is not merely imprecise -- AdPolicy withholds ads until
      // premium status is *confirmed* inactive, so an app built without a
      // RevenueCat key would show no ads ever, and there would be no way to
      // check the ad wiring on a device before billing exists.
      _lastPremiumStatus = PremiumStatus.inactive;
      _premiumStatusController.add(PremiumStatus.inactive);
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
  Future<void> refreshCustomerInfo() async {
    if (!BillingConfig.isConfigured) return;
    // Invalidated first. getCustomerInfo() answers from the SDK's cache,
    // which was filled at logIn -- before the server granted anything -- so
    // asking without this returns the very state we are trying to replace
    // and nothing appears to have changed (PM report, 2026-08-21: the free
    // allowance was still being spent after a code was applied).
    await Purchases.invalidateCustomerInfoCache();
    _onCustomerInfoUpdate(await Purchases.getCustomerInfo());
  }

  @override
  Future<void> logOut() async {
    if (!BillingConfig.isConfigured) return;
    await Purchases.logOut();
    _lastPremiumStatus = PremiumStatus.unknown;
  }

  /// Guards every call that reaches into the SDK. See
  /// [BillingNotConfiguredException] -- on iOS an unconfigured call is a
  /// process kill, not an exception, so this has to happen before the SDK
  /// is touched rather than in a `catch` around it.
  void _requireConfigured() {
    if (!BillingConfig.isConfigured) {
      throw const BillingNotConfiguredException();
    }
  }

  @override
  Future<Offerings> getOfferings() async {
    _requireConfigured();
    return Purchases.getOfferings();
  }

  @override
  Future<void> purchase(String packageIdentifier) async {
    _requireConfigured();
    final offerings = await Purchases.getOfferings();
    final package = _findPackage(offerings, packageIdentifier);
    if (package == null) {
      throw StateError(
        'Package "$packageIdentifier" was not found in the current '
        'RevenueCat offerings. Has it been configured in the RevenueCat '
        'dashboard yet?',
      );
    }
    // purchases_flutter 10 replaced purchasePackage() with purchase() taking
    // a PurchaseParams, and wraps the response: a PurchaseResult
    // (customerInfo + the store transaction) instead of the CustomerInfo
    // directly.
    final result = await Purchases.purchase(PurchaseParams.package(package));
    _onCustomerInfoUpdate(result.customerInfo);

    // Consumables (ai_tickets_5/15) aren't modeled as entitlements at all in
    // RevenueCat, so a CustomerInfo diff would never surface them — we know
    // what was just bought because we initiated the purchase ourselves.
    // Normalised before both the test and the event: Play may append a
    // base-plan/purchase-option suffix that Apple does not, and the handler
    // downstream matches on the bare id. Crediting is the one place where a
    // mismatch costs the owner money for nothing.
    final productId = ProductIds.baseId(package.storeProduct.identifier);
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
    _requireConfigured();
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

  Future<void> _applyPendingGrants() async {
    try {
      await _backendClient.applyPendingGrants();
    } catch (e, stackTrace) {
      // Best-effort: the rewards stay pending and are retried the next time
      // the app sees premium inactive, so failing quietly here costs nothing
      // but a delay.
      developer.log(
        'Could not apply pending grants',
        name: 'BillingRepository',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _onCustomerInfoUpdate(CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.all[EntitlementIds.premium];
    final isActive = entitlement?.isActive ?? false;
    // RevenueCat hands the date back as an ISO 8601 string, and omits it for
    // a lifetime grant. A value we cannot parse is treated as absent rather
    // than guessed at -- the screen simply says nothing about the end date.
    final expiresAt = isActive
        ? DateTime.tryParse(entitlement?.expirationDate ?? '')
        : null;
    final newStatus = isActive
        ? PremiumStatus(EntitlementState.active, expiresAt: expiresAt)
        : PremiumStatus.inactive;
    final changed = newStatus != _lastPremiumStatus;
    _lastPremiumStatus = newStatus;
    _premiumStatusController.add(newStatus);
    if (!isActive) {
      // A reward earned while premium was already active was recorded rather
      // than granted (it would have expired underneath the paid plan). Now
      // that the plan has lapsed it can actually be delivered.
      //
      // Fire-and-forget, and only a hint: the backend re-checks the
      // subscription with RevenueCat before granting anything, so this being
      // wrong -- or being called by a modified client -- changes nothing.
      unawaited(_applyPendingGrants());
    }
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
