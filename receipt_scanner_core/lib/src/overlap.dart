// Copyright (c) 2026 Dongmin, Yu. MIT License; see LICENSE.
import 'dart:ffi';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';

import 'package:receipt_scanner_core/src/third_party/receipt_core.g.dart' as native;

/// Calls ABI v1 with allocator-owned temporary buffers.
///
/// Internal allocator injection verifies ownership without exposing pointers.
int findOverlap(
  List<String> left,
  List<String> right, {
  Allocator allocator = calloc,
}) {
  if (native.receipt_core_abi_version() != 1) {
    throw UnsupportedError('Unsupported receipt core ABI');
  }
  final leftSize = _size(left);
  final rightSize = _size(right);
  final arena = Arena(allocator);
  try {
    final l = _page(left, leftSize, arena);
    final r = _page(right, rightSize, arena);
    final output = arena<Uint32>();
    final status = native.receipt_core_find_overlap_v1(
      l.$1,
      leftSize,
      l.$2,
      left.length,
      r.$1,
      rightSize,
      r.$2,
      right.length,
      output,
    );
    if (status != 0) throw StateError('Receipt core rejected input: $status');
    final count = output.value;
    if (count > math.min(left.length, right.length)) {
      throw StateError('Invalid native overlap count');
    }
    return count;
  } finally {
    arena.releaseAll();
  }
}

int _size(List<String> lines) {
  _uint32(lines.length);
  var size = 0;
  for (final line in lines) {
    size += line.length;
    _uint32(size);
  }
  return size;
}

void _uint32(int value) {
  if (value < 0 || value > 0xffffffff) {
    throw RangeError('Input exceeds ABI uint32 range');
  }
}

(Pointer<Uint16>, Pointer<native.receipt_core_line_v1>) _page(
  List<String> lines,
  int size,
  Arena arena,
) {
  final data = size == 0 ? nullptr.cast<Uint16>() : arena<Uint16>(size);
  final descriptors = lines.isEmpty
      ? nullptr.cast<native.receipt_core_line_v1>()
      : arena<native.receipt_core_line_v1>(lines.length);
  var offset = 0;
  for (var i = 0; i < lines.length; i++) {
    final units = lines[i].codeUnits;
    descriptors[i].offset = offset;
    descriptors[i].length = units.length;
    for (final unit in units) {
      data[offset++] = unit;
    }
  }
  return (data, descriptors);
}
