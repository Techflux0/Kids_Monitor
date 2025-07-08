import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    AndroidWebViewController.enableDebugging(true);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DopeBox',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0061FF)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0061FF),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const MyHomePage(title: 'DopeBox'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final WebViewController _webViewController;
  bool _isConnected = true;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((results) {
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      _handleConnectivityChange(result);
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _fixImageLoading();
    });
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() => _isLoading = progress < 100);
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) async {
            setState(() => _isLoading = false);
            await Future.delayed(const Duration(seconds: 1));
            await _fixImageLoading();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(
        Uri.parse('https://dopebox.to/movie'),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36',
          'Referer': 'https://dopebox.to/',
        },
      );
  }

  Future<void> _fixImageLoading() async {
    await _webViewController.runJavaScript('''
      // Enhanced image loader with MutationObserver
      (function() {
        const loadImage = (img) => {
          if (img.dataset.processed) return;
          img.dataset.processed = 'true';
          
          const sources = [
            'data-src', 
            'data-original', 
            'data-lazy-src',
            'data-srcset',
            'data-lazy-srcset'
          ];
          
          // Check for source attributes
          for (const src of sources) {
            if (img.hasAttribute(src)) {
              const value = img.getAttribute(src);
              if (src.includes('srcset')) {
                img.srcset = value;
              } else {
                img.src = value;
              }
              break;
            }
          }
          
          // Handle picture/source elements
          if (img.parentElement.tagName === 'PICTURE') {
            const sources = img.parentElement.querySelectorAll('source');
            sources.forEach(source => {
              for (const src of sources) {
                if (source.hasAttribute(src)) {
                  const value = source.getAttribute(src);
                  if (src.includes('srcset')) {
                    source.srcset = value;
                  } else {
                    source.src = value;
                  }
                }
              }
            });
          }
          
          // Remove lazy loading attributes
          img.removeAttribute('loading');
          img.removeAttribute('lazy');
          
        };

        const processImages = () => {
          const images = document.querySelectorAll('img:not([data-processed])');
          images.forEach(img => {
            loadImage(img);
            img.onerror = () => {
              img.style.display = 'none';
              if (img.parentElement) {
                img.parentElement.innerHTML = 
                  '<div style="min-height:150px;display:flex;align-items:center;justify-content:center;color:#888">Image unavailable</div>';
              }
            };
          });
        };

        // Process existing images
        processImages();

        // Set up MutationObserver for dynamically added content
        const observer = new MutationObserver((mutations) => {
          mutations.forEach(mutation => {
            if (mutation.addedNodes.length) {
              processImages();
            }
          });
        });

        observer.observe(document.body, {
          childList: true,
          subtree: true
        });
      })();
    ''');
  }

  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    final isConnected = result != ConnectivityResult.none;
    setState(() => _isConnected = isConnected);
    if (isConnected && _hasError) await _webViewController.reload();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(
      () => _isConnected = connectivityResult != ConnectivityResult.none,
    );
  }

  Widget _buildNoInternetView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 64, color: Colors.red),
          const SizedBox(height: 20),
          const Text(
            'No Internet Connection',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0061FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              _checkConnectivity();
              if (_isConnected) _webViewController.reload();
            },
            child: const Text('Retry Connection'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 20),
          const Text(
            'Failed to Load Content',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0061FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => _webViewController.reload(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', height: 30),
            const SizedBox(width: 10),
            const Text('DopeBox'),
          ],
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: !_isConnected
          ? _buildNoInternetView()
          : _hasError
          ? _buildErrorView()
          : Stack(
              children: [
                WebViewWidget(controller: _webViewController),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF0061FF),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
