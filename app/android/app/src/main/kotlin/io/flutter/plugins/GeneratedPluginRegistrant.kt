package io.flutter.plugins

import androidx.annotation.Keep
import io.flutter.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Mirrors Flutter's generated registrant, but uses reflection so Android
 * compilation does not depend on direct Java symbol resolution for every plugin.
 */
@Keep
object GeneratedPluginRegistrant {
    private const val TAG = "GeneratedPluginRegistrant"

    @JvmStatic
    fun registerWith(flutterEngine: FlutterEngine) {
        register(flutterEngine, "xyz.luan.audioplayers.AudioplayersPlugin", "audioplayers_android")
        register(flutterEngine, "dev.fluttercommunity.plus.connectivity.ConnectivityPlugin", "connectivity_plus")
        register(flutterEngine, "com.builttoroam.devicecalendar.DeviceCalendarPlugin", "device_calendar")
        register(flutterEngine, "dev.fluttercommunity.plus.device_info.DeviceInfoPlusPlugin", "device_info_plus")
        register(flutterEngine, "io.flutter.plugins.firebase.core.FlutterFirebaseCorePlugin", "firebase_core")
        register(flutterEngine, "io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingPlugin", "firebase_messaging")
        register(flutterEngine, "dev.note11.flutter_naver_map.flutter_naver_map.FlutterNaverMapPlugin", "flutter_naver_map")
        register(flutterEngine, "io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin", "flutter_plugin_android_lifecycle")
        register(flutterEngine, "com.baseflow.geocoding.GeocodingPlugin", "geocoding_android")
        register(flutterEngine, "com.baseflow.geolocator.GeolocatorPlugin", "geolocator_android")
        register(flutterEngine, "io.flutter.plugins.googlemaps.GoogleMapsPlugin", "google_maps_flutter_android")
        register(flutterEngine, "io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin", "google_mobile_ads")
        register(flutterEngine, "es.antonborri.home_widget.HomeWidgetPlugin", "home_widget")
        register(flutterEngine, "com.example.image_gallery_saver_plus.ImageGallerySaverPlusPlugin", "image_gallery_saver_plus")
        register(flutterEngine, "io.flutter.plugins.imagepicker.ImagePickerPlugin", "image_picker_android")
        register(flutterEngine, "dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin", "package_info_plus")
        register(flutterEngine, "io.flutter.plugins.pathprovider.PathProviderPlugin", "path_provider_android")
        register(flutterEngine, "com.llfbandit.record.RecordPlugin", "record_android")
        register(flutterEngine, "dev.fluttercommunity.plus.share.SharePlusPlugin", "share_plus")
        register(flutterEngine, "com.tekartik.sqflite.SqflitePlugin", "sqflite_android")
        register(flutterEngine, "io.flutter.plugins.urllauncher.UrlLauncherPlugin", "url_launcher_android")
        register(flutterEngine, "io.flutter.plugins.webviewflutter.WebViewFlutterPlugin", "webview_flutter_android")
    }

    private fun register(flutterEngine: FlutterEngine, className: String, pluginName: String) {
        try {
            val plugin = Class.forName(className).getDeclaredConstructor().newInstance() as FlutterPlugin
            flutterEngine.plugins.add(plugin)
        } catch (exception: Exception) {
            Log.e(TAG, "Error registering plugin $pluginName, $className", exception)
        }
    }
}
