import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parfum_im/core/utils/formatters.dart';
import 'package:parfum_im/widgets/common.dart';

void main() {
  group('Formatters.rupiah', () {
    test('formats thousands separators without decimals', () {
      expect(Formatters.rupiah(275000), 'Rp275.000');
      expect(Formatters.rupiah(0), 'Rp0');
    });

    test('abbreviates large amounts', () {
      expect(Formatters.rupiahShort(1250000), contains('jt'));
      expect(Formatters.rupiahShort(275000), contains('rb'));
    });
  });

  group('Formatters.date', () {
    test('renders a dash for missing timestamps', () {
      expect(Formatters.date(null), '-');
      expect(Formatters.dateTime(null), '-');
    });

    test('formats an ISO timestamp with Indonesian months', () {
      final value = DateTime(2026, 1, 15, 9, 30);

      expect(Formatters.date(value), '15 Jan 2026');
      expect(Formatters.dateTime(value), '15 Jan 2026, 09:30');
    });

    test('uses Indonesian month abbreviations, not English ones', () {
      expect(Formatters.date(DateTime(2026, 5, 1)), '1 Mei 2026');
      expect(Formatters.date(DateTime(2026, 8, 9)), '9 Agu 2026');
      expect(Formatters.date(DateTime(2026, 12, 25)), '25 Des 2026');
    });

    test('pads single-digit hours', () {
      expect(
        Formatters.dateTime(DateTime(2026, 2, 3, 7, 5)),
        '3 Feb 2026, 07:05',
      );
    });
  });

  group('common widgets', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('EmptyState renders its title and message', (tester) async {
      await tester.pumpWidget(
        wrap(
          const EmptyState(
            title: 'Keranjang masih kosong',
            message: 'Tambahkan produk pilihan Anda.',
          ),
        ),
      );

      expect(find.text('Keranjang masih kosong'), findsOneWidget);
      expect(find.text('Tambahkan produk pilihan Anda.'), findsOneWidget);
    });

    testWidgets('ErrorView shows the retry action when provided', (
      tester,
    ) async {
      var retried = 0;

      await tester.pumpWidget(
        wrap(
          ErrorView(message: 'Gagal memuat katalog', onRetry: () => retried++),
        ),
      );

      expect(find.text('Gagal memuat katalog'), findsOneWidget);

      await tester.tap(find.text('Coba lagi'));
      await tester.pump();

      expect(retried, 1);
    });

    testWidgets('ErrorView hides retry when no callback is given', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const ErrorView(message: 'Boom')));

      expect(find.text('Coba lagi'), findsNothing);
    });

    testWidgets('StatusChip shows the label', (tester) async {
      await tester.pumpWidget(
        wrap(
          const StatusChip(label: 'Menunggu Pembayaran', color: Colors.amber),
        ),
      );

      expect(find.text('Menunggu Pembayaran'), findsOneWidget);
    });
  });
}
