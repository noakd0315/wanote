import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../domain/ad_policy.dart';
import 'ad_unit_ids.dart';

/// Mounts a banner ad only when [AdPolicy.shouldShowBanner] is true;
/// otherwise renders nothing ([SizedBox.shrink]) and never loads an ad at
/// all (spec 8.1: ads must be fully hidden for paying subscribers, not just
/// visually collapsed).
///
/// Usage: place at the bottom of a screen and pass the caller's current
/// [AdPolicy] (derived from [BillingRepository.currentPremiumStatus] /
/// [BillingRepository.premiumStatusChanges]).
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key, required this.policy});

  final AdPolicy policy;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.policy.shouldShowBanner) {
      _loadBanner();
    }
  }

  @override
  void didUpdateWidget(covariant BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldShowNow = widget.policy.shouldShowBanner;
    final wasShowing = oldWidget.policy.shouldShowBanner;
    if (shouldShowNow && !wasShowing) {
      _loadBanner();
    } else if (!shouldShowNow && wasShowing) {
      _disposeBanner();
    }
  }

  void _loadBanner() {
    final bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: AdUnitIds.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
            });
          }
        },
      ),
    );
    _bannerAd = bannerAd;
    _isLoaded = false;
    bannerAd.load();
  }

  void _disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;
  }

  @override
  void dispose() {
    _disposeBanner();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (!widget.policy.shouldShowBanner || ad == null || !_isLoaded) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
