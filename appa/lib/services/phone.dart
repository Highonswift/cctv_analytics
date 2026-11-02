import 'package:url_launcher/url_launcher.dart';

/// Places a phone call through the phone's own dialer.
abstract class Phone {
  Future<bool> call(String number);
}

class DevicePhone implements Phone {
  @override
  Future<bool> call(String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return false;
    return launchUrl(Uri(scheme: 'tel', path: cleaned));
  }
}

class FakePhone implements Phone {
  final List<String> dialled = [];
  @override
  Future<bool> call(String number) async {
    dialled.add(number);
    return true;
  }
}
