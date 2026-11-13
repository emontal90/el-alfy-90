import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furniture_erp/components/order_card.dart';
import 'package:furniture_erp/core/app_theme.dart';
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

    test('computes primary and secondary category stock deductions on multi-category order delivery', () {
      final kenzComps = [
        {'name': 'كنبة كبيرة', 'base_qty': 1, 'qty': 3},
        {'name': 'كنبة صغيرة', 'base_qty': 1, 'qty': 3},
        {'name': 'فوتيه', 'base_qty': 2, 'qty': 6},
      ];
      final maasaComps = [
        {'name': 'كنبة كبيرة', 'base_qty': 1, 'qty': 4},
        {'name': 'فوتيه', 'base_qty': 2, 'qty': 8},
      ];

      final orderPieces = OrderDeliveryHelper.extractOrderPieces(
        [
          {'name': 'كنبة كبيرة', 'qty': 2, 'base_qty': 1},
          {'name': 'كنبة صغيرة', 'qty': 2, 'base_qty': 1},
          {'name': 'فوتيه', 'qty': 4, 'base_qty': 2},
          {
            'name': 'كنبة كبيرة (ماسه)',
            'source_piece_name': 'كنبة كبيرة',
            'source_category_id': 2,
            'source_category_name': 'ماسه',
            'qty': 2,
            'base_qty': 0,
            'is_custom': true,
          },
        ],
        kenzComps,
        setsCount: 2,
      );

      final summary = OrderDeliveryHelper.summarizeOrder(
        orderComps: orderPieces,
        rawCategoryComps: kenzComps,
      );
      expect(summary.sets, 2);
      expect(summary.individualPieces, 2);
      expect(summary.toOrangeBadgeLabel(), '2 طقم + 2 فردي');

      final deliverMap = {
        for (final p in orderPieces) p['name'] as String: p['qty'] as int,
      };
      final calc = OrderDeliveryHelper.computeDelivery(
        orderPieces: orderPieces,
        deliverQuantities: deliverMap,
        rawCategoryComps: kenzComps,
        fallbackCategoryStock: 3,
        primaryCategoryId: 1,
      );

      // المخزن الأساسي (كنز) يخصم 2 طقم فقط ولا يتأثر بكنبة ماسه
      expect(calc.isFullDelivery, isTrue);
      expect(calc.newCategorySets, 1);
      expect(calc.updatedCategoryComps, [
        {'name': 'كنبة كبيرة', 'base_qty': 1, 'qty': 1},
        {'name': 'كنبة صغيرة', 'base_qty': 1, 'qty': 1},
        {'name': 'فوتيه', 'base_qty': 2, 'qty': 2},
      ]);

      // مخزن الصنف الآخر (ماسه) يخصم 2 كنبة كبيرة ويُعاد حساب أطقم ماسه
      final secUpdates = OrderDeliveryHelper.computeSecondaryCategoryStockUpdates(
        deliveredComps: calc.deliveredComps,
        primaryCategoryId: 1,
        categoriesById: {
          2: {
            'id': 2,
            'name': 'ماسه',
            'stock_qty': 4,
            'components_json': jsonEncode(maasaComps),
          },
        },
      );
      expect(secUpdates.length, 1);
      expect(secUpdates.first.categoryId, 2);
      expect(secUpdates.first.categoryName, 'ماسه');
      expect(secUpdates.first.newStockSets, 2);
      expect(secUpdates.first.updatedComps, [
        {'name': 'كنبة كبيرة', 'base_qty': 1, 'qty': 2},
        {'name': 'فوتيه', 'base_qty': 2, 'qty': 8},
      ]);
    });
  });

  testWidgets('OrderCard shows complete/excess/incomplete status labels and distinct نمطي/أوردر colors', (tester) async {
    final categoryComps = [
      {'name': 'كنبة كبيرة', 'base_qty': 1, 'qty': 2},
      {'name': 'كنبة صغيرة', 'base_qty': 1, 'qty': 2},
      {'name': 'فوتيه', 'base_qty': 2, 'qty': 4},
    ];

    // 1) زائد (1 طقم + 3 فردي) مع نوع نمطي (كحلي)
    final excessWaitingOrder = {
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

    // 2) كامل (2 طقم) مع نوع أوردر (أحمر)
    final completeOrder = {
      'id': 21,
      'customer_name': 'سعيد محمد',
      'category_name': 'كنز',
      'order_type': 'أوردر',
      'sets_count': 2,
      'delivery_date': '2026-11-16',
      'selected_components_json': jsonEncode([
        {'name': 'كنبة كبيرة', 'qty': 2, 'base_qty': 1},
        {'name': 'كنبة صغيرة', 'qty': 2, 'base_qty': 1},
        {'name': 'فوتيه', 'qty': 4, 'base_qty': 2},
      ]),
    };

    // 3) ناقص (0 طقم + 3 فردي)
    final incompleteOrder = {
      'id': 22,
      'customer_name': 'كريم عادل',
      'category_name': 'كنز',
      'order_type': 'نمطي',
      'sets_count': 0,
      'delivery_date': '2026-11-17',
      'selected_components_json': jsonEncode([
        {'name': 'كنبة كبيرة', 'qty': 1, 'base_qty': 1},
        {'name': 'كنبة صغيرة', 'qty': 1, 'base_qty': 1},
        {'name': 'فوتيه', 'qty': 1, 'base_qty': 2},
      ]),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ListView(
              children: [
                OrderCard(
                  order: excessWaitingOrder,
                  categoryComponents: categoryComps,
                  collapsible: true,
                  isExpanded: false,
                ),
                OrderCard(
                  order: completeOrder,
                  categoryComponents: categoryComps,
                  collapsible: true,
                  isExpanded: false,
                ),
                OrderCard(
                  order: incompleteOrder,
                  categoryComponents: categoryComps,
                  collapsible: true,
                  isExpanded: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('1 طقم + 3 فردي (زائد)'), findsOneWidget);
    expect(find.text('2 طقم (كامل)'), findsOneWidget);
    expect(find.text('0 طقم + 3 فردي (ناقص)'), findsOneWidget);

    final Container excessContainer = tester.widget(
      find.ancestor(
        of: find.text('1 طقم + 3 فردي (زائد)'),
        matching: find.byType(Container),
      ).first,
    );
    expect((excessContainer.decoration as BoxDecoration).color, const Color(0xFFA16207));

    final Container completeContainer = tester.widget(
      find.ancestor(
        of: find.text('2 طقم (كامل)'),
        matching: find.byType(Container),
      ).first,
    );
    expect((completeContainer.decoration as BoxDecoration).color, const Color(0xFFEF6C00));

    final Container incompleteContainer = tester.widget(
      find.ancestor(
        of: find.text('0 طقم + 3 فردي (ناقص)'),
        matching: find.byType(Container),
      ).first,
    );
    expect((incompleteContainer.decoration as BoxDecoration).color, const Color(0xFFA16207));

    final Container customTypeContainer = tester.widget(
      find.ancestor(
        of: find.text('أوردر'),
        matching: find.byType(Container),
      ).first,
    );
    expect((customTypeContainer.decoration as BoxDecoration).color, Colors.red.shade700);

    final Container standardTypeContainer = tester.widget(
      find.ancestor(
        of: find.text('نمطي'),
        matching: find.byType(Container),
      ).first,
    );
    expect((standardTypeContainer.decoration as BoxDecoration).color, AppTheme.primaryNavy);
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

  testWidgets('OrderCard shows إلغاء الطلب next to تعديل الطلب and triggers callback', (tester) async {
    bool deleteTriggered = false;
    bool editTriggered = false;

    final sampleWaitingOrder = {
      'id': 101,
      'customer_name': 'محمد إبراهيم',
      'category_name': 'صالون مودرن',
      'category_id': 1,
      'specs': '',
      'order_type': 'نمطي',
      'delivery_date': '2026-11-20',
      'status': 'waiting',
      'sets_count': 1,
      'selected_components_json': jsonEncode([
        {'name': 'كنبة كبيرة', 'qty': 1, 'base_qty': 1},
        {'name': 'فوتيه', 'qty': 2, 'base_qty': 2},
      ]),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: OrderCard(
              order: sampleWaitingOrder,
              isDelivered: false,
              collapsible: false,
              isExpanded: true,
              onDeletePressed: () => deleteTriggered = true,
              onEditPressed: () => editTriggered = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('إلغاء الطلب'), findsOneWidget);
    expect(find.text('تعديل الطلب'), findsOneWidget);

    await tester.tap(find.text('إلغاء الطلب'));
    await tester.pump();
    expect(deleteTriggered, isTrue);

    await tester.tap(find.text('تعديل الطلب'));
    await tester.pump();
    expect(editTriggered, isTrue);
  });

  test('Order piece quantity can be reduced to zero and summarizes accurately', () {
    final compsWithZero = [
      {'name': 'كنبة كبيرة', 'qty': 0, 'base_qty': 1},
      {'name': 'كنبة صغيرة', 'qty': 1, 'base_qty': 1},
      {'name': 'فوتيه', 'qty': 0, 'base_qty': 2},
    ];

    final summary = OrderDeliveryHelper.summarizeOrder(
      orderComps: compsWithZero,
      rawCategoryComps: [
        {'name': 'كنبة كبيرة', 'qty': 1},
        {'name': 'كنبة صغيرة', 'qty': 1},
        {'name': 'فوتيه', 'qty': 2},
      ],
      fallbackSetsCount: 1,
    );

    expect(summary.sets, 0);
    expect(summary.individualPieces, 1);
    expect(summary.totalPieces, 1);
    expect(summary.status, OrderCompletenessStatus.incomplete);
  });

  test('Adding pieces from another set in order edit attaches source_category metadata and preserves counts', () {
    final compsWithSecondary = [
      {'name': 'كنبة كبيرة', 'qty': 1, 'base_qty': 1},
      {
        'name': 'فوتيه (صالون لويس)',
        'source_piece_name': 'فوتيه',
        'source_category_id': 5,
        'source_category_name': 'صالون لويس',
        'base_qty': 0,
        'qty': 2,
        'is_custom': true,
      },
    ];

    final summary = OrderDeliveryHelper.summarizeOrder(
      orderComps: compsWithSecondary,
      rawCategoryComps: [
        {'name': 'كنبة كبيرة', 'qty': 1},
        {'name': 'كنبة صغيرة', 'qty': 1},
      ],
      fallbackSetsCount: 1,
    );

    expect(summary.totalPieces, 3);
    final secComp = compsWithSecondary.firstWhere((c) => c['source_category_id'] == 5);
    expect(secComp['source_category_name'], 'صالون لويس');
    expect(secComp['qty'], 2);
  });

  testWidgets('Component card for secondary category pieces renders horizontally with badge and counter', (tester) async {
    final comp = {
      'name': 'كنبة كبيرة',
      'qty': 1,
      'base_qty': 1,
      'selected': true,
      'is_custom': true,
      'source_category_id': 2,
      'source_category_name': 'كنز',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_box_rounded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          children: [
                            Text(comp['name'].toString()),
                            Text('من طقم: ${comp['source_category_name']}'),
                          ],
                        ),
                      ),
                      const Icon(Icons.delete_outline),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text('قطعة فردية تُخصم من مخزون (${comp['source_category_name']}) عند التسليم'),
                      ),
                      Text('${comp['qty']}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('كنبة كبيرة'), findsOneWidget);
    expect(find.text('من طقم: كنز'), findsOneWidget);
    expect(find.text('قطعة فردية تُخصم من مخزون (كنز) عند التسليم'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}

