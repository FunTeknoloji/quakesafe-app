import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:image_picker/image_picker.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress;
            });
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://quakesafe-app.vercel.app/'));

    // Android specific configuration
    if (_controller.platform is AndroidWebViewController) {
      final androidController = _controller.platform as AndroidWebViewController;
      androidController.setOnPlatformPermissionRequest((request) async {
        debugPrint('WebView Permission Request: ${request.types}');
        await request.grant();
      });

      androidController.setOnShowFileSelector((params) async {
        final ImagePicker picker = ImagePicker();
        if (params.acceptTypes.any((type) => type.contains('image'))) {
          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
          if (image != null) {
            return [Uri.file(image.path).toString()];
          }
        } else if (params.acceptTypes.any((type) => type.contains('video'))) {
          final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
          if (video != null) {
            return [Uri.file(video.path).toString()];
          }
        } else {
          final XFile? media = await picker.pickMedia();
          if (media != null) {
            return [Uri.file(media.path).toString()];
          }
        }
        return [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loadingProgress < 100)
              LinearProgressIndicator(
                value: _loadingProgress / 100.0,
                backgroundColor: Colors.black,
                color: Colors.redAccent,
              ),
          ],
        ),
      ),
    );
  }
}
