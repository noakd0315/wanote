import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../data/billing_repository.dart';
import '../data/campaign_code_repository.dart';
import '../domain/campaign_code_models.dart';
import '../domain/product_ids.dart';

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
  }) : campaignCodeRepository = campaignCodeRepository ?? const _LazyFirestoreCampaignCodeRepository();

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
  Future<CampaignCode?> checkValid(String code) => _delegate.checkValid(code);

  @override
  Future<CampaignCodeRedemptionResult> redeem({required String code, required String uid}) =>
      _delegate.redeem(code: code, uid: uid);

  @override
  Future<String> getOrCreateReferralCode(String uid) => _delegate.getOrCreateReferralCode(uid);

  static CampaignCodeRepository get _delegate => FirestoreCampaignCodeRepository();
}

class _PaywallScreenState extends State<PaywallScreen> {
  late Future<Offerings> _offeringsFuture;
  String? _busyPackageId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _offeringsFuture = widget.billingRepository.getOfferings();
  }

  Future<void> _purchase(Package package) async {
    setState(() {
      _busyPackageId = package.identifier;
      _errorMessage = null;
    });
    try {
      await widget.billingRepository.purchase(package.identifier);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Purchase complete.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Purchase failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busyPackageId = null);
      }
    }
  }

  Future<void> _restore() async {
    setState(() => _errorMessage = null);
    try {
      await widget.billingRepository.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases restored.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Restore failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium & AI tickets'),
        actions: [
          TextButton(
            onPressed: _restore,
            child: const Text(
              'Restore purchases',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<Offerings>(
              future: _offeringsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Could not load offerings: ${snapshot.error}\n\n'
                        'If this is a dev/test build, the RevenueCat dashboard '
                        'may not be configured yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final offering = snapshot.data?.current;
                final packages = offering?.availablePackages ?? const <Package>[];
                if (packages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No products are available yet. The RevenueCat dashboard '
                        'has not been configured with offerings/products.',
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
          _CampaignCodeSection(repository: widget.campaignCodeRepository),
        ],
      ),
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

  String get _label {
    final productId = package.storeProduct.identifier;
    return switch (productId) {
      ProductIds.premiumMonthly => 'Premium (monthly)',
      ProductIds.premiumYearly => 'Premium (yearly)',
      ProductIds.aiTickets5 => 'AI consultation tickets x5',
      ProductIds.aiTickets15 => 'AI consultation tickets x15',
      _ => package.storeProduct.title,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(_label),
        subtitle: Text(package.storeProduct.description),
        trailing: isBusy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : ElevatedButton(
                onPressed: onPurchase,
                child: Text(package.storeProduct.priceString),
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
  const _CampaignCodeSection({required this.repository});

  final CampaignCodeRepository repository;

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

  Future<void> _redeem() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _statusMessage = 'サインインしてからお試しください。';
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
          _statusMessage = 'プレミアムを1ヶ月分付与しました。ありがとうございます！';
          _codeController.clear();
        case CampaignCodeRedemptionRejected(reason: final reason):
          _statusIsError = true;
          _statusMessage = _messageForReason(reason);
        case CampaignCodeRedemptionFailed(message: final message):
          _statusIsError = true;
          _statusMessage = message;
      }
    });
  }

  String _messageForReason(RedemptionIneligibleReason reason) {
    return switch (reason) {
      RedemptionIneligibleReason.unknownCode => 'このコードは見つかりませんでした。',
      RedemptionIneligibleReason.inactive => 'このコードは現在無効です。',
      RedemptionIneligibleReason.redemptionCapReached => 'このコードは利用上限に達しています。',
      RedemptionIneligibleReason.alreadyRedeemedByUser => 'このコードは既に使用済みです。',
      RedemptionIneligibleReason.selfReferral => '自分の紹介コードは使用できません。',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'プロモーションコードをお持ちですか？',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    hintText: 'コードを入力',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  enabled: !_redeemBusy,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _redeemBusy ? null : _redeem,
                child: _redeemBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('適用する'),
              ),
            ],
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _statusMessage!,
              style: TextStyle(color: _statusIsError ? Colors.red : Colors.green),
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
                    Expanded(child: Text('あなたの紹介コード: $referralCode')),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'コピー',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: referralCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('紹介コードをコピーしました。')),
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
