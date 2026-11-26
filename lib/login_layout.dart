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
              (portrait || desktop ? 24.0 : (short ? 20.0 : 54.0)) + insets.top,
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
                          alignment: portrait || desktop
                              ? Alignment.topCenter
                              : Alignment.topLeft,
                          child: desktop
                              ? _DesktopLoginTitle(short: short)
                              : _LoginBrand(portrait: portrait, short: short),
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspect = constraints.maxWidth / constraints.maxHeight;
        final widescreen = aspect >= 1.5;
        return Image.asset(
          widescreen
              ? 'assets/brand/login-party-wide.webp'
              : 'assets/brand/login-party.webp',
          key: const ValueKey('login-art'),
          // A narrower window can trim the extension outside the original scene.
          fit: widescreen ? BoxFit.fitHeight : BoxFit.contain,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.medium,
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

class _DesktopLoginTitle extends StatelessWidget {
  const _DesktopLoginTitle({required this.short});

  final bool short;

  @override
  Widget build(BuildContext context) {
    final lettering = TextStyle(
      fontFamily: 'Cinzel Decorative',
      fontWeight: FontWeight.w900,
      fontSize: short ? 42 : 58,
      height: 1.10,
      letterSpacing: 0.4,
    );
    const gold = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xfffff1bc),
        Color(0xffffd577),
        Color(0xffc68137),
        Color(0xffffcf82),
      ],
      stops: [0.15, 0.48, 0.72, 0.94],
    );
    return Semantics(
      header: true,
      label: 'RPG Master Set',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Text(
                  'RPG MASTER',
                  style: lettering.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 8
                      ..strokeJoin = StrokeJoin.round
                      ..color = const Color(0xff211529),
                    shadows: const [
                      Shadow(
                        color: Color(0xee100914),
                        offset: Offset(0, 4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                Text(
                  'RPG MASTER',
                  style: lettering.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 3
                      ..strokeJoin = StrokeJoin.round
                      ..color = const Color(0xffad6b36),
                  ),
                ),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: gold.createShader,
                  child: Text('RPG MASTER', style: lettering),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TitleRule(short: short),
                const Padding(
                  padding: EdgeInsets.only(left: 15, right: 10),
                  child: Text(
                    'SET',
                    style: TextStyle(
                      color: Color(0xffffe5a7),
                      fontFamily: 'Cinzel Decorative',
                      fontWeight: FontWeight.w900,
                      fontSize: 21,
                      letterSpacing: 5,
                      height: 1.15,
                      shadows: [
                        Shadow(color: Color(0xff180f24), blurRadius: 8),
                        Shadow(color: Color(0xff180f24), offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
                _TitleRule(short: short, mirrored: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleRule extends StatelessWidget {
  const _TitleRule({required this.short, this.mirrored = false});

  final bool short;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: short ? 68 : 91,
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: mirrored ? Alignment.centerRight : Alignment.centerLeft,
          end: mirrored ? Alignment.centerLeft : Alignment.centerRight,
          colors: const [Colors.transparent, Color(0xfff6d289)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x9418102d), blurRadius: 5)],
      ),
    );
  }
}
