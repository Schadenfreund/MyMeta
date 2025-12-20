import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum CardStatus { configured, needsAttention, unconfigured }

class CollapsibleCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final CardStatus? status;
  final Widget collapsedSummary;
  final Widget expandedContent;
  final bool initiallyExpanded;

  const CollapsibleCard({
    super.key,
    required this.title,
    this.subtitle,
    this.status,
    required this.collapsedSummary,
    required this.expandedContent,
    this.initiallyExpanded = false,
  });

  @override
  State<CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<CollapsibleCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  Color _getStatusColor(BuildContext context, CardStatus status) {
    switch (status) {
      case CardStatus.configured:
        return AppColors.lightSuccess;
      case CardStatus.needsAttention:
        return AppColors.lightWarning;
      case CardStatus.unconfigured:
        return Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary;
    }
  }

  IconData _getStatusIcon(CardStatus status) {
    switch (status) {
      case CardStatus.configured:
        return Icons.check_circle;
      case CardStatus.needsAttention:
        return Icons.warning;
      case CardStatus.unconfigured:
        return Icons.settings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardShadow =
        isDark ? AppTheme.darkCardShadow : AppTheme.lightCardShadow;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
        boxShadow: cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  // Status Indicator
                  if (widget.status != null) ...[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getStatusColor(context, widget.status!)
                            .withOpacity(0.12),
                      ),
                      child: Icon(
                        _getStatusIcon(widget.status!),
                        size: 18,
                        color: _getStatusColor(context, widget.status!),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],

                  // Title and Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Chevron
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
              ),
              child: widget.collapsedSummary,
            ),
            secondChild: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
              ),
              child: widget.expandedContent,
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}
