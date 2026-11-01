import 'package:url_launcher/url_launcher.dart';

const String lawBuddyApkUrl =
    'https://vrushtii-patel.github.io/LawBuddy/app-release.apk';

Future<void> downloadLawBuddyApk() async {
  final uri = Uri.parse(lawBuddyApkUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

