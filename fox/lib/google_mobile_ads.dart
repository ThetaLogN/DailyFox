/*import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  bool _rewardEarned = false;
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  static const double bannerHeight = 50.0;

  void loadRewardedAd({
    required BuildContext context,
    required VoidCallback onAdCompleted,
    required VoidCallback onAdFailed,
  }) {
    if (_isAdLoading) return;
    _isAdLoading = true;
    _rewardEarned = false;

    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1712485313',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isAdLoading = false;

              if (_rewardEarned) {
                onAdCompleted(); // ✅ Naviga solo dopo la chiusura
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isAdLoading = false;
              onAdFailed();
            },
          );

          ad.show(
            onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
              _rewardEarned = true;
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isAdLoading = false;
          onAdFailed();
        },
      ),
    );
  }

  void loadBannerAd() {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-3940256099942544/2934735716', // ID TEST iOS banner
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          _isBannerAdReady = true;
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          _isBannerAdReady = false;
          debugPrint('⚠️ Banner failed to load: $error');
        },
      ),
      request: const AdRequest(),
    )..load();
  }

  Widget getBannerWidget() {
    if (_bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    } else {
      return SizedBox(height: bannerHeight); // 🔒 Riserva spazio
    }
  }

  void disposeBanner() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }
}*/
