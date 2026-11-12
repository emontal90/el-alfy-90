import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_erp/components/order_card.dart';
import 'package:furniture_erp/core/order_delivery_helper.dart';
import 'package:furniture_erp/screens/dashboard_screen.dart';

void main() {
  group('DashboardScreen.calculateUpholstererWorkshopStats', () {
    test('calculates full sets only when all pieces match full sets', () {
      final batches = [
        {
          'category_id': 1,
          'total_sent': 8,
          'received_qty': 0,
          'pieces_json': jsonEncode([
            {'name': 'كنبة كبيرة', 'base_qty': 1, 'sent_qty': 2, 'received_qty': 0},
            {'name': 'كنبة صغيرة', 'base_qty': 1, 'sent_qty': 2, 'received_qty': 0},
            {'name': 'فوتيه', 'base_qty': 2, 'sent_qty': 4, 'received_qty': 0},
          ]),
        },
      ];

      final stats = DashboardScreen.calculateUpholstererWorkshopStats(
        batches,
        {1: 3},
      );

      expect(stats['sets'], 2);
      expect(stats['individual'], 0);
      expect(stats['totalPieces'], 8);
    });

    test('splits full sets and excess individual pieces after partial receipt', () {
      final batches = [
        {
          'category_id': 1,
          'total_sent': 8,
          'received_qty': 1,
          'pieces_json': jsonEncode([
            {'name': 'كنبة كبيرة', 'base_qty': 1, 'sent_qty': 2, 'received_qty': 1},
            {'name': 'كنبة صغيرة', 'base_qty': 1, 'sent_qty': 2, 'received_qty': 0},
            {'name': 'فوتيه', 'base_qty': 2, 'sent_qty': 4, 'received_qty': 0},
          ]),
        },
      ];

      final stats = DashboardScreen.calculateUpholstererWorkshopStats(
        batches,
        {1: 3},
      );

      expect(stats['sets'], 1);
      expect(stats['individual'], 3);
      expect(stats['totalPieces'], 7);
    });

    test('counts partial-component batch as individual pieces only and ignores completed batches', () {
      final batches = [
        {
          'category_id': 1,
          'total_sent': 2,
          'received_qty': 0,
          'pieces_json': jsonEncode([
            {'name': 'فوتيه', 'base_qty': 2, 'sent_qty': 2, 'received_qty': 0},
          ]),
        },
        {
          'category_id': 1,
          'total_sent': 4,
          'received_qty': 4,
          'pieces_json': jsonEncode([
            {'name': 'كنبة كبيرة', 'base_qty': 1, 'sent_qty': 1, 'received_qty': 1},
            {'name': 'كنبة صغيرة', 'base_qty': 1, 'sent_qty': 1, 'received_qty': 1},
            {'name': 'فوتيه', 'base_qty': 2, 'sent_qty': 2, 'received_qty': 2},
          ]),
        },
      ];

      final stats = DashboardScreen.calculateUpholstererWorkshopStats(
        batches,
        {1: 3},
      );

      expect(stats['sets'], 0);
      expect(stats['individual'], 2);
      expect(stats['totalPieces'], 2);
    });
  });

  group('OrderDeliveryHelper', () {
    final categoryComps = [
      {'name': 'كنبة كبيرة', 'base_qty': 1, 'qty': 2},
      {'name': 'كنبة صغيرة', 'base_qty': 1, 'qty': 2},
      {'name': 'فوتيه', 'base_qty': 2, 'qty': 4},
    ];

    test('extractOrderPieces preserves base_qty or falls back to category base_qty * setsCount', () {
      final explicit = OrderDeliveryHelper.extractOrderPieces(
        [
          {'name': 'فوتيه', 'qty': 2},
        ],
        categoryComps,
        setsCount: 2,
      );
      expect(explicit, [
        {'name': 'فوتيه', 'qty': 2, 'base_qty': 2},
      ]);

      final fallback = OrderDeliveryHelper.extractOrderPieces(
        const [],
        categoryComps,
        setsCount: 2,
      );
      expect(fallback, [
        {'name': 'كنبة كبيرة', 'qty': 2, 'base_qty': 1},
        {'name': 'كنبة صغيرة', 'qty': 2, 'base_qty': 1},
        {'name': 'فوتيه', 'qty': 4, 'base_qty': 2},
      ]);
    });

    test('computeDelivery handles full delivery and deducts showroom stock & sets', () {
      final orderPieces = OrderDeliveryHelper.extractOrderPieces(
        const [],
        categoryComps,
        setsCount: 1,
      );

      final result = OrderDeliveryHelper.computeDelivery(
        orderPieces: orderPieces,
        deliverQuantities: {
          'كنبة كبيرة': 1,
          'كنبة صغيرة': 1,
          'فوتيه': 2,
        },
        rawCategoryComps: categoryComps,
      );

      expect(result.isFullDelivery, isTrue);
      expect(result.deliveredSets, 1);
      expect(result.deliveredIndividualPieces, 0);
      expect(result.totalDeliveredPieces, 4);
      expect(result.totalRemainingPieces, 0);
      expect(result.remainingComps, isEmpty);
      expect(result.remainingOrderSets, 0);
      expect(result.newCategorySets, 1);
      expect(result.updatedCategoryComps, [
        {'name': 'كنبة كبيرة', 'base_qty': 1, 'qty': 1},
        {'name': 'كنبة صغيرة', 'base_qty': 1, 'qty': 1},
        {'name': 'فوتيه', 'base_qty': 2, 'qty': 2},
      ]);
    });

    test('computeDelivery handles partial piece delivery, splits remaining, and recalculates showroom sets', () {
      final orderPieces = [
        {'name': 'كنبة كبيرة', 'qty': 1, 'base_qty': 1},
        {'name': 'كنبة صغيرة', 'qty': 1, 'base_qty': 1},
        {'name': 'فوتيه', 'qty': 2, 'base_qty': 2},
      ];

      final result = OrderDeliveryHelper.computeDelivery(
        orderPieces: orderPieces,
        deliverQuantities: {
          'كنبة كبيرة': 1,
          'كنبة صغيرة': 0,
          'فوتيه': 1,
        },
        rawCategoryComps: categoryComps,
      );

      expect(result.isFullDelivery, isFalse);
      expect(result.totalDeliveredPieces, 2);
      expect(result.totalRemainingPieces, 2);
      expect(result.deliveredComps, [
        {'name': 'كنبة كبيرة', 'qty': 1, 'base_qty': 1},
        {'name': 'فوتيه', 'qty': 1, 'base_qty': 2},
      ]);
      expect(result.remainingComps, [
        {'name': 'كنبة صغيرة', 'qty': 1, 'base_qty': 1},
        {'name': 'فوتيه', 'qty': 1, 'base_qty': 2},
      ]);
      expect(result.remainingOrderSets, 0);
      expect(result.remainingIndividualPieces, 2);
      expect(result.newCategorySets, 1);
      expect(result.updatedCategoryComps, [
        {'name': 'كنبة كبيرة', 'base_qty': 1, 'qty': 1},
        {'name': 'كنبة صغيرة', 'base_qty': 1, 'qty': 2},
        {'name': 'فوتيه', 'base_qty': 2, 'qty': 3},
      ]);
    });

    test('buildDeliverQuantities delivers 1 set out of 2 sets, or 1 piece leaving 1 set + 3 individual', () {
      final twoSetPieces = OrderDeliveryHelper.extractOrderPieces(
        const [],
        categoryComps,
        setsCount: 2,
      );

      // 1) اختيار 1 طقم كامل من أصل 2 طقم
      final oneSetMap = OrderDeliveryHelper.buildDeliverQuantities(
        orderPieces: twoSetPieces,
        deliverSets: 1,
        extraPieceQuantities: const {},
      );
      expect(oneSetMap, {'كنبة كبيرة': 1, 'كنبة صغيرة': 1, 'فوتيه': 2});

      final oneSetResult = OrderDeliveryHelper.computeDelivery(
        orderPieces: twoSetPieces,
        deliverQuantities: oneSetMap,
        rawCategoryComps: categoryComps,
      );
      expect(oneSetResult.deliveredSets, 1);
      expect(oneSetResult.deliveredIndividualPieces, 0);
      expect(oneSetResult.remainingOrderSets, 1);
      expect(oneSetResult.remainingIndividualPieces, 0);

      // 2) تسليم قطعة واحدة فقط من أصل 2 طقم -> يتبقى 1 طقم + 3 فردي
      final onePieceMap = OrderDeliveryHelper.buildDeliverQuantities(
        orderPieces: twoSetPieces,
        deliverSets: 0,
        extraPieceQuantities: const {'فوتيه': 1},
      );
      final onePieceResult = OrderDeliveryHelper.computeDelivery(
        orderPieces: twoSetPieces,
        deliverQuantities: onePieceMap,
        rawCategoryComps: categoryComps,
      );
      expect(onePieceResult.deliveredSets, 0);
      expect(onePieceResult.deliveredIndividualPieces, 1);
      expect(onePieceResult.remainingOrderSets, 1);
      expect(onePieceResult.remainingIndividualPieces, 3);
      expect(
        OrderSetSummary(
          sets: onePieceResult.remainingOrderSets,
          individualPieces: onePieceResult.remainingIndividualPieces,
          totalPieces: onePieceResult.totalRemainingPieces,
        ).toOrangeBadgeLabel(),
        '1 طقم + 3 فردي',
      );
    });
  });

  testWidgets('OrderCard shows mixed sets + individual label in orange badge', (tester) async {
    final categoryComps = [
      {'name': 'كنبة كبيرة', 'base_qty': 1, 'qty': 2},
      {'name': 'كنبة صغيرة', 'base_qty': 1, 'qty': 2},
      {'name': 'فوتيه', 'base_qty': 2, 'qty': 4},
    ];
    final partialWaitingOrder = {
      'id': 20,
      'customer_name': 'محمود حسن',
      'category_name': 'كنز',
      'order_type': 'نمطي',
      'sets_count': 1,
      'delivery_date': '2026-11-15',
      'selected_components_json': jsonEncode([
        {'name': 'كنبة كبيرة', 'qty': 2, 'base_qty': 1},
        {'name': 'كنبة صغيرة', 'qty': 2, 'base_qty': 1},
        {'name': 'فوتيه', 'qty': 3, 'base_qty': 2},
      ]),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: OrderCard(
              order: partialWaitingOrder,
              categoryComponents: categoryComps,
              collapsible: true,
              isExpanded: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('1 طقم + 3 فردي'), findsOneWidget);
    expect(find.text('(7 قطعة)'), findsOneWidget);
  });

  testWidgets('Delivered OrderCard collapses summary and expands on tap', (tester) async {
    bool isExpanded = false;
    final sampleOrder = {
      'id': 10,
      'customer_name': 'أحمد علي',
      'category_name': 'كنز',
      'order_type': 'نمطي',
      'sets_count': 1,
      'delivery_date': '2026-11-10',
      'created_at': '2026-11-01 10:00:00',
      'specs': 'قماش كتان رمادي',
      'selected_components_json': jsonEncode([
        {'name': 'كنبة كبيرة', 'qty': 1},
        {'name': 'فوتيه', 'qty': 2},
      ]),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return OrderCard(
                  order: sampleOrder,
                  isDelivered: true,
                  collapsible: true,
                  isExpanded: isExpanded,
                  onToggleExpand: () => setState(() => isExpanded = !isExpanded),
                );
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('أحمد علي'), findsOneWidget);
    expect(find.text('طقم: كنز'), findsOneWidget);
    expect(find.text('قطع ومكونات الطلب:'), findsNothing);
    expect(find.text('المواصفات: قماش كتان رمادي'), findsNothing);

    await tester.tap(find.byType(OrderCard));
    await tester.pumpAndSettle();

    expect(find.text('قطع ومكونات الطلب:'), findsOneWidget);
    expect(find.text('المواصفات: قماش كتان رمادي'), findsOneWidget);
    expect(find.text('كنبة كبيرة'), findsOneWidget);
    expect(find.text('تسليم الطلب'), findsNothing);
  });
}

