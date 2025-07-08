import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
  double _loadingProgress = 0;
  final CacheManager _cacheManager = CacheManager(
    Config(
      'dopebox_cache',
      stalePeriod: const Duration(days: 1),
      maxNrOfCacheObjects: 100,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      _handleConnectivityChange(result);
    });
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress / 100;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });

            _webViewController.runJavaScript('''
              document.querySelectorAll('img').forEach(img => {
                if (img.loading === 'lazy') {
                  img.loading = 'eager';
                }
                if (!img.src && img.dataset.src) {
                  img.src = img.dataset.src;
                }
              });
              
              const style = document.createElement('style');
              style.innerHTML = 'img { opacity: 1 !important; }';
              document.head.appendChild(style);
            ''');
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
        headers: _getCacheHeaders(),
      );
  }

  Map<String, String> _getCacheHeaders() {
    return {'Cache-Control': 'max-age=3600', 'Pragma': 'cache'};
  }

  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    final isConnected = result != ConnectivityResult.none;
    setState(() {
      _isConnected = isConnected;
    });

    if (isConnected && _hasError) {
      await _webViewController.reload();
    }
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = connectivityResult != ConnectivityResult.none;
    });
  }

  Future<void> _clearCacheAndReload() async {
    await _cacheManager.emptyCache();
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    await _webViewController.reload();
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 20),
          const Text(
            'Unable to Load Content',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'The page could not be loaded. Please try again later.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0061FF),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _webViewController.reload(),
                child: const Text('Retry'),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: _clearCacheAndReload,
                child: const Text('Clear Cache'),
              ),
            ],
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
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: _loadingProgress,
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (!_isConnected) {
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
                  const SizedBox(height: 10),
                  const Text(
                    'Please check your connection and try again',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0061FF),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      _checkConnectivity();
                      if (_isConnected) {
                        _webViewController.reload();
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (_hasError) {
            return _buildErrorView();
          }
          return Stack(
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
          );
        },
      ),
    );
  }
}
