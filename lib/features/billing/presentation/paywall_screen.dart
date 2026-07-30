import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../data/billing_repository.dart';
import '../domain/product_ids.dart';

/// Simple, functional (not pixel-perfect) upgrade/paywall screen: lists the
/// premium_monthly/premium_yearly subscriptions and the ai_tickets_5/15
/// consumable packs from RevenueCat's current offering, with a purchase
/// button on each and a "restore purchases" action.
///
/// No app-wide state-management convention exists yet in this codebase
/// (no other feature has a presentation/ layer), so this screen owns its
/// own loading/error state locally rather than assuming Provider/Riverpod
/// wiring; the app-shell just needs to construct it with a
/// [BillingRepository] (typically the same instance app-shell configured
/// and called [BillingRepository.logIn] on after Firebase sign-in).
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, required this.billingRepository});

  final BillingRepository billingRepository;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
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
      body: FutureBuilder<Offerings>(
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
