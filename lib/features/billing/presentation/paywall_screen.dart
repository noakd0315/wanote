import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/utils/formatting.dart';
import '../domain/billing_models.dart';
import '../data/billing_repository.dart';
import '../data/campaign_code_repository.dart';
import '../domain/campaign_code_models.dart';
import '../domain/product_ids.dart';
import '../../../shared/widgets/wanote_loading_indicator.dart';

/// Simple, functional (not pixel-perfect) upgrade/paywall screen: lists the
/// premium_monthly/premium_yearly subscriptions and the ai_tickets_5/15
/// consumable packs from RevenueCat's current offering, with a purchase
/// button on each and a "restore purchases" action. Also includes a
/// placeholder campaign-code / referral-code redemption section at the
/// bottom -- deliberately unstyled, a visual-polish pass is a separate,
/// later piece of work per the PM.
///
/// No app-wide state-management convention exists yet in this codebase
/// (no other feature has a presentation/ layer), so this screen owns its
/// own loading/error state locally rather than assuming Provider/Riverpod
/// wiring; the app-shell just needs to construct it with a
/// [BillingRepository] (typically the same instance app-shell configured
/// and called [BillingRepository.logIn] on after Firebase sign-in).
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    required this.billingRepository,
    CampaignCodeRepository? campaignCodeRepository,
  }) : campaignCodeRepository =
           campaignCodeRepository ??
           const _LazyFirestoreCampaignCodeRepository();

  final BillingRepository billingRepository;
  final CampaignCodeRepository campaignCodeRepository;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

/// Defers constructing [FirestoreCampaignCodeRepository] (which touches
/// FirebaseFirestore.instance) until it's actually used, so widget tests
/// that never exercise the campaign-code section don't need Firebase to be
/// initialized just to build [PaywallScreen] with its default repository.
class _LazyFirestoreCampaignCodeRepository implements CampaignCodeRepository {
  const _LazyFirestoreCampaignCodeRepository();

  @override
  Future<CampaignCodeRedemptionResult> redeem({
    required String code,
    required String uid,
  }) => _delegate.redeem(code: code, uid: uid);

  @override
  Future<String> getOrCreateReferralCode(String uid) =>
      _delegate.getOrCreateReferralCode(uid);

