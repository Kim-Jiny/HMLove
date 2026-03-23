import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }
}
