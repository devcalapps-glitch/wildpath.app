import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(text,
            style: WildPathTypography.display(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: WildPathColors.forest)),
      );
}

class PageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const PageTitle(this.title, {this.subtitle, super.key});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: WildPathTypography.display(
                  fontSize: 26, color: WildPathColors.forest)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: WildPathTypography.body(
                    fontSize: 12, color: WildPathColors.smoke)),
          ],
        ],
      );
}

class WildCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  const WildCard({required this.child, this.padding, this.onTap, super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: WildPathColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: WildPathColors.pine.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
                padding: padding ?? const EdgeInsets.all(16), child: child),
          ),
        ),
      );
}

class WildDivider extends StatelessWidget {
  const WildDivider({super.key});
  @override
  Widget build(BuildContext context) => Container(
      height: 1,
      color: WildPathColors.mist,
      margin: const EdgeInsets.symmetric(vertical: 16));
}

class WildProgressBar extends StatelessWidget {
  final double progress;
  final String title;
  final String countLabel;
  final Color? barColor;
  const WildProgressBar({
    required this.progress,
    required this.title,
    required this.countLabel,
    this.barColor,
    super.key,
  });
  @override
  Widget build(BuildContext context) => Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title,
              style: WildPathTypography.body(
                  fontSize: 10.5,
                  letterSpacing: 1.05,
                  color: WildPathColors.smoke)),
          Text(countLabel,
              style: WildPathTypography.body(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: WildPathColors.forest)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: WildPathColors.mist,
            valueColor: AlwaysStoppedAnimation(barColor ?? WildPathColors.moss),
          ),
        ),
      ]);
}

class StatsRow extends StatelessWidget {
  final List<StatItem> stats;
  const StatsRow(this.stats, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: WildPathColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: WildPathColors.pine.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: stats
              .asMap()
              .entries
              .map((e) => Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                          border: e.key < stats.length - 1
                              ? const Border(
                                  right: BorderSide(color: WildPathColors.mist))
                              : null),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 8),
                      child: Column(children: [
                        Text(e.value.value,
                            style: WildPathTypography.display(
                                fontSize: 21, color: WildPathColors.forest)),
                        const SizedBox(height: 2),
                        Text(e.value.label,
                            style: WildPathTypography.body(
                                fontSize: 9.5,
                                letterSpacing: 0.95,
                                color: WildPathColors.smoke),
                            textAlign: TextAlign.center),
                      ]),
                    ),
                  ))
              .toList(),
        ),
      );
}

class StatItem {
  final String value;
  final String label;
  const StatItem({required this.value, required this.label});
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;
  const PrimaryButton(this.label,
      {this.onPressed, this.fullWidth = false, super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: fullWidth ? double.infinity : null,
        child: ElevatedButton(onPressed: onPressed, child: Text(label)),
      );
}

class OutlineButton2 extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;
  const OutlineButton2(this.label,
      {this.onPressed, this.fullWidth = false, super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: fullWidth ? double.infinity : null,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: WildPathColors.forest, width: 2),
            foregroundColor: WildPathColors.forest,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size(0, 48),
            textStyle: WildPathTypography.body(
                fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w500),
          ),
          child: Text(label),
        ),
      );
}

class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;
  const GhostButton(this.label,
      {this.onPressed, this.fullWidth = false, super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: fullWidth ? double.infinity : null,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: WildPathColors.mist, width: 1.5),
            foregroundColor: WildPathColors.smoke,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size(0, 48),
            textStyle:
                WildPathTypography.body(fontSize: 11, letterSpacing: 1.1),
          ),
          child: Text(label),
        ),
      );
}

class TipCard extends StatelessWidget {
  final String emoji;
  final String content;
  final Color? bgColor;
  final Color? borderColor;
  const TipCard(
      {required this.emoji,
      required this.content,
      this.bgColor,
      this.borderColor,
      super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor ?? WildPathColors.cream,
          border:
              Border.all(color: borderColor ?? WildPathColors.mist, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 19)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(content,
                  style: WildPathTypography.body(
                      fontSize: 13, color: WildPathColors.pine, height: 1.6))),
        ]),
      );
}

class GroupHeader extends StatelessWidget {
  final String label;
  const GroupHeader(this.label, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Row(children: [
          Text(label.toUpperCase(),
              style: WildPathTypography.body(
                  fontSize: 10.5,
                  letterSpacing: 1.47,
                  color: WildPathColors.amber,
                  fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: WildPathColors.mist)),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final String emoji;
  final String message;
  const EmptyState({required this.emoji, required this.message, super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: WildPathTypography.body(
                    fontSize: 14, color: WildPathColors.smoke, height: 1.6)),
          ]),
        ),
      );
}

class WildSpinner extends StatelessWidget {
  final String? label;
  const WildSpinner({this.label, super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(children: [
            const CircularProgressIndicator(color: WildPathColors.moss),
            if (label != null) ...[
              const SizedBox(height: 12),
              Text(label!,
                  style: WildPathTypography.body(
                      fontSize: 12, color: WildPathColors.smoke)),
            ],
          ]),
        ),
      );
}

void showWildToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message,
        style: WildPathTypography.body(fontSize: 13, color: Colors.white)),
    backgroundColor: WildPathColors.pine,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    duration: const Duration(seconds: 2),
  ));
}