  static CampaignCodeRepository get _delegate =>
      FirestoreCampaignCodeRepository();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late Future<Offerings> _offeringsFuture;
  String? _busyPackageId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _offeringsFuture = widget.billingRepository.getOfferings().catchError((
      Object e,
      StackTrace stackTrace,
    ) {
      // Full exception -> developer log only; the FutureBuilder's error
      // branch shows a generic friendly message instead (PM report: raw
      // SDK error text was showing on screen).
      developer.log(
        'getOfferings failed',
        name: 'PaywallScreen',
        error: e,
        stackTrace: stackTrace,
      );
      throw e; // rethrow so the FutureBuilder still sees snapshot.hasError
    });
  }

  Future<void> _purchase(Package package) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busyPackageId = package.identifier;
      _errorMessage = null;
    });
    try {
      await widget.billingRepository.purchase(package.identifier);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.purchaseCompleteMessage)));
      }
    } catch (e, stackTrace) {
      // A cancelled purchase isn't a failure the user needs an alarming
      // error message for -- just silently leave the sheet as-is.
      if (e is PlatformException &&
          PurchasesErrorHelper.getErrorCode(e) ==
              PurchasesErrorCode.purchaseCancelledError) {
        return;
      }
      // Full exception -> developer log only; the user gets a generic
      // friendly message (PM report: raw SDK error text was showing on
      // screen).
      developer.log(
        'Purchase failed',
        name: 'PaywallScreen',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() => _errorMessage = l10n.purchaseFailedMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _busyPackageId = null);
      }
    }
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _errorMessage = null);
    try {
      await widget.billingRepository.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.purchasesRestoredMessage)));
      }
    } catch (e, stackTrace) {
      // Full exception -> developer log only; the user gets a generic
      // friendly message (PM report: raw SDK error text was showing on
      // screen).
      developer.log(
        'Restore purchases failed',
        name: 'PaywallScreen',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(
          () => _errorMessage = e is BillingNotConfiguredException
              ? l10n.billingUnavailableMessage
              : l10n.restoreFailedMessage,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // Transparent so HomeShell's shared DogSilhouetteBackground (behind
      // its Navigator) shows through, per the PM's request to scatter the
      // pattern across every non-input-form screen.
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(l10n.paywallAppBarTitle),
        actions: [
          TextButton(
            onPressed: _restore,
            child: Text(
              l10n.restorePurchasesButton,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _PremiumStatusBanner(billingRepository: widget.billingRepository),
          Expanded(
            child: FutureBuilder<Offerings>(
              future: _offeringsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return WanoteLoadingIndicator.centered();
                }
                if (snapshot.hasError) {
                  // "Not provisioned yet" is not the same as "we tried and
                  // it failed" -- telling the user to check their connection
                  // would send them chasing a problem on their end.
                  final message =
                      snapshot.error is BillingNotConfiguredException
                      ? l10n.billingUnavailableMessage
                      : l10n.offeringsLoadError;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(message, textAlign: TextAlign.center),
                    ),
                  );
                }

                final offering = snapshot.data?.current;
                final packages =
                    offering?.availablePackages ?? const <Package>[];
                if (packages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l10n.noProductsAvailableMessage,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                    ],
                    for (final package in packages) ...[
                      _PackageTile(
                        package: package,
                        isBusy: _busyPackageId == package.identifier,
                        onPurchase: () => _purchase(package),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          _CampaignCodeSection(
            repository: widget.campaignCodeRepository,
            billingRepository: widget.billingRepository,
          ),
        ],
      ),
    );
  }
}

/// Says, at the top of the paywall, that the account already has access --
/// and until when.
///
/// A free month delivered by a campaign or referral code otherwise ends
/// without warning: the owner is told "one month" once, in a snackbar, and
/// afterwards has nowhere to look (PM, 2026-08-21). A subscriber gets the
/// same line, which also stops the paywall reading as if they had bought
/// nothing.
class _PremiumStatusBanner extends StatelessWidget {
  const _PremiumStatusBanner({required this.billingRepository});

  final BillingRepository billingRepository;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<PremiumStatus>(
      stream: billingRepository.premiumStatusChanges(),
      initialData: billingRepository.currentPremiumStatus,
      builder: (context, snapshot) {
        final status = snapshot.data ?? PremiumStatus.unknown;
        // Nothing while the answer is still coming, and nothing once it is
        // known to be inactive -- the plans below are the message then.
        if (!status.isActive) return const SizedBox.shrink();
        final expiresAt = status.expiresAt;
        final scheme = Theme.of(context).colorScheme;
        return Container(
          width: double.infinity,
          color: scheme.primaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.verified, size: 18, color: scheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  expiresAt == null
                      ? l10n.premiumActiveNoExpiry
                      : l10n.premiumActiveUntil(formatDate(context, expiresAt)),
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.package,
    required this.isBusy,
    required this.onPurchase,
  });

  final Package package;
  final bool isBusy;
  final VoidCallback onPurchase;

  String _label(AppLocalizations l10n) {
    // Normalised: Play appends the base plan (`premium_monthly:monthly`)
    // and Apple does not, so the raw string only ever matched on iOS.
    final productId = ProductIds.baseId(package.storeProduct.identifier);
    return switch (productId) {
      ProductIds.premiumMonthly => l10n.premiumMonthlyLabel,
      ProductIds.premiumYearly => l10n.premiumYearlyLabel,
      ProductIds.aiTickets5 => l10n.aiTickets5Label,
      ProductIds.aiTickets15 => l10n.aiTickets15Label,
      _ => package.storeProduct.title,
    };
  }

  /// The plan's description, in the app's language.
  ///
  /// Not the store's. Both stores answer in whatever the *account's* region
  /// and language resolve to, not the app's: an English-language app on a
  /// Japanese Play account showed Japanese, and a sandbox account set to the
  /// United States showed English everywhere (PM, 2026-08-21). The price is
  /// still the store's -- that one has to be, it is what will be charged.
  String _description(AppLocalizations l10n) {
    final productId = ProductIds.baseId(package.storeProduct.identifier);
    return switch (productId) {
      ProductIds.premiumMonthly => l10n.premiumMonthlyDescription,
      ProductIds.premiumYearly => l10n.premiumYearlyDescription,
      ProductIds.aiTickets5 => l10n.aiTickets5Description,
      ProductIds.aiTickets15 => l10n.aiTickets15Description,
      _ => package.storeProduct.description,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      // The whole row buys, not just the button. The button sits at the
      // right edge and the eye goes to the plan name, so the name is what
      // got tapped -- and nothing happened (PM, 2026-08-21).
      child: InkWell(
        onTap: isBusy ? null : onPurchase,
        child: ListTile(
          title: Text(_label(l10n)),
          subtitle: Text(_description(l10n)),
          trailing: isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              // Filled, not elevated: this is the primary action of the
              // screen and it was reading as secondary.
              : FilledButton(
                  onPressed: onPurchase,
                  child: Text(package.storeProduct.priceString),
                ),
        ),
      ),
    );
  }
}

/// Placeholder campaign-code / referral-code section: a text field + submit
/// button for redeeming a code, plus a "your referral code" row with a copy
/// button. Deliberately minimal (no dedicated screen, no visual polish) --
/// the PM explicitly scoped this as a placeholder for a later design pass.
class _CampaignCodeSection extends StatefulWidget {
  const _CampaignCodeSection({
    required this.repository,
    required this.billingRepository,
  });

  final CampaignCodeRepository repository;

  /// Only used to re-read the entitlement after a code is accepted --
  /// see BillingRepository.refreshCustomerInfo.
  final BillingRepository billingRepository;

  @override
  State<_CampaignCodeSection> createState() => _CampaignCodeSectionState();
}

class _CampaignCodeSectionState extends State<_CampaignCodeSection> {
  final _codeController = TextEditingController();
  bool _redeemBusy = false;
  String? _statusMessage;
  bool _statusIsError = false;
  Future<String>? _referralCodeFuture;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _referralCodeFuture = widget.repository.getOrCreateReferralCode(uid);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeem(AppLocalizations l10n) async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _statusMessage = l10n.campaignCodeSignInRequired;
        _statusIsError = true;
      });
      return;
    }

    setState(() {
      _redeemBusy = true;
      _statusMessage = null;
    });

    final result = await widget.repository.redeem(code: code, uid: uid);

    if (!mounted) return;
    setState(() {
      _redeemBusy = false;
      switch (result) {
        case CampaignCodeRedeemed():
          _statusIsError = false;
          _statusMessage = l10n.campaignCodeRedeemedMessage;
          _codeController.clear();
          // The grant happened on the server, so the SDK still believes the
          // account is not premium: ads keep showing and the report screen
          // stays locked while the free month is already running (PM report,
          // 2026-08-21). Fire-and-forget -- the message above is already
          // correct, and the entitlement will also resolve on next launch if
          // this fails.
          unawaited(widget.billingRepository.refreshCustomerInfo());
        case CampaignCodeRedemptionRejected(reason: final reason):
          _statusIsError = true;
          _statusMessage = _messageForReason(l10n, reason);
        case CampaignCodeRedemptionFailed(message: final message):
          _statusIsError = true;
          _statusMessage = message;
      }
    });
  }

  String _messageForReason(
    AppLocalizations l10n,
    RedemptionIneligibleReason reason,
  ) {
    return switch (reason) {
      RedemptionIneligibleReason.unknownCode => l10n.campaignCodeUnknownError,
      RedemptionIneligibleReason.inactive => l10n.campaignCodeInactiveError,
      RedemptionIneligibleReason.redemptionCapReached =>
        l10n.campaignCodeCapReachedError,
      RedemptionIneligibleReason.alreadyRedeemedByUser =>
        l10n.campaignCodeAlreadyRedeemedError,
      RedemptionIneligibleReason.selfReferral =>
        l10n.campaignCodeSelfReferralError,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.campaignCodeSectionTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    hintText: l10n.campaignCodeHintText,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  enabled: !_redeemBusy,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _redeemBusy ? null : () => _redeem(l10n),
                child: _redeemBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.campaignCodeApplyButton),
              ),
            ],
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _statusMessage!,
              style: TextStyle(
                color: _statusIsError ? Colors.red : Colors.green,
              ),
            ),
          ],
          if (_referralCodeFuture != null) ...[
            const SizedBox(height: 16),
            FutureBuilder<String>(
              future: _referralCodeFuture,
              builder: (context, snapshot) {
                final referralCode = snapshot.data;
                if (referralCode == null) return const SizedBox.shrink();
                return Row(
                  children: [
                    Expanded(
                      child: Text(l10n.referralCodeDisplay(referralCode)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: l10n.copyTooltip,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: referralCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.referralCodeCopiedMessage),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
