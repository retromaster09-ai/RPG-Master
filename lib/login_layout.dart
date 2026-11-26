import 'package:material_ui/material_ui.dart';

/// Keeps the sign-in form usable in a narrow window or with the keyboard open.
class LoginLayout extends StatelessWidget {
  const LoginLayout({super.key, required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xffd7a25f),
      brightness: Brightness.dark,
      surface: const Color(0xff1c1927),
    );
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: colors,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xff15121f),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xff14101d),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.65, -0.8),
              radius: 1.25,
              colors: [Color(0xff28375d), Color(0xff14101d)],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 840;
                final padding = wide ? 40.0 : 20.0;
                final brand = _LoginBrand(wide: wide);
                final panel = Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border.all(color: const Color(0xff5c4655)),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(wide ? 28 : 20),
                        child: form,
                      ),
                    ),
                  ),
                );
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.all(padding),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 2 * padding).clamp(
                        0.0,
                        double.infinity,
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: wide
                            ? Row(
                                children: [
                                  Expanded(child: brand),
                                  const SizedBox(width: 32),
                                  Expanded(child: panel),
                                ],
                              )
                            : Column(
                                children: [
                                  brand,
                                  const SizedBox(height: 20),
                                  panel,
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginBrand extends StatelessWidget {
  const _LoginBrand({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        children: [
          DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xffb99766)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 3 / 2,
                child: Image.asset(
                  'assets/brand/login-party.webp',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
          SizedBox(height: wide ? 20 : 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/brand/emblem.png',
                width: wide ? 56 : 36,
                height: wide ? 56 : 36,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'RPG Master Set',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Crimson Text',
                    color: const Color(0xffffe0b9),
                    fontSize: wide ? 48 : 32,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
