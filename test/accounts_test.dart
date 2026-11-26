import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rpg_master_set/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('login empilha no celular e abre lado a lado no PC', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 820));
    await tester.pumpWidget(
      MaterialApp(home: SignInScreen(client: _UnusedSupabase())),
    );
    final brand = find.text('RPG Master Set');
    final form = find.byType(Form);
    expect(tester.getRect(brand).bottom, lessThan(tester.getRect(form).top));
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    await tester.pumpAndSettle();
    expect(tester.getRect(brand).right, lessThan(tester.getRect(form).left));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a entrada prioriza o nome de usuário e oferece a vinculação antiga',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SignInScreen(client: _UnusedSupabase())),
      );
      expect(find.text('Nome de usuário'), findsOneWidget);
      expect(find.text('E-mail da conta antiga'), findsNothing);
      await tester.ensureVisible(
        find.text('Primeiro acesso com a conta antiga'),
      );
      await tester.tap(find.text('Primeiro acesso com a conta antiga'));
      await tester.pumpAndSettle();
      expect(find.text('E-mail da conta antiga'), findsOneWidget);
      await tester.ensureVisible(find.text('Usar nome de usuário'));
      await tester.tap(find.text('Usar nome de usuário'));
      await tester.pumpAndSettle();
      expect(find.text('Nome de usuário'), findsOneWidget);
    },
  );

  testWidgets('recuperação abre e recebe o código e a nova senha', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SignInScreen(client: _UnusedSupabase())),
    );
    await tester.ensureVisible(find.text('Esqueci minha senha'));
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();
    expect(find.text('Pedir código ao mestre'), findsOneWidget);
    await tester.tap(find.text('Já tenho um código'));
    await tester.pumpAndSettle();
    expect(find.text('Código do mestre ou de reserva'), findsOneWidget);
    expect(find.text('Nova senha'), findsOneWidget);
  });
}

class _UnusedSupabase extends Fake implements SupabaseClient {}
