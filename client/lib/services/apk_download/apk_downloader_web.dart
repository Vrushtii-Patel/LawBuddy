// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

String getLawBuddyApkUrl() {
  final base = Uri.base;
  // If running on GitHub Pages or LawBuddy is in the path/host
  if (base.host.contains('github.io') || base.pathSegments.contains('LawBuddy')) {
    return 'https://vrushtii-patel.github.io/LawBuddy/app-release.apk';
  }
  if (base.host != 'localhost' &&
      base.host != '127.0.0.1' &&
      base.host.isNotEmpty) {
    final origin = base.origin;
    var path = base.path;
    if (!path.endsWith('/')) {
      path = '$path/';
    }
    return '$origin${path}app-release.apk';
  }
  return 'https://vrushtii-patel.github.io/LawBuddy/app-release.apk';
}

Future<void> downloadLawBuddyApk() async {
  final url = getLawBuddyApkUrl();
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', 'LawBuddy.apk')
    ..setAttribute('target', '_self')
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  html.document.body?.children.remove(anchor);
}
