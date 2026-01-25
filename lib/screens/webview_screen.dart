import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';

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
            final url = request.url.toLowerCase();
            if (url.contains('.pdf') ||
                url.contains('.zip') ||
                url.contains('.jpg') ||
                url.contains('.png') ||
                url.contains('.apk') ||
                url.contains('download')) {
              _downloadFile(request.url);
              return NavigationDecision.prevent;
            }
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

  Future<void> _downloadFile(String url) async {
    try {
      final dio = Dio();
      final dir = await getApplicationDocumentsDirectory();
      final fileName = url.split('/').last.split('?').first;
      final savePath = '${dir.path}/$fileName';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İndiriliyor: $fileName')),
      );

      await dio.download(url, savePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İndirme tamamlandı: $fileName'),
          action: SnackBarAction(
            label: 'Aç',
            onPressed: () {
              OpenFilex.open(savePath);
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Download error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İndirme hatası: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          _controller.goBack();
        } else {
          // If no history, we can't really "go back" more.
          // Maybe show a dialog or just allow exit?
          // The user said "don't close app directly".
          // So let's stay here or maybe show a prompt.
          final exit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text('Çıkış', style: TextStyle(color: Colors.white)),
              content: const Text('Uygulamadan çıkmak istiyor musunuz?', style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hayır')),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Evet', style: TextStyle(color: Colors.redAccent))),
              ],
            ),
          );
          if (exit == true) {
            // How to close app in Flutter?
            // SystemNavigator.pop() or just allow pop from this screen if it's the root.
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          }
        }
      },
      child: Scaffold(
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
      ),
    );
  }
}
