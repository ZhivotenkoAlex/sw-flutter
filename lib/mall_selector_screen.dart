import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/selector_item.dart';
import 'services/secure_config_service.dart';
import 'services/mall_selection_storage.dart';
import 'webview_screen.dart';

class MallSelectorScreen extends StatefulWidget {
  final SecureAppConfig config;

  const MallSelectorScreen({super.key, required this.config});

  @override
  State<MallSelectorScreen> createState() => _MallSelectorScreenState();
}

class _MallSelectorScreenState extends State<MallSelectorScreen> {
  static const _backgroundColor = Color(0xFF1A1A1A);
  static const _systemUiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: _backgroundColor,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(_systemUiOverlayStyle);
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  Future<void> _openMall(SelectorItem item) async {
    await MallSelectionStorage.saveWebViewUrl(
      widget.config.companyId,
      item.redirectionUrl,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WebViewScreen(
          config: widget.config,
          initialUrl: item.redirectionUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32),
              const Text(
                'Wybierz swoje',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const Text(
                'Centrum handlowe',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.config.selectorItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _MallSelectorCard(
                      item: widget.config.selectorItems[index],
                      onTap: () => _openMall(widget.config.selectorItems[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MallSelectorCard extends StatelessWidget {
  final SelectorItem item;
  final VoidCallback onTap;

  const _MallSelectorCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white24,
          highlightColor: Colors.white12,
          child: SizedBox(
            height: 130,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _NetworkImageBackground(url: item.image),
                Container(color: Colors.black.withValues(alpha: 0.35)),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.logo.isNotEmpty) ...[
                          _NetworkLogo(url: item.logo),
                          const SizedBox(width: 12),
                        ],
                        Flexible(
                          child: Text(
                            item.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkImageBackground extends StatelessWidget {
  final String url;

  const _NetworkImageBackground({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(color: const Color(0xFF2A2A2A));
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: const Color(0xFF2A2A2A),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFF2A2A2A),
          alignment: Alignment.center,
          child: const Icon(Icons.storefront, color: Colors.white38, size: 40),
        );
      },
    );
  }
}

class _NetworkLogo extends StatelessWidget {
  final String url;

  const _NetworkLogo({required this.url});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox.shrink();
        },
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.store, color: Colors.white70, size: 32);
        },
      ),
    );
  }
}
