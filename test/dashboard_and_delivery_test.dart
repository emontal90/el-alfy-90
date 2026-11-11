import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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

    test('extractOrderPieces uses explicit order pieces or falls back to category base_qty * setsCount', () {
      final explicit = OrderDeliveryHelper.extractOrderPieces(
        [
          {'name': 'فوتيه', 'qty': 2},
        ],
        categoryComps,
        setsCount: 2,
      );
      expect(explicit, [
        {'name': 'فوتيه', 'qty': 2},
      ]);

      final fallback = OrderDeliveryHelper.extractOrderPieces(
        const [],
        categoryComps,
        setsCount: 2,
      );
      expect(fallback, [
        {'name': 'كنبة كبيرة', 'qty': 2},
        {'name': 'كنبة صغيرة', 'qty': 2},
        {'name': 'فوتيه', 'qty': 4},
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
        {'name': 'كنبة كبيرة', 'qty': 1},
        {'name': 'كنبة صغيرة', 'qty': 1},
        {'name': 'فوتيه', 'qty': 2},
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
        {'name': 'كنبة كبيرة', 'qty': 1},
        {'name': 'فوتيه', 'qty': 1},
      ]);
      expect(result.remainingComps, [
        {'name': 'كنبة صغيرة', 'qty': 1},
        {'name': 'فوتيه', 'qty': 1},
      ]);
      expect(result.remainingOrderSets, 0);
      expect(result.newCategorySets, 1);
      expect(result.updatedCategoryComps, [
        {'name': 'كنبة كبيرة', 'base_qty': 1, 'qty': 1},
        {'name': 'كنبة صغيرة', 'base_qty': 1, 'qty': 2},
        {'name': 'فوتيه', 'base_qty': 2, 'qty': 3},
      ]);
    });
  });
}

