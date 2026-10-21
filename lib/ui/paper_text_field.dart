import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/paper_tokens.dart';
import '../theme/theme_x.dart';
import 'paper_icon_button.dart';

/// `.field-input` sizes (components.md §4.1).
enum PaperTextFieldSize {
  /// `px-3 py-2 text-sm`: 38 tall (forms, search).
  md(12, 9, 14, 20),

  /// `text-base` on narrow sign-in: 42 tall.
  mdBase(12, 9, 16, 24),

  /// `px-2.5 py-1 text-sm`: 30 tall (inline rename).
  sm(10, 5, 14, 20),

  /// `px-2.5 py-1 text-xs`: 26 tall (find bar).
  xs(10, 5, 12, 16);

  const PaperTextFieldSize(
    this.paddingX,
    this.paddingY,
    this.fontSize,
    this.lineHeight,
  );

  final double paddingX;

  /// Vertical content padding including the 1px border (web py + 1).
  final double paddingY;
  final double fontSize;
  final double lineHeight;

  /// Single-line rendered height.
  double get height => lineHeight + paddingY * 2;
}

/// A web `.field-input` (components.md §4.1): gray-900 fill, 1px gray-700
/// border, radius 6, 14/20 text, gray-400 placeholder; focus = 2px accent
/// edge with no size change; error = red-500 border + message below.
///
/// With [label], the label sits above (`sm 500 gray-300`, gap 6).
class PaperTextField extends StatelessWidget {
  const PaperTextField({
    super.key,
    this.fieldKey,
    this.controller,
    this.focusNode,
    this.label,
    this.hintText,
    this.errorText,
    this.size = PaperTextFieldSize.md,
    this.enabled = true,
    this.obscureText = false,
    this.autofocus = false,
    this.readOnly = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTapOutside,
    this.suffix,
    this.minLines,
    this.maxLines = 1,
    this.semanticLabel,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.inlineError = false,
  });

  /// Key for the inner [TextField] (tests: `enterText(find.byKey(...))`).
  final Key? fieldKey;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hintText;
  final String? errorText;
  final PaperTextFieldSize size;
  final bool enabled;
  final bool obscureText;
  final bool autofocus;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final TapRegionCallback? onTapOutside;

  /// Trailing control inside the field's right edge (e.g. a 24
  /// [PaperIconButton]: clear, show/hide password). Sits 8 from the border.
  final Widget? suffix;
  final int? minLines;

  /// 1 = single line; null/greater = textarea (`resize-y`, +20 per row).
  final int? maxLines;
  final String? semanticLabel;
  final TextCapitalization textCapitalization;
  final bool autocorrect;

  /// `text-xs`, mt 4 error line (inline rows) instead of `text-sm`, mt 6.
  final bool inlineError;

  @override
  Widget build(BuildContext context) {
    final c = context.paper;
    final style = size == PaperTextFieldSize.md
        ? PaperTypography.input(c)
        : PaperTypography.input(c).copyWith(
            fontSize: size.fontSize,
            height: size.lineHeight / size.fontSize,
          );
    final hasError = errorText != null && errorText!.isNotEmpty;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: PaperRadii.borderMd,
      borderSide: BorderSide(color: color, width: width),
    );
    final field = TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
      onTapOutside: onTapOutside,
      minLines: minLines,
      maxLines: obscureText ? 1 : maxLines,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      style: style,
      cursorColor: PaperWeb.accent,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: PaperWeb.gray900,
        hintText: hintText,
        hintStyle: style.copyWith(color: PaperWeb.gray400),
        semanticCounterText: '',
        contentPadding: EdgeInsets.symmetric(
          horizontal: size.paddingX,
          vertical: size.paddingY,
        ),
        border: border(hasError ? PaperWeb.red500 : PaperWeb.gray700, 1),
        enabledBorder: border(hasError ? PaperWeb.red500 : PaperWeb.gray700, 1),
        disabledBorder: border(PaperWeb.gray700, 1),
        focusedBorder: border(
          hasError ? PaperWeb.red500 : PaperWeb.accent,
          PaperElevation.focusRingWidth,
        ),
        suffixIcon: suffix == null
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: suffix,
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
    );
    final Widget box = Opacity(opacity: enabled ? 1 : 0.5, child: field);
    if (label == null && !hasError) {
      return semanticLabel == null
          ? box
          : Semantics(label: semanticLabel, child: box);
    }
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(label!, style: t.labelLarge?.copyWith(color: PaperWeb.gray300)),
          const SizedBox(height: PaperSpacing.tw1_5),
        ],
        box,
        if (hasError) ...<Widget>[
          SizedBox(height: inlineError ? PaperSpacing.tw1 : PaperSpacing.tw1_5),
          Semantics(
            liveRegion: true,
            child: Text(
              errorText!,
              style: (inlineError ? t.bodySmall : t.bodyMedium)?.copyWith(
                color: PaperWeb.red400,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// `GlossarySearch` field (components.md §4.2): a [PaperTextField.md] with
/// no leading icon and a 24px `×` clear button while there is text.
class PaperSearchField extends StatefulWidget {
  const PaperSearchField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.hintText,
    required this.clearTooltip,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String hintText;

  /// Tooltip + semantics label of the clear button.
  final String clearTooltip;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;

  @override
  State<PaperSearchField> createState() => _PaperSearchFieldState();
}

class _PaperSearchFieldState extends State<PaperSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(PaperSearchField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) => PaperTextField(
    fieldKey: widget.fieldKey,
    controller: widget.controller,
    focusNode: widget.focusNode,
    hintText: widget.hintText,
    enabled: widget.enabled,
    autofocus: widget.autofocus,
    textInputAction: TextInputAction.search,
    onChanged: widget.onChanged,
    onSubmitted: widget.onSubmitted,
    suffix: widget.controller.text.isEmpty
        ? null
        : PaperIconButton(
            size: PaperIconButtonSize.s24,
            tooltip: widget.clearTooltip,
            icon: const PaperCloseGlyph(),
            onPressed: () {
              widget.controller.clear();
              widget.onChanged?.call('');
            },
          ),
  );
}
