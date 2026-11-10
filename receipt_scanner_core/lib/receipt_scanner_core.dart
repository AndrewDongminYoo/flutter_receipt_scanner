// Copyright (c) 2026 Dongmin, Yu. MIT License; see LICENSE.
/// Explicit pilot accepting caller-normalized UTF-16 lines.
library;

import 'package:receipt_scanner_core/src/overlap.dart';

/// Computes a deepest suffix/prefix overlap without normalization or retention.
int findReceiptOverlap(List<String> left, List<String> right) => findOverlap(left, right);
