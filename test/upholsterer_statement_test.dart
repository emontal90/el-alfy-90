import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_erp/core/upholsterer_statement_helper.dart';
import 'package:furniture_erp/screens/upholsterer_statement_screen.dart';

void main() {
  final categories = [
    {
      'id': 1,
      'name': 'كنز',
      'components_json': jsonEncode([
        {'name': 'كنبة كبيرة', 'base_qty': 1, 'qty': 0},
        {'name': 'كنبة صغيرة', 'base_qty': 1, 'qty': 0},
        {'name': 'فوتيه', 'base_qty': 2, 'qty': 0},
      ]),
    },
    {
      'id': 2,
      'name': 'ماسة',
      'components_json': jsonEncode([
        {'name': 'كنبة كبيرة', 'base_qty': 1, 'qty': 0},
        {'name': 'كنبة صغيرة', 'base_qty': 1, 'qty': 0},
        {'name': 'فوتيه', 'base_qty': 1, 'qty': 0},
      ]),
    },
  ];

  group('UpholstererStatementHelper', () {
    test('separates sent and received groups and calculates sets + individual pieces accurately', () {
      final batches = [
        {
          'id': 1,
          'upholsterer_name': 'أحمد',
          'category_id': 1,
          'category_name': 'كنز',
          'total_sent': 9,
          'received_qty': 5,
          'sent_date': '2026-11-02',
          'received_date': '2026-11-05',
          'sets_sent': 2,
          'sets_received': 1,
          'pieces_json': jsonEncode([
            {
              'name': 'كنبة كبيرة',
              'base_qty': 1,
              'sent_qty': 2,
              'received_qty': 1,
              'sent_date': '2026-11-02',
              'received_date': '2026-11-05',
            },
            {
              'name': 'كنبة صغيرة',
              'base_qty': 1,
              'sent_qty': 2,
              'received_qty': 1,
              'sent_date': '2026-11-02',
              'received_date': '2026-11-05',
            },
            {
              'name': 'فوتيه',
              'base_qty': 2,
              'sent_qty': 5,
              'received_qty': 3,
              'sent_date': '2026-11-02',
              'received_date': '2026-11-05',
            },
          ]),
        },
        {
          'id': 2,
          'upholsterer_name': 'محمود',
          'category_id': 2,
          'category_name': 'ماسة',
          'total_sent': 3,
          'received_qty': 1,
          'sent_date': '2026-11-08',
          'received_date': '2026-11-10',
          'sets_sent': 1,
          'sets_received': 0,
          'pieces_json': jsonEncode([
            {
              'name': 'كنبة كبيرة',
              'base_qty': 1,
              'sent_qty': 1,
              'received_qty': 1,
              'sent_date': '2026-11-08',
              'received_date': '2026-11-10',
            },
            {
              'name': 'كنبة صغيرة',
              'base_qty': 1,
              'sent_qty': 1,
              'received_qty': 0,
              'sent_date': '2026-11-08',
              'received_date': null,
            },
            {
              'name': 'فوتيه',
              'base_qty': 1,
              'sent_qty': 1,
              'received_qty': 0,
              'sent_date': '2026-11-08',
              'received_date': null,
            },
          ]),
        },
      ];

      final report = UpholstererStatementHelper.buildStatement(
        batches: batches,
        transactions: const [],
        categories: categories,
        fromDate: DateTime(2026, 11, 1),
        toDate: DateTime(2026, 11, 12),
      );

      // التسليم للمنجد: كنز (2 طقم + 1 فردي) + ماسة (1 طقم) = 3 طقم و 1 فردي (12 قطعة)
      expect(report.deliveredToUpholsterer.totalSets, 3);
      expect(report.deliveredToUpholsterer.totalIndividualPieces, 1);
      expect(report.deliveredToUpholsterer.totalPieces, 12);
      expect(report.deliveredToUpholsterer.categorySummaries.length, 2);

      // الاستلام من المنجد: كنز (1 طقم + 1 فردي) + ماسة (0 طقم + 1 فردي) = 1 طقم و 2 فردي (6 قطع)
      expect(report.receivedFromUpholsterer.totalSets, 1);
      expect(report.receivedFromUpholsterer.totalIndividualPieces, 2);
      expect(report.receivedFromUpholsterer.totalPieces, 6);
    });

    test('filters by date range and category cleanly without duplicating tracked transactions', () {
      final batches = [
        {
          'id': 10,
          'upholsterer_name': 'حسن',
          'category_id': 1,
          'category_name': 'كنز',
          'total_sent': 8,
          'received_qty': 4,
          'sent_date': '2026-11-01',
          'received_date': '2026-11-09',
          'sets_sent': 2,
          'sets_received': 1,
          'pieces_json': jsonEncode([
            {'name': 'كنبة كبيرة', 'base_qty': 1, 'sent_qty': 2, 'received_qty': 1, 'received_date': '2026-11-09'},
            {'name': 'كنبة صغيرة', 'base_qty': 1, 'sent_qty': 2, 'received_qty': 1, 'received_date': '2026-11-09'},
            {'name': 'فوتيه', 'base_qty': 2, 'sent_qty': 4, 'received_qty': 2, 'received_date': '2026-11-09'},
          ]),
        },
      ];

      final transactions = [
        {
          'id': 1,
          'batch_id': 10,
          'upholsterer_name': 'حسن',
          'category_id': 1,
          'category_name': 'كنز',
          'action_type': 'send',
          'sets_count': 2,
          'pieces_json': jsonEncode([
            {'name': 'كنبة كبيرة', 'qty': 2, 'base_qty': 1},
            {'name': 'كنبة صغيرة', 'qty': 2, 'base_qty': 1},
            {'name': 'فوتيه', 'qty': 4, 'base_qty': 2},
          ]),
          'total_pieces': 8,
          'action_date': '2026-11-01',
          'created_at': '2026-11-01 10:00 ص',
        },
        {
          'id': 2,
          'batch_id': 10,
          'upholsterer_name': 'حسن',
          'category_id': 1,
          'category_name': 'كنز',
          'action_type': 'receive',
          'sets_count': 1,
          'pieces_json': jsonEncode([
            {'name': 'كنبة كبيرة', 'qty': 1, 'base_qty': 1},
            {'name': 'كنبة صغيرة', 'qty': 1, 'base_qty': 1},
            {'name': 'فوتيه', 'qty': 2, 'base_qty': 2},
          ]),
          'total_pieces': 4,
          'action_date': '2026-11-09',
          'created_at': '2026-11-09 04:00 م',
        },
      ];

      // فلترة من 05 إلى 10: يظهر الاستلام فقط ولا يظهر التسليم المسجل يوم 01، ولا يتكرر
      final report = UpholstererStatementHelper.buildStatement(
        batches: batches,
        transactions: transactions,
        categories: categories,
        fromDate: DateTime(2026, 11, 5),
        toDate: DateTime(2026, 11, 10),
        categoryNameFilter: 'كنز',
      );

      expect(report.deliveredToUpholsterer.isEmpty, isTrue);
      expect(report.receivedFromUpholsterer.totalSets, 1);
      expect(report.receivedFromUpholsterer.totalIndividualPieces, 0);
      expect(report.receivedFromUpholsterer.totalPieces, 4);
      expect(report.receivedFromUpholsterer.operationsCount, 1);
    });

    test('parses Arabic-Indic digits and combines multi-day partial piece receipts into full sets', () {
      final transactions = [
        {
          'id': 100,
          'batch_id': 50,
          'upholsterer_name': 'سعيد',
          'category_id': 1,
          'category_name': 'كنز',
          'action_type': 'receive',
          'sets_count': 0,
          'pieces_json': jsonEncode([
            {'name': 'كنبة كبيرة', 'qty': 1, 'base_qty': 1},
          ]),
          'total_pieces': 1,
          'action_date': '٢٠٢٦-١١-٠٣',
          'created_at': '٢٠٢٦-١١-٠٣',
        },
        {
          'id': 101,
          'batch_id': 50,
          'upholsterer_name': 'سعيد',
          'category_id': 1,
          'category_name': 'كنز',
          'action_type': 'receive',
          'sets_count': 0,
          'pieces_json': jsonEncode([
            {'name': 'كنبة صغيرة', 'qty': 1, 'base_qty': 1},
            {'name': 'فوتيه', 'qty': 3, 'base_qty': 2},
          ]),
          'total_pieces': 4,
          'action_date': '2026-11-06',
          'created_at': '2026-11-06',
        },
      ];

      final report = UpholstererStatementHelper.buildStatement(
        batches: const [],
        transactions: transactions,
        categories: categories,
        fromDate: DateTime(2026, 11, 1),
        toDate: DateTime(2026, 11, 10),
      );

      expect(report.receivedFromUpholsterer.totalSets, 1);
      expect(report.receivedFromUpholsterer.totalIndividualPieces, 1);
      expect(report.receivedFromUpholsterer.totalPieces, 5);
    });
  });

  group('UpholstererStatementScreen widget', () {
    testWidgets('renders filters, separate delivery/receipt sections, and WhatsApp share button', (tester) async {
      final today = UpholstererStatementHelper.formatIsoDate(DateTime.now());
      final preloadedTxs = [
        {
          'id': 1,
          'batch_id': 1,
          'upholsterer_name': 'أحمد',
          'category_id': 1,
          'category_name': 'كنز',
          'action_type': 'send',
          'sets_count': 2,
          'pieces_json': jsonEncode([
            {'name': 'كنبة كبيرة', 'qty': 2, 'base_qty': 1},
            {'name': 'كنبة صغيرة', 'qty': 2, 'base_qty': 1},
            {'name': 'فوتيه', 'qty': 4, 'base_qty': 2},
          ]),
          'total_pieces': 8,
          'action_date': today,
          'created_at': today,
        },
        {
          'id': 2,
          'batch_id': 1,
          'upholsterer_name': 'أحمد',
          'category_id': 1,
          'category_name': 'كنز',
          'action_type': 'receive',
          'sets_count': 1,
          'pieces_json': jsonEncode([
            {'name': 'كنبة كبيرة', 'qty': 1, 'base_qty': 1},
            {'name': 'كنبة صغيرة', 'qty': 1, 'base_qty': 1},
            {'name': 'فوتيه', 'qty': 3, 'base_qty': 2},
          ]),
          'total_pieces': 5,
          'action_date': today,
          'created_at': today,
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar', 'EG'),
          supportedLocales: const [Locale('ar', 'EG')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: UpholstererStatementScreen(
              preloadedBatches: const [],
              preloadedTransactions: preloadedTxs,
              preloadedCategories: categories,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('كشف حساب المنجد'), findsOneWidget);
      expect(find.text('من تاريخ'), findsOneWidget);
      expect(find.text('إلى تاريخ'), findsOneWidget);
      expect(find.text('إجمالي التسليم للمنجد'), findsOneWidget);
      expect(find.text('إجمالي الاستلام من المنجد'), findsOneWidget);
      expect(find.text('أولاً: التسليم للمنجد'), findsOneWidget);
      expect(find.text('ثانياً: الاستلام من المنجد'), findsOneWidget);
      expect(find.text('2 طقم'), findsWidgets);
      expect(find.text('1 طقم و 1 فردي'), findsWidgets);
      expect(find.text('مشاركة كشف الحساب على واتساب (صورة)'), findsOneWidget);
    });
  });
}

