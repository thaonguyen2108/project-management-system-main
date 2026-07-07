import 'package:flutter/material.dart';
import 'package:todo/core/app_style.dart';

Widget input({
  TextEditingController? controller,
  String? label,
  String? hint,
  bool isPassword = false,
  TextInputType keyboard = TextInputType.text,
  int maxLines = 1,
  int minLines = 1,
  ValueChanged<String>? onChanged,
  IconData? prefixIcon,
  Color? activeColor,
  double radius = 15.0,
  bool hasShadow = false,
  VoidCallback? onClear,
}) {
  return Builder(
    builder: (context) {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: hasShadow
              ? const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboard,
          maxLines: maxLines,
          minLines: minLines,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: colors.onSurface,
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: TextStyle(
              color: colors.onSurfaceVariant.withValues(alpha: 0.72),
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: activeColor ?? colors.primary)
                : null,
            suffixIcon: controller != null && controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                      onClear?.call();
                    },
                  )
                : null,
            filled: true,
            fillColor:
                theme.inputDecorationTheme.fillColor ??
                colors.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(color: colors.outlineVariant, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(
                color: activeColor ?? colors.primary,
                width: 2,
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget formInput({
  TextEditingController? controller,
  String? label,
  String? hint,
  bool isPassword = false,
  bool isEnabled = true,
  TextInputType keyboard = TextInputType.text,
  int maxLines = 1,
  int minLines = 1,
  IconData? prefixIcon,
  Widget? suffixIcon,
  String? Function(String?)? validator,
  Function(String)? onChanged,
  Color? fillColor,
  Color? labelColor,
  FontWeight? labelFontWeight,
  Color? borderColor,
  double borderRadius = 12.0,
  AutovalidateMode autovalidateMode = AutovalidateMode.onUserInteraction,
  EdgeInsets? contentPadding,
}) {
  return Builder(
    builder: (context) {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final isDark = theme.brightness == Brightness.dark;
      final forcedLightFill =
          fillColor == Colors.white ||
          fillColor == AppColors.surface ||
          fillColor == Colors.grey[100];
      final effectiveFill = isDark && forcedLightFill
          ? colors.surfaceContainerHighest
          : fillColor ?? theme.inputDecorationTheme.fillColor;
      final effectiveBorder = isDark
          ? colors.outlineVariant
          : Colors.grey.shade300;
      final effectiveLabelColor =
          labelColor ??
          (isDark ? colors.onSurfaceVariant : const Color(0xFF111827));

      return TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboard,
        maxLines: maxLines,
        minLines: minLines,
        enabled: isEnabled,
        validator: validator,
        onChanged: onChanged,
        autovalidateMode: autovalidateMode,
        style: TextStyle(fontSize: 16, color: colors.onSurface),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: colors.onSurfaceVariant)
              : null,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: effectiveFill,
          labelStyle: TextStyle(color: effectiveLabelColor),
          hintStyle: TextStyle(
            color: colors.onSurfaceVariant.withValues(alpha: 0.75),
          ),
          floatingLabelStyle: TextStyle(
            color: effectiveLabelColor,
            fontWeight: labelFontWeight ?? FontWeight.normal,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(color: effectiveBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(
              color: borderColor ?? colors.primary,
              width: 2,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(
              color: effectiveBorder.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(color: colors.error, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(color: colors.error, width: 2),
          ),
          contentPadding:
              contentPadding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      );
    },
  );
}

Widget button({
  required String label,
  required VoidCallback onPressed,
  double? width,
  double height = 48,
  Color? color,
  Color textColor = const Color.fromARGB(255, 0, 0, 0),
}) {
  return SizedBox(
    width: width,
    height: height,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}

Widget outlineButton({
  required String label,
  required VoidCallback onPressed,
  Color? color,
}) {
  return OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      side: color != null ? BorderSide(color: color) : null,
      foregroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: Text(label),
  );
}

Widget textButton({
  required String label,
  required VoidCallback onPressed,
  Color? color,
  TextStyle? style,
}) {
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: color),
    child: Text(label, style: style),
  );
}

Widget iconButton({
  required IconData icon,
  required VoidCallback onPressed,
  double size = 24,
  Color? color,
}) {
  return IconButton(
    onPressed: onPressed,
    icon: Icon(icon, size: size, color: color),
  );
}

Widget checkboxTile({
  required String title,
  Widget? titileWidget,
  int? maxLines,
  required bool value,
  required ValueChanged<bool?> onChanged,
  Color? activeColor,
  bool enalbe = true,
  EdgeInsetsGeometry? contentPadding,
  VisualDensity? visualDensity,
}) {
  return CheckboxListTile(
    title:
        titileWidget ??
        Text(title, overflow: TextOverflow.ellipsis, maxLines: maxLines),
    value: value,
    enabled: enalbe,
    onChanged: onChanged,
    activeColor: activeColor,
    contentPadding: contentPadding ?? EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    visualDensity: visualDensity ?? VisualDensity.compact,
  );
}

Widget pressable({
  required Widget child,
  GestureTapDownCallback? onTapDown,
  VoidCallback? onTap,
  VoidCallback? onDoubleTap,
  VoidCallback? onLongPress,
  BorderRadius? borderRadius,
}) {
  return InkWell(
    onTap: onTap,
    onDoubleTap: onDoubleTap,
    onLongPress: onLongPress,
    onTapDown: onTapDown,
    borderRadius: borderRadius ?? BorderRadius.circular(25),
    splashColor: Colors.black12,
    highlightColor: Colors.transparent,
    child: child,
  );
}

Widget radioTile<T>({
  required String title,
  required T value,
  required T? groupValue,
  required ValueChanged<T?> onChanged,
  Color? activeColor,
}) {
  // ignore: deprecated_member_use
  return RadioListTile<T>(
    title: Text(title),
    value: value,
    groupValue: groupValue,
    onChanged: onChanged,
    activeColor: activeColor,
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
  );
}

Widget toggleTile({
  required String title,
  required bool value,
  required ValueChanged<bool> onChanged,
  Color? activeColor,
  Color? inactiveColor,
}) {
  return SwitchListTile(
    title: Text(title),
    value: value,
    onChanged: onChanged,
    activeThumbColor: activeColor,
    inactiveThumbColor: inactiveColor,
    contentPadding: EdgeInsets.zero,
  );
}

Widget dropdown<T>({
  Widget? icon,
  required T? value,
  required List<T> list,
  required ValueChanged<T?> onChanged,
  Widget Function(T)? itemBuilder,
  double borderRadius = 15.0,
  String hint = "Chọn một mục",
  String? Function(T?)? validator,
  Color? dropdownColor,
  Color? fillColor,
  Color? textHintColor,
  Color? selectedColor,
}) {
  return Builder(
    builder: (context) {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final isDark = theme.brightness == Brightness.dark;
      final forcedLightFill =
          fillColor == Colors.white || fillColor == AppColors.surface;
      final effectiveFill = isDark && forcedLightFill
          ? colors.surfaceContainerHighest
          : fillColor ?? colors.surface;
      final effectiveDropdownColor = isDark
          ? colors.surfaceContainerHighest
          : dropdownColor ?? Colors.white;
      final effectiveTextColor = selectedColor ?? colors.onSurface;

      return DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        icon: icon,
        hint: Text(
          hint,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: textHintColor ?? colors.onSurfaceVariant),
        ),
        validator: validator,
        dropdownColor: effectiveDropdownColor,
        style: TextStyle(color: effectiveTextColor, fontSize: 14),
        decoration: InputDecoration(
          fillColor: effectiveFill,
          hintStyle: TextStyle(color: textHintColor ?? colors.onSurfaceVariant),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide(color: colors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          filled: true,
        ),
        items: list.map((T item) {
          return DropdownMenuItem<T>(
            value: item,
            child: DefaultTextStyle.merge(
              style: TextStyle(color: effectiveTextColor),
              child: itemBuilder != null
                  ? itemBuilder(item)
                  : Text(item.toString(), overflow: TextOverflow.ellipsis),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      );
    },
  );
}

class MenuOption {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  MenuOption({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });
}

void menu({
  required BuildContext context,
  required Offset tapPosition,
  required List<MenuOption> options,
}) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;

  showMenu<MenuOption>(
    context: context,
    position: RelativeRect.fromLTRB(
      tapPosition.dx,
      tapPosition.dy,
      tapPosition.dx + 1,
      tapPosition.dy + 1,
    ),
    color: theme.popupMenuTheme.color ?? colors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    items: options.map((opt) {
      final itemColor = opt.color ?? colors.onSurface;
      return PopupMenuItem<MenuOption>(
        value: opt,
        child: Row(
          children: [
            Icon(opt.icon, color: itemColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                opt.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: itemColor),
              ),
            ),
          ],
        ),
      );
    }).toList(),
  ).then((selectedOption) {
    selectedOption?.onTap();
  });
}

Future<T?> showAppModal<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  Widget? listButtons,
  double initialSize = 0.6,
  double minSize = 0.4,
  double maxSize = 0.9,
  bool isScrollable = true,
  Color? backgroundColor,
  double borderRadius = 20.0,
}) {
  double safeSheetSize(double value) {
    return value.clamp(0.0, 1.0).toDouble();
  }

  final safeMinSize = safeSheetSize(minSize);
  var safeMaxSize = safeSheetSize(maxSize);
  if (safeMaxSize < safeMinSize) safeMaxSize = safeMinSize;
  final safeInitialSize = safeSheetSize(
    initialSize,
  ).clamp(safeMinSize, safeMaxSize).toDouble();

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    isDismissible: true,
    enableDrag: true,
    builder: (context) {
      final viewInsets = MediaQuery.viewInsetsOf(context);
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final sheetColor = backgroundColor ?? colors.surface;
      final handleColor = colors.outlineVariant;

      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: DraggableScrollableSheet(
          initialChildSize: safeInitialSize,
          minChildSize: safeMinSize,
          maxChildSize: safeMaxSize,
          expand: false,
          snap: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(borderRadius),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: handleColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    if (title != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    Expanded(
                      child: isScrollable
                          ? SingleChildScrollView(
                              controller: scrollController,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.only(
                                left: 20,
                                right: 20,
                                top: 10,
                                bottom: 20,
                              ),
                              child: child,
                            )
                          : child,
                    ),
                    if (listButtons != null) listButtons,
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
