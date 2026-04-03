import 'package:flutter/material.dart';

import '../constants/country_options.dart';
import '../models/trip_model.dart';
import '../theme/app_theme.dart';

class CountryAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final String fallbackValue;
  final Color fillColor;
  final Color textColor;
  final Color hintColor;
  final Color iconColor;
  final Color optionsBackgroundColor;
  final Color optionsTextColor;
  final Color optionsBorderColor;
  final double optionsMaxHeight;
  final OptionsViewOpenDirection optionsViewOpenDirection;
  final EdgeInsets scrollPadding;
  final bool enabled;
  final ValueChanged<String> onSelected;
  final void Function(String value, String? exactMatch)? onChanged;

  const CountryAutocompleteField({
    required this.controller,
    required this.hintText,
    required this.fillColor,
    required this.textColor,
    required this.hintColor,
    required this.iconColor,
    required this.optionsBackgroundColor,
    required this.optionsTextColor,
    required this.optionsBorderColor,
    required this.onSelected,
    this.focusNode,
    this.fallbackValue = '',
    this.optionsMaxHeight = 260,
    this.optionsViewOpenDirection = OptionsViewOpenDirection.down,
    this.scrollPadding = const EdgeInsets.all(20),
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  @override
  State<CountryAutocompleteField> createState() =>
      _CountryAutocompleteFieldState();
}

class _CountryAutocompleteFieldState extends State<CountryAutocompleteField> {
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(CountryAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_handleFocusChanged);
      if (oldWidget.focusNode == null) {
        _ownedFocusNode?.removeListener(_handleFocusChanged);
      }
      _focusNode.addListener(_handleFocusChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) return;
    final exactMatch = _exactCountryMatch(widget.controller.text);
    if (exactMatch != null) {
      _setControllerText(exactMatch);
      return;
    }
    if (widget.fallbackValue.trim().isNotEmpty) {
      _setControllerText(widget.fallbackValue);
    }
  }

  void _setControllerText(String value) {
    widget.controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  String? _exactCountryMatch(String value) {
    final normalized = TripModel.normalizeCountryName(value).toLowerCase();
    if (normalized.isEmpty) return null;
    for (final option in countryOptions) {
      if (TripModel.normalizeCountryName(option).toLowerCase() == normalized) {
        return option;
      }
    }
    return null;
  }

  Iterable<String> _countryMatches(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const Iterable<String>.empty();
    final normalizedQuery =
        TripModel.normalizeCountryName(trimmed).toLowerCase();

    final startsWith = <String>[];
    final contains = <String>[];
    for (final option in countryOptions) {
      final normalizedOption =
          TripModel.normalizeCountryName(option).toLowerCase();
      if (normalizedOption.startsWith(normalizedQuery)) {
        startsWith.add(option);
      } else if (normalizedOption.contains(normalizedQuery)) {
        contains.add(option);
      }
    }
    return [...startsWith, ...contains].take(8);
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsViewOpenDirection: widget.optionsViewOpenDirection,
      optionsBuilder: (textEditingValue) => widget.enabled
          ? _countryMatches(textEditingValue.text)
          : const Iterable<String>.empty(),
      onSelected: (value) {
        _setControllerText(value);
        widget.onSelected(value);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          textInputAction: TextInputAction.done,
          onChanged: (value) {
            widget.onChanged?.call(value, _exactCountryMatch(value));
          },
          onFieldSubmitted: (value) {
            final exactMatch = _exactCountryMatch(value);
            if (exactMatch != null) {
              _setControllerText(exactMatch);
              widget.onSelected(exactMatch);
            } else {
              onFieldSubmitted();
            }
          },
          style: WildPathTypography.body(fontSize: 14, color: widget.textColor),
          scrollPadding: widget.scrollPadding,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle:
                WildPathTypography.body(fontSize: 13, color: widget.hintColor),
            filled: true,
            fillColor: widget.fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: Icon(
              Icons.search_rounded,
              size: 18,
              color: widget.enabled
                  ? widget.iconColor
                  : widget.iconColor.withValues(alpha: 0.45),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final entries = options.toList();
        if (entries.isEmpty) return const SizedBox.shrink();
        final optionsSpacing =
            widget.optionsViewOpenDirection == OptionsViewOpenDirection.up
                ? const EdgeInsets.only(bottom: 8)
                : const EdgeInsets.only(top: 8);
        return Padding(
          padding: optionsSpacing,
          child: Material(
            elevation: 8,
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(maxHeight: widget.optionsMaxHeight),
              decoration: BoxDecoration(
                color: widget.optionsBackgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: widget.optionsBorderColor),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: widget.optionsBorderColor.withValues(alpha: 0.6),
                ),
                itemBuilder: (context, index) {
                  final option = entries[index];
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Text(
                        option,
                        style: WildPathTypography.body(
                          fontSize: 14,
                          color: widget.optionsTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
