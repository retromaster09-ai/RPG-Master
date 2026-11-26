import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:material_ui/material_ui.dart';

bool isDesktopWebLogin(double width) =>
    kIsWeb &&
    width >= 760 &&
    switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => true,
      _ => false,
    };

class LoginLayout extends StatelessWidget {
  const LoginLayout({super.key, required this.form, this.soundControl});

  final Widget form;
  final Widget? soundControl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xffd7a25f),
      brightness: Brightness.dark,
    );
    return Theme(
      data: theme.copyWith(
        colorScheme: colors,
        textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xa60b1028),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 13,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(5),
            borderSide: const BorderSide(color: Color(0xff777492)),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style:
              FilledButton.styleFrom(
                foregroundColor: const Color(0xff23142a),
                backgroundColor: const Color(0xfff6c981),
                textStyle: const TextStyle(
                  fontFamily: 'Crimson Text',
                  fontWeight: FontWeight.w700,
                  fontSize: 25,
                ),
                minimumSize: const Size(0, 49),
                shape: const BeveledRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(9)),
                  side: BorderSide(color: Color(0xffffe6ae)),
                ),
              ).copyWith(
                backgroundBuilder: (context, states, child) {
                  if (states.contains(WidgetState.disabled)) return child!;
                  return DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xffffe2a4), Color(0xffde9950)],
                      ),
                    ),
                    child: child,
                  );
                },
              ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xffffe1ad),
            textStyle: const TextStyle(fontSize: 13),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
            minimumSize: const Size(0, 44),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xff0b1028),
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final portrait =
                constraints.maxWidth <= 740 &&
                constraints.maxHeight > constraints.maxWidth;
            final desktop = isDesktopWebLogin(constraints.maxWidth);
            final insets = MediaQuery.paddingOf(context);
            final keyboard = MediaQuery.viewInsetsOf(context).bottom;
            final short = constraints.maxHeight <= 650;
            final horizontal = portrait ? 20.0 : (short ? 32.0 : 56.0);
            final padding = EdgeInsets.fromLTRB(
              horizontal + insets.left,
              (portrait ? 24.0 : (short ? 20.0 : 54.0)) + insets.top,
              horizontal + insets.right,
              (portrait ? 10.0 : (short ? 20.0 : 32.0)) +
                  insets.bottom +
                  keyboard,
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                if (desktop)
                  const _DesktopLoginArt()
                else
                  Image.asset(
                    portrait
                        ? 'assets/brand/login-party-portrait.webp'
                        : 'assets/brand/login-party.webp',
                    key: const ValueKey('login-art'),
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.1),
                    excludeFromSemantics: true,
                    filterQuality: FilterQuality.medium,
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.26, 0.60, 1],
                      colors: [
                        Color(portrait ? 0xa6070a22 : 0x7906091d),
                        Colors.transparent,
                        Colors.transparent,
                        Color(portrait ? 0x59090b23 : 0x8c070a23),
                      ],
                    ),
                  ),
                ),
                SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: padding,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - padding.vertical)
                          .clamp(0.0, double.infinity),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Align(
                          alignment: portrait
                              ? Alignment.topCenter
                              : Alignment.topLeft,
                          child: _LoginBrand(portrait: portrait, short: short),
                        ),
                        const SizedBox(height: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 378),
                          child: _LoginPanel(portrait: portrait, child: form),
                        ),
                      ],
                    ),
                  ),
                ),
                if (desktop && soundControl != null)
                  Positioned(
                    top: insets.top + 16,
                    right: insets.right + 18,
                    child: soundControl!,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DesktopLoginArt extends StatelessWidget {
  const _DesktopLoginArt();

  static const _asset = 'assets/brand/login-party.webp';
  static const _aspect = 1.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= constraints.maxHeight * _aspect;
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Image.asset(
                  _asset,
                  fit: BoxFit.cover,
                  color: const Color(0x66101630),
                  colorBlendMode: BlendMode.srcATop,
                  excludeFromSemantics: true,
                ),
              ),
            ),
            Center(
              child: SizedBox(
                width: math.min(
                  constraints.maxWidth,
                  constraints.maxHeight * _aspect,
                ),
                height: math.min(
                  constraints.maxHeight,
                  constraints.maxWidth / _aspect,
                ),
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: LinearGradient(
                    begin: wide ? Alignment.centerLeft : Alignment.topCenter,
                    end: wide ? Alignment.centerRight : Alignment.bottomCenter,
                    stops: const [0, 0.055, 0.945, 1],
                    colors: const [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                  ).createShader,
                  child: Image.asset(
                    _asset,
                    key: const ValueKey('login-art'),
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({required this.portrait, required this.child});

  final bool portrait;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(11));
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xbaf9cf86)),
                borderRadius: radius,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x9c1d224b),
                    Color(0xa3111425),
                    Color(0x9928213e),
                  ],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  portrait ? 16 : 24,
                  portrait ? 13 : 22,
                  portrait ? 16 : 24,
                  portrait ? 6 : 13,
                ),
                child: child,
              ),
            ),
          ),
        ),
        Positioned(
          top: -4,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 8,
              height: 8,
              color: const Color(0xffe6b974),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginBrand extends StatelessWidget {
  const _LoginBrand({required this.portrait, required this.short});

  final bool portrait;
  final bool short;

  @override
  Widget build(BuildContext context) {
    final emblemSize = portrait ? 46.0 : (short ? 51.0 : 76.0);
    final emblem = Image.asset(
      'assets/brand/emblem.png',
      key: const ValueKey('login-emblem'),
      width: emblemSize,
      height: emblemSize,
      excludeFromSemantics: true,
    );
    final title = Semantics(
      header: true,
      label: 'RPG Master Set',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'RPG Master',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xffffebbf),
              fontFamily: 'Crimson Text',
              fontSize: portrait ? 38 : (short ? 40 : 56),
              fontWeight: FontWeight.w700,
              height: 1,
              shadows: const [
                Shadow(color: Color(0xff71481e), offset: Offset(0, 2)),
                Shadow(color: Colors.black, blurRadius: 12),
              ],
            ),
          ),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 35,
                child: Divider(color: Color(0xffc8a36d), thickness: 1),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'SET',
                  style: TextStyle(
                    fontFamily: 'Crimson Text',
                    color: Color(0xffffebbf),
                    letterSpacing: 4,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
              ),
              SizedBox(
                width: 35,
                child: Divider(color: Color(0xffc8a36d), thickness: 1),
              ),
            ],
          ),
        ],
      ),
    );
    return portrait
        ? Column(children: [emblem, const SizedBox(height: 7), title])
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              emblem,
              const SizedBox(width: 14),
              Flexible(child: title),
            ],
          );
  }
}
