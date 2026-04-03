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
          border: Border.all(
              color: WildPathColors.mist.withValues(alpha: 0.9), width: 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: WildPathColors.pine.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6))
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
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: WildPathColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: WildPathColors.pine.withValues(alpha: 0.06),
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
                          vertical: 10, horizontal: 8),
                      child: Column(children: [
                        Text(e.value.value,
                            style: WildPathTypography.display(
                                fontSize: 19, color: WildPathColors.forest)),
                        const SizedBox(height: 1),
                        Text(e.value.label,
                            style: WildPathTypography.body(
                                fontSize: 9,
                                letterSpacing: 0.85,
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

class KeyboardDismissOnTap extends StatelessWidget {
  final Widget child;
  const KeyboardDismissOnTap({required this.child, super.key});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: child,
      );
}

class KeyboardAwareScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final ScrollController? controller;
  final bool addBottomInset;

  const KeyboardAwareScrollView({
    required this.child,
    required this.padding,
    this.controller,
    this.addBottomInset = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding.copyWith(
      bottom: padding.bottom +
          (addBottomInset ? MediaQuery.viewInsetsOf(context).bottom : 0),
    );
    return KeyboardDismissOnTap(
      child: SingleChildScrollView(
        controller: controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: resolvedPadding,
        child: child,
      ),
    );
  }
}

class KeyboardAwareListView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  final ScrollController? controller;
  final bool addBottomInset;

  const KeyboardAwareListView({
    required this.children,
    required this.padding,
    this.controller,
    this.addBottomInset = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding.copyWith(
      bottom: padding.bottom +
          (addBottomInset ? MediaQuery.viewInsetsOf(context).bottom : 0),
    );
    return KeyboardDismissOnTap(
      child: ListView(
        controller: controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: resolvedPadding,
        children: children,
      ),
    );
  }
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
        child: ElevatedButton(
            onPressed: onPressed,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
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
            backgroundColor: WildPathColors.white,
            side: const BorderSide(color: WildPathColors.forest, width: 1.8),
            foregroundColor: WildPathColors.forest,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size(0, 50),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            textStyle: WildPathTypography.body(
                fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w700),
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
}

class GhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final Color? color;
  const GhostButton(this.label,
      {this.onPressed, this.fullWidth = false, this.color, super.key});
  @override
  Widget build(BuildContext context) {
    final base = color ?? WildPathColors.forest;
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: base.withValues(alpha: 0.05),
          side: BorderSide(color: base.withValues(alpha: 0.2), width: 1.2),
          foregroundColor: base,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: WildPathTypography.body(
              fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w600),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
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

void showWildSuccessBanner(
  BuildContext context, {
  required String title,
  String? subtitle,
  String primaryLabel = 'Close',
  VoidCallback? onPrimaryPressed,
  String? secondaryLabel,
  VoidCallback? onSecondaryPressed,
}) {
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    builder: (context) => _WildSuccessModal(
      title: title,
      subtitle: subtitle,
      primaryLabel: primaryLabel,
      onPrimaryPressed: onPrimaryPressed,
      secondaryLabel: secondaryLabel,
      onSecondaryPressed: onSecondaryPressed,
    ),
  );
}

class _WildSuccessModal extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String primaryLabel;
  final VoidCallback? onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  const _WildSuccessModal({
    required this.title,
    this.subtitle,
    required this.primaryLabel,
    this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) => Dialog(
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: WildPathColors.forest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: WildPathColors.fern.withValues(alpha: 0.22),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: WildPathColors.pine.withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: WildPathColors.fern.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 28,
                    color: WildPathColors.fern,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: WildPathTypography.body(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: WildPathTypography.body(
                      fontSize: 12.5,
                      color: WildPathColors.mist.withValues(alpha: 0.94),
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onSecondaryPressed ??
                            () => Navigator.of(context, rootNavigator: true)
                                .pop(),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.02),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1.2,
                          ),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: WildPathTypography.body(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(
                          secondaryLabel ?? 'Close',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onPrimaryPressed ??
                            () => Navigator.of(context, rootNavigator: true)
                                .pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WildPathColors.fern,
                          foregroundColor: WildPathColors.forest,
                          minimumSize: const Size(0, 48),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: WildPathTypography.body(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(
                          primaryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
