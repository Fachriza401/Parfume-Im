import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';

/// One announcement rendered by [PromoTicker].
class PromoTickerItem {
  const PromoTickerItem({
    required this.title,
    required this.subtitle,
    this.icon = Icons.local_offer_outlined,
    this.imageUrl,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? imageUrl;

  factory PromoTickerItem.fromPromotion({
    required String code,
    required String name,
    required String discountLabel,
    String? description,
    String? imageUrl,
    double minOrder = 0,
  }) => PromoTickerItem(
    icon: Icons.local_offer_outlined,
    title: 'Promo $code • $discountLabel',
    imageUrl: imageUrl,
    subtitle: <String>[
      name,
      if (description != null && description.trim().isNotEmpty)
        description.trim(),
      if (minOrder > 0) 'Min. belanja ${Formatters.rupiah(minOrder)}',
    ].join(' — '),
  );
}

/// Horizontally scrollable promo cards displayed under the catalog search.
class PromoTicker extends StatefulWidget {
  const PromoTicker({super.key, required this.items, this.onTap});

  final List<PromoTickerItem> items;

  final ValueChanged<int>? onTap;

  @override
  State<PromoTicker> createState() => _PromoTickerState();
}

class _PromoTickerState extends State<PromoTicker> {
  static const double _cardWidth = 250;
  static const double _cardGap = 10;

  final ScrollController _scrollController = ScrollController();
  Timer? _advanceTimer;
  bool _isAdvancing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && widget.items.length > 1) {
        _scrollController.jumpTo(widget.items.length * (_cardWidth + _cardGap));
      }
    });
    _advanceTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _advance(),
    );
  }

  @override
  void didUpdateWidget(PromoTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            widget.items.length > 1
                ? widget.items.length * (_cardWidth + _cardGap)
                : 0,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    if (!_scrollController.hasClients ||
        widget.items.length < 2 ||
        _isAdvancing) {
      return;
    }

    _isAdvancing = true;
    final loopExtent = widget.items.length * (_cardWidth + _cardGap);
    if (_scrollController.offset < _cardWidth + _cardGap) {
      _scrollController.jumpTo(loopExtent);
    }

    try {
      await _scrollController.animateTo(
        _scrollController.offset - (_cardWidth + _cardGap),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    } finally {
      _isAdvancing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    final palette = context.palette;

    return SizedBox(
      height: 104,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final loopExtent = items.length * (_cardWidth + _cardGap);
          final viewportWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : loopExtent;
          final repeatCount = items.length < 2
              ? 1
              : (viewportWidth / loopExtent).ceil() + 1;

          return ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            itemCount: items.length * repeatCount,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final itemIndex = index % items.length;
              final item = items[itemIndex];

              return SizedBox(
                width: _cardWidth,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: widget.onTap == null
                        ? null
                        : () => widget.onTap!(itemIndex),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: <Color>[
                            AppColors.gold.withValues(
                              alpha: palette.isDark ? 0.18 : 0.20,
                            ),
                            AppColors.gold.withValues(
                              alpha: palette.isDark ? 0.05 : 0.06,
                            ),
                          ],
                        ),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          _PromoImage(item: item, iconColor: palette.goldText),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: palette.goldText,
                                  ),
                                ),
                                if (item.subtitle.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PromoImage extends StatelessWidget {
  const _PromoImage({required this.item, required this.iconColor});

  final PromoTickerItem item;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl?.trim();
    final fallback = Icon(item.icon, size: 26, color: iconColor);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 62,
        height: 76,
        child: url == null || url.isEmpty
            ? ColoredBox(
                color: AppColors.gold.withValues(alpha: 0.12),
                child: Center(child: fallback),
              )
            : Image.network(
                AppConfig.resolveApiResource(url).toString(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  child: Center(child: fallback),
                ),
              ),
      ),
    );
  }
}
