import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/lat_lng.dart';
import '/flutter_flow/place.dart';
import '/flutter_flow/uploaded_file.dart';
import '/backend/backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/backend/schema/structs/index.dart';
import '/auth/firebase_auth/auth_util.dart';

List<dynamic>? filteringJson(
  List<dynamic>? data,
  String? query,
  String? field,
  String? sortedField,
  bool? isAsc,
) {
  /// MODIFY CODE ONLY BELOW THIS LINE
//if (data != null || data.isNotEmpty || query != null || query.isNotEmpty) {
  //return data;
  //}

  try {
    // SORTING

    dynamic getNestedValue(Map obj, String field) {
      final parts =
          RegExp(r'\w+').allMatches(field).map((m) => m.group(0)).toList();
      dynamic value = obj;
      for (final part in parts) {
        if (value is Map && value.containsKey(part)) {
          value = value[part];
        } else {
          return null;
        }
      }
      return value;
    }

    // print('query $query');
    // print('field $field');

    if (data != null &&
        data.isNotEmpty &&
        sortedField != null &&
        sortedField.isNotEmpty &&
        isAsc != null) {
      data.sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        if (a is! Map || b is! Map) return 0;

        final aValue = getNestedValue(a, sortedField);
        final bValue = getNestedValue(b, sortedField);

        if (aValue == null) return 1;
        if (bValue == null) return -1;

        if (sortedField == 'order' || sortedField == 'order_num') {
          // Convert string numbers to integers for proper numeric sorting
          final aNum = int.tryParse(aValue) ?? 0;
          final bNum = int.tryParse(bValue) ?? 0;
          return aNum.compareTo(bNum);
        }

        if (aValue is List && bValue is List) {
          if (aValue.isEmpty) return 1;
          if (bValue.isEmpty) return -1;
          final minLength = math.min(aValue.length, bValue.length);
          for (var i = 0; i < minLength; i++) {
            if (aValue[i] == null && bValue[i] == null) continue;
            if (aValue[i] == null) return 1;
            if (bValue[i] == null) return -1;
            final comparison =
                aValue[i].toString().compareTo(bValue[i].toString());
            if (comparison != 0) return comparison;
          }
          return aValue.length.compareTo(bValue.length);
        }

        if (aValue is num && bValue is num) {
          return aValue.compareTo(bValue);
        }
        if (aValue is String && bValue is String) {
          return aValue.compareTo(bValue);
        }
        return 0;
      });
      if (!isAsc) {
        data = data.reversed.toList();
      }
    }

    // FILTERING
    if (data != null && data.isNotEmpty && query != null && query.isNotEmpty) {
      DateTime? queryDate;
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(query)) {
        queryDate = DateTime.tryParse(query);
      }

      final filtered = data.where((item) {
        if (item is! Map) return false;
        final fieldValue = field != null && field.isNotEmpty
            ? getNestedValue(item, field)
            : null;

        if ((field ?? '').toLowerCase() == 'user_status') {
          final dynamic arch = getNestedValue(item, 'archivized_by');
          final String archStr =
              (arch is String ? arch : (arch?.toString() ?? '')).trim();
          final bool isEmpty = arch == null || archStr.isEmpty;
          final q = (query ?? '').toLowerCase();

          if (q == 'active') return isEmpty; // archivized_by missing or empty
          if (q == 'archived')
            return !isEmpty; // archivized_by present and non-empty
          // fall through to default logic for other queries
        }

        if ((field ?? '').toLowerCase() == 'points_type_id') {
          final dynamic arch = getNestedValue(item, 'points_type_id');
          final String archStr =
              (arch is String ? arch : (arch?.toString() ?? '')).trim();
          final bool isEmpty = arch == null || archStr.isEmpty;
          final q = (query ?? '').toLowerCase();

          if (q == 'active') return isEmpty; // archivized_by missing or empty
          if (q == 'archived')
            return !isEmpty; // archivized_by present and non-empty
          // fall through to default logic for other queries
        }

        if (fieldValue is List) {
          return fieldValue.any((element) =>
              element.toString().toLowerCase().contains(query.toLowerCase()));
        }

        if (fieldValue is int && queryDate != null) {
          final itemDate = DateTime.fromMillisecondsSinceEpoch(fieldValue);
          return itemDate.year == queryDate.year &&
              itemDate.month == queryDate.month &&
              itemDate.day == queryDate.day;
        }

        return fieldValue
                ?.toString()
                .toLowerCase()
                .contains(query.toLowerCase()) ??
            false;
      }).toList();

      return filtered;
    }

    return data;
  } catch (e) {
    print('Error filtering data: $e');
    return [];
  }

  /// MODIFY CODE ONLY ABOVE THIS LINE
}
