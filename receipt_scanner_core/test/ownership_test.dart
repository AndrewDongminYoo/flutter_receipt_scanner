// Copyright (c) 2026 Dongmin, Yu. MIT License; see LICENSE.
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:receipt_scanner_core/src/overlap.dart';
import 'package:receipt_scanner_core/src/third_party/receipt_core.g.dart' as native;
import 'package:test/test.dart';

class CountingAllocator implements Allocator {
  final live = <int>{};
  int calls = 0;
  int? failAt;
  @override
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment}) {
    if (++calls == failAt) throw StateError('injected allocation failure');
    final pointer = calloc.allocate<T>(byteCount, alignment: alignment);
    live.add(pointer.address);
    return pointer;
  }

  @override
  void free(Pointer<NativeType> pointer) {
    expect(live.remove(pointer.address), isTrue);
    calloc.free(pointer);
  }
}

void main() {
  test('rejects oversized UTF-16 buffers before allocating', () {
    final allocator = CountingAllocator();
    expect(
      () => findOverlap(
        List.filled(65536, 'x' * 65536),
        [],
        allocator: allocator,
      ),
      throwsRangeError,
    );
    expect(allocator.calls, 0);
  });
  test('buffers released on success and every partial allocation failure', () {
    const lines = ['coffee 1000', 'bread 2000'];
    final allocator = CountingAllocator();
    expect(findOverlap(lines, lines, allocator: allocator), 2);
    expect(allocator.live, isEmpty);
    expect(allocator.calls, 5);
    for (var failure = 1; failure <= 5; failure++) {
      final failing = CountingAllocator()..failAt = failure;
      expect(
        () => findOverlap(lines, lines, allocator: failing),
        throwsStateError,
      );
      expect(failing.live, isEmpty);
    }
  });
  test('generated ABI validates layout, null and malformed descriptors', () {
    expect(native.receipt_core_abi_version(), 1);
    expect(sizeOf<native.receipt_core_line_v1>(), 8);
    using((arena) {
      final output = arena<Uint32>()..value = 42;
      final descriptor = arena<native.receipt_core_line_v1>();
      final data = arena<Uint16>();
      int call({int length = 1, int count = 1, bool nullOutput = false}) => native.receipt_core_find_overlap_v1(
        data,
        length,
        descriptor,
        count,
        nullptr,
        0,
        nullptr,
        0,
        nullOutput ? nullptr : output,
      );
      descriptor.ref.offset = 2;
      descriptor.ref.length = 0;
      expect(call(), 1);
      expect(output.value, 0);
      descriptor.ref.offset = 0;
      descriptor.ref.length = 0xffffffff;
      expect(call(), 1);
      expect(output.value, 0);
      expect(call(nullOutput: true), 1);
      expect(call(count: 0), 0);
      expect(
        native.receipt_core_find_overlap_v1(
          nullptr,
          1,
          nullptr,
          0,
          nullptr,
          0,
          nullptr,
          0,
          output,
        ),
        1,
      );
    });
  });
}
