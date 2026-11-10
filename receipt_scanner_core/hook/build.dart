// Copyright (c) 2026 Dongmin, Yu. MIT License; see LICENSE.
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    await CBuilder.library(
      name: 'receipt_core',
      assetName: 'src/third_party/receipt_core.g.dart',
      sources: ['third_party/receipt_core/receipt_core.cpp'],
      language: Language.cpp,
      std: 'c++17',
      cppLinkStdLib: input.config.code.targetOS == OS.android ? 'c++_static' : null,
      flags: [
        '-fno-exceptions',
        '-fno-rtti',
        '-fvisibility=hidden',
        if (input.config.code.targetOS == OS.android) '-Wl,-z,max-page-size=16384',
      ],
      defines: {'RECEIPT_CORE_SHARED': null, 'RECEIPT_CORE_BUILD': null},
    ).run(input: input, output: output);
  });
}
