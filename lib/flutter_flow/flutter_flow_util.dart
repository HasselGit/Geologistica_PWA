import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

T createModel<T>(BuildContext context, T Function() modelCreator) {
  return modelCreator();
}

void safeSetState(Function() fn) {
  fn();
}

dynamic valueOrDefault<T>(T? value, T defaultValue) {
  return value ?? defaultValue;
}

extension MapExtensions<K, V> on Map<K, V> {
  Map<K, V> get withoutNulls => Map.fromEntries(
        entries.where((e) => e.value != null),
      );
}

String serializeParam(dynamic param, ParamType type) {
  return param?.toString() ?? '';
}

enum ParamType { String, int, double, bool, DateTime, JSON }

extension NavigationExtensions on BuildContext {
  void goNamed(String name, {Map<String, String>? queryParameters, Object? extra}) {
    GoRouter.of(this).goNamed(
      name,
      queryParameters: queryParameters ?? {},
      extra: extra,
    );
  }

  void pushNamed(String name, {Map<String, String>? queryParameters, Object? extra}) {
    GoRouter.of(this).pushNamed(
      name,
      queryParameters: queryParameters ?? {},
      extra: extra,
    );
  }
}

class FFButtonOptions {
  const FFButtonOptions({
    this.height,
    this.width,
    this.color,
    this.textStyle,
    this.elevation,
    this.borderSide,
    this.borderRadius,
    this.padding,
    this.iconPadding,
  });

  final double? height;
  final double? width;
  final Color? color;
  final TextStyle? textStyle;
  final double? elevation;
  final BorderSide? borderSide;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? iconPadding;
}

class FFButtonWidget extends StatelessWidget {
  const FFButtonWidget({
    super.key,
    required this.text,
    required this.onPressed,
    required this.options,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final FFButtonOptions options;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: options.color,
        minimumSize: Size(options.width ?? double.infinity, options.height ?? 40),
        shape: RoundedRectangleBorder(
          borderRadius: options.borderRadius ?? BorderRadius.circular(8),
        ),
      ),
      child: Text(text, style: options.textStyle),
    );
  }
}

class TransitionInfo {
  TransitionInfo({
    this.hasTransition = false,
    this.transitionType,
    this.duration,
  });
  final bool hasTransition;
  final PageTransitionType? transitionType;
  final Duration? duration;
}

enum PageTransitionType { fade, bottomToTop, topToBottom, leftToRight, rightToLeft }
