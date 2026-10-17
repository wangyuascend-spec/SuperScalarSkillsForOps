
/home/wangyu/Code/PtoNpu/validation_logs/rms1024-20261017/rms_norm_1024x8192.elf:	file format elf64-unknown

Disassembly of section .text:

00000000000113bc <_start>:
; _start():
   113bc: 0232                 	C.BSTART.STD	DIRECT, 0x11402 <main>
   113be: 5056                 	c.setret	0x113c0, ->ra <_end>

00000000000113c0 <_end>:
; _end():
   113c0: 0800                 	C.BSTART.STD	
   113c2: 05e00a95             	addi	zero, 94, 	->x1
   113c6: 0010302b             	acrc 1
   113ca: 0000                 	C.BSTOP

00000000000113cc <pto::layout_type_to_str(pto::LayoutEnum)>:
; pto::layout_type_to_str(pto::LayoutEnum)():
   113cc: 00d4                 	C.BSTART.STD	COND, 0x113e6 <.LBB0_2>
; ():
   113ce: fffff187             	addtpc	-1, 	->a1
   113d2: f896                 	c.movi	2, 	->t
   113d4: 002c6065             	setc.ltu	t#1, a0
   113d8: 00a2                 	C.BSTART.STD	DIRECT, 0x113ec <.LBB0_3>
   113da: 00001f87             	addtpc	1, 	->t
   113de: 506c0f95             	addi	t#1, 1286, 	->t
   113e2: 182c3109             	ld	[t#1, a0<<3], 	->a0

00000000000113e6 <.LBB0_2>:
; .LBB0_2():
   113e6: 0800                 	C.BSTART.STD	
   113e8: 1a619115             	subi	a1, 422, 	->a0

00000000000113ec <.LBB0_3>:
; .LBB0_3():
   113ec: 3800                 	C.BSTART.STD	RET
   113ee: 029c                 	c.setc.tgt	ra
   113f0: 0800                 	C.BSTART.STD	

00000000000113f2 <writeBinaryFile(char const*, unsigned char const*, unsigned long)>:
; writeBinaryFile(char const*, unsigned char const*, unsigned long)():
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/test/common/writeBinary.h:12
   113f2: 3800                 	C.BSTART.STD	RET
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/test/common/writeBinary.h:33
   113f4: 1056                 	c.movi	1, 	->a0
; ():
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/test/common/writeBinary.h:33
   113f6: 029c                 	c.setc.tgt	ra
   113f8: 0800                 	C.BSTART.STD	

00000000000113fa <readBinaryFile(char const*, unsigned char*, unsigned long)>:
; readBinaryFile(char const*, unsigned char*, unsigned long)():
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/common/layout.hpp:118
   113fa: 3800                 	C.BSTART.STD	RET
   113fc: 1056                 	c.movi	1, 	->a0
; ():
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/test/common/readBinary.h:35
   113fe: 029c                 	c.setc.tgt	ra
   11400: 0800                 	C.BSTART.STD	

0000000000011402 <main>:
; main():
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/test/solution/normalization/rms_norm/src/rms_norm_dynamic_tree_32k.cpp:60
   11402: 40a50041             	FENTRY	[ra ~ ra], sp!, 256
; ():
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/common/pto_tileop.hpp:19
   11406: 0364                 	C.BSTART.STD	COND, 0x11472 <.LBB3_4>
   11408: 8020013b             	ssrget	2050, 	->a0
   1140c: ff16                 	c.movi	-4, 	->t
   1140e: 6e1c                 	c.zext.w	t#1, ->t
   11410: 01812065             	setc.and	a0, t#1
   11414: 02f4                 	C.BSTART.STD	COND, 0x11472 <.LBB3_4>
   11416: f856                 	c.movi	1, 	->t
   11418: 028c7f95             	slli	t#1, 40, 	->t
   1141c: 100c1f95             	subi	t#1, 256, 	->t
   11420: 402c2105             	and	t#1, a0<<8, 	->a0
   11424: 3ff00f95             	addi	zero, 1023, 	->t
   11428: 002c6065             	setc.ltu	t#1, a0
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:434
   1142c: 0942                 	C.BSTART.STD	DIRECT, 0x11554 <void rms_detail_simt_dynamic_tree_32k::rms_norm_tile_16k<_Float16, pto::global_tensor<_Float16, pto::MatrixLayout<-1, -1, -1, 1, (pto::LayoutEnum)1>>, pto::Tile<(pto::Location)0, _Float16, 32, 128, (pto::BLayout)3, -1, -1, (pto::SLayout)0, 512, (pto::PadValue)3, (pto::CompactMode)0>, pto::Tile<(pto::Location)0, float, 32, 128, (pto::BLayout)3, -1, -1, (pto::SLayout)0, 512, (pto::PadValue)3, (pto::CompactMode)0>, pto::Tile<(pto::Location)0, float, 32, 128, (pto::BLayout)3, -1, 1, (pto::SLayout)0, 512, (pto::PadValue)3, (pto::CompactMode)0>, pto::Tile<(pto::Location)0, float, 32, 1, (pto::BLayout)3, 1, 1, (pto::SLayout)0, 512, (pto::PadValue)3, (pto::CompactMode)0>>(_Float16*, _Float16 const*, _Float16*, long, long, float)>
   1142e: 00022507             	setret	0x11472, ->ra <.LBB3_4>
   11432: 40000f95             	addi	zero, 1024, 	->t
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:435
   11436: 1618                 	c.sub	t#1, a0, ->t
   11438: 100c4fd5             	cmp.lti	t#1, 256, 	->t
   1143c: 10000f95             	addi	zero, 256, 	->t
   11440: c98d0377             	csel	t#2, t#3, t#1, 	->a4
   11444: 00002f87             	addtpc	2, 	->t
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:438
   11448: 4b4c0f95             	addi	t#1, 1204, 	->t
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:440
   1144c: 702c0f05             	add	t#1, a0<<14, 	->u
   11450: 01006f87             	addtpc	4102, 	->t
   11454: 4a8c0f95             	addi	t#1, 1192, 	->t
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:441
   11458: 702c0205             	add	t#1, a0<<14, 	->a2
   1145c: 01002f87             	addtpc	4098, 	->t
   11460: 49cc0195             	addi	t#1, 1180, 	->a1
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:442
   11464: ffffff87             	addtpc	-1, 	->t
   11468: d9cc23a9             	lwi.u	[t#1, -612], 	->a5
   1146c: 1706                 	c.movr	u#1, 	->a0
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:462
   1146e: 00002297             	lui	2, 	->a3

0000000000011472 <.LBB3_4>:
   11472: 0800                 	C.BSTART.STD	
   11474: 1006                 	c.movr	zero, 	->a0
   11476: 40a53041             	FRET.STK	[ra ~ ra], sp!, 256
   1147a: 0800                 	C.BSTART.STD	

000000000001147c <__cxx_global_var_init>:
; __cxx_global_var_init():
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:462
   1147c: 0184                 	C.BSTART.STD	COND, 0x114ac <.LBB4_2>
; ():
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:462
   1147e: 02006f87             	addtpc	8198, 	->t
   11482: 4dac4f99             	lbui	[t#1, 1242], 	->t
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/test/solution/normalization/rms_norm/src/rms_norm_dynamic_tree_32k.cpp:136
   11486: 0636                 	c.setc.ne	t#1, zero
   11488: 0800                 	C.BSTART.STD	
   1148a: 02006f87             	addtpc	8198, 	->t
   1148e: f856                 	c.movi	1, 	->t
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/common/pto_tile.hpp:719
   11490: dd9c7459             	sdi.u	t#1, [t#2, 1134]
   11494: 46ec8f95             	addi	t#2, 1134, 	->t
   11498: 05802059             	swi	zero, [t#1, 8]
   1149c: 07802059             	swi	zero, [t#1, 12]
   114a0: 09802059             	swi	zero, [t#1, 16]
   114a4: 02006f87             	addtpc	8198, 	->t
   114a8: 698d04d9             	sbi	t#3, [t#1, 1204]

00000000000114ac <.LBB4_2>:
; .LBB4_2():
   114ac: 3800                 	C.BSTART.STD	RET
   114ae: 029c                 	c.setc.tgt	ra
   114b0: 0800                 	C.BSTART.STD	

00000000000114b2 <__cxx_global_var_init.4>:
; __cxx_global_var_init.4():
   114b2: 0184                 	C.BSTART.STD	COND, 0x114e2 <.LBB5_2>
; ():
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/common/pto_tile.hpp:904
   114b4: 02006f87             	addtpc	8198, 	->t
   114b8: 4acc4f99             	lbui	[t#1, 1196], 	->t
   114bc: 0636                 	c.setc.ne	t#1, zero
   114be: 0800                 	C.BSTART.STD	
   114c0: 02006f87             	addtpc	8198, 	->t
   114c4: f856                 	c.movi	1, 	->t
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/common/pto_tile.hpp:797
   114c6: a19c7459             	sdi.u	t#1, [t#2, 1104]
   114ca: 450c8f95             	addi	t#2, 1104, 	->t
   114ce: 05802059             	swi	zero, [t#1, 8]
   114d2: 07802059             	swi	zero, [t#1, 12]
   114d6: 09802059             	swi	zero, [t#1, 16]
   114da: 02006f87             	addtpc	8198, 	->t
   114de: 0d8d04d9             	sbi	t#3, [t#1, 1158]

00000000000114e2 <.LBB5_2>:
; .LBB5_2():
   114e2: 3800                 	C.BSTART.STD	RET
   114e4: 029c                 	c.setc.tgt	ra
   114e6: 0800                 	C.BSTART.STD	

00000000000114e8 <__cxx_global_var_init.5>:
; __cxx_global_var_init.5():
   114e8: 0184                 	C.BSTART.STD	COND, 0x11518 <.LBB6_2>
; ():
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/common/pto_tile.hpp:908
   114ea: 02006f87             	addtpc	8198, 	->t
   114ee: 47ec4f99             	lbui	[t#1, 1150], 	->t
   114f2: 0636                 	c.setc.ne	t#1, zero
   114f4: 0800                 	C.BSTART.STD	
   114f6: 02006f87             	addtpc	8198, 	->t
   114fa: f856                 	c.movi	1, 	->t
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/common/pto_tile.hpp:719
   114fc: 659c7459             	sdi.u	t#1, [t#2, 1074]
   11500: 432c8f95             	addi	t#2, 1074, 	->t
   11504: 05802059             	swi	zero, [t#1, 8]
   11508: 07802059             	swi	zero, [t#1, 12]
   1150c: 09802059             	swi	zero, [t#1, 16]
   11510: 02006f87             	addtpc	8198, 	->t
   11514: b18d0459             	sbi	t#3, [t#1, 1112]

0000000000011518 <.LBB6_2>:
; .LBB6_2():
   11518: 3800                 	C.BSTART.STD	RET
   1151a: 029c                 	c.setc.tgt	ra
   1151c: 0800                 	C.BSTART.STD	

000000000001151e <__cxx_global_var_init.6>:
; __cxx_global_var_init.6():
   1151e: 0184                 	C.BSTART.STD	COND, 0x1154e <.LBB7_2>
; ():
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/common/pto_tile.hpp:904
   11520: 02006f87             	addtpc	8198, 	->t
   11524: 450c4f99             	lbui	[t#1, 1104], 	->t
   11528: 0636                 	c.setc.ne	t#1, zero
   1152a: 0800                 	C.BSTART.STD	
   1152c: 02006f87             	addtpc	8198, 	->t
   11530: f856                 	c.movi	1, 	->t
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/common/pto_tile.hpp:797
   11532: 299c7459             	sdi.u	t#1, [t#2, 1044]
   11536: 414c8f95             	addi	t#2, 1044, 	->t
   1153a: 05802059             	swi	zero, [t#1, 8]
   1153e: 07802059             	swi	zero, [t#1, 12]
   11542: 09802059             	swi	zero, [t#1, 16]
   11546: 02006f87             	addtpc	8198, 	->t
   1154a: 558d0459             	sbi	t#3, [t#1, 1066]

000000000001154e <.LBB7_2>:
; .LBB7_2():
   1154e: 3800                 	C.BSTART.STD	RET
   11550: 029c                 	c.setc.tgt	ra
   11552: 0800                 	C.BSTART.STD	

0000000000011554 <void rms_detail_simt_dynamic_tree_32k::rms_norm_tile_16k<_Float16, pto::global_tensor<_Float16, pto::MatrixLayout<-1, -1, -1, 1, (pto::LayoutEnum)1>>, pto::Tile<(pto::Location)0, _Float16, 32, 128, (pto::BLayout)3, -1, -1, (pto::SLayout)0, 512, (pto::PadValue)3, (pto::CompactMode)0>, pto::Tile<(pto::Location)0, float, 32, 128, (pto::BLayout)3, -1, -1, (pto::SLayout)0, 512, (pto::PadValue)3, (pto::CompactMode)0>, pto::Tile<(pto::Location)0, float, 32, 128, (pto::BLayout)3, -1, 1, (pto::SLayout)0, 512, (pto::PadValue)3, (pto::CompactMode)0>, pto::Tile<(pto::Location)0, float, 32, 1, (pto::BLayout)3, 1, 1, (pto::SLayout)0, 512, (pto::PadValue)3, (pto::CompactMode)0>>(_Float16*, _Float16 const*, _Float16*, long, long, float)>:
; void rms_detail_simt_dynamic_tree_32k::rms_norm_tile_16k<_Float16, pto::global_tensor<_Float16, pto::MatrixLayout<-1, -1, -1, 1, (pto::LayoutEnum)1>>, pto::Tile<(pto::Location)0, _Float16, 32, 128, (pto::BLayout)3, -1, -1, (pto::SLayout)0, 512, (pto::PadValue)3, (pto::CompactMode)0>, pto::Tile<(pto::Location)0, float, 32, 128, (pto::BLayout)3, -1, -1, (pto::SLayout)0, 512, (pto::PadValue)3, (pto::CompactMode)0>, pto::Tile<(pto::Location)0, float, 32, 128, (pto::BLayout)3, -1, 1, (pto::SLayout)0, 512, (pto::PadValue)3, (pto::CompactMode)0>, pto::Tile<(pto::Location)0, float, 32, 1, (pto::BLayout)3, 1, 1, (pto::SLayout)0, 512, (pto::PadValue)3, (pto::CompactMode)0>>(_Float16*, _Float16 const*, _Float16*, long, long, float)():
   11554: 40e58041             	FENTRY	[s0 ~ s3], sp!, 256
; ():
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/common/pto_tile.hpp:908
   11558: 0800                 	C.BSTART.STD	
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:214
   1155a: 00002417             	lui	2, 	->a6
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:222
   1155e: 00818a85             	add	a1, a6, 	->x1
   11562: 10000b15             	addi	zero, 256, 	->x2
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:3331
   11566: 20011181 01f01aa3    	TLOAD             <Row=32, ValidCol=128, FP16, ND2M32, Zero>, [base=a1, stride=x2], ->T<8KB>
          483c203c 000bee13
          01618013
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:253
   1157a: 21b19181 18101023    	TCVT              <Col=1, ValidRow=32, ValidCol=128, FP16, FP32>, T#1, ->T<16KB>
          483c203c 000c5e13
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:3331
   1158a: 20011181 01f01aa3    	TLOAD             <Row=32, ValidCol=128, FP16, ND2M32, Zero>, [base=x1, stride=x2], ->U<8KB>
          483c203c 000bee93
          016a8013
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:253
   1159e: 21b19181 18101023    	TCVT              <Col=1, ValidRow=32, ValidCol=128, FP16, FP32>, U#1, ->U<16KB>
          483c203c 010c5e93
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:231
   115ae: 1844                 	C.BSTART.STD	COND, 0x118b6 <.LBB8_61>
   115b0: 00134075             	setc.lti	a4, 1
   115b4: f8211181             	BSTART.TLSU	TMOV, DTYPE_NONE
   115b8: 000c5e13             	B.IOT	t#1, mask=1111, last, 	->t<16KB>
   115bc: f8211181             	BSTART.TLSU	TMOV, DTYPE_NONE
   115c0: 010c5e93             	B.IOT	u#1, mask=1111, last, 	->u<16KB>
   115c4: 0012f195             	slli	a3, 1, 	->a1
   115c8: 00810285             	add	a0, a6, 	->a3
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:231
   115cc: 00820405             	add	a2, a6, 	->a6
   115d0: 4806                 	c.movr	zero, 	->a7

00000000000115d2 <.LBB8_7>:
   115d2: 0800                 	C.BSTART.STD	
   115d4: 00910705             	add	a0, a7, 	->s3
   115d8: 00928685             	add	a3, a7, 	->s2
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:234
   115dc: 00920605             	add	a2, a7, 	->s1
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:235
   115e0: 00940a05             	add	a6, a7, 	->x0
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:236
   115e4: 10000a95             	addi	zero, 256, 	->x1
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:3331
   115e8: 20011181 01f01aa3    	TLOAD             <Row=32, ValidCol=128, FP16, ND2M32, Zero>, [base=s3, stride=x1], ->M<8KB>
          483c203c 000bef13
          01570013
   115fc: 21b19181 18101023    	TCVT              <Col=1, ValidRow=32, ValidCol=128, FP16, FP32>, M#1, ->N<16KB>
          483c203c 020c5f93
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:253
   1160c: 08219181             	BSTART.TEPL	TMUL, FP32
   11610: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:9961
   11614: 203c                 	C.B.DIMI	128, 	->lb0
   11616: 483c                 	C.B.DIMI	32, 	->lb1
   11618: a03c                 	C.B.DIMI	128, 	->lb2
   1161a: c30c4e13             	B.IOT	n#1, n#1, mask=1111, last, 	->t<16KB>
   1161e: 20011181 01f01aa3    	TLOAD             <Row=32, ValidCol=128, FP16, ND2M32, Zero>, [base=s2, stride=x1], ->M<8KB>
          483c203c 000bef13
          01568013
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:3331
   11632: 21b19181 18101023    	TCVT              <Col=1, ValidRow=32, ValidCol=128, FP16, FP32>, M#1, ->M<16KB>
          483c203c 020c5f13
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:253
   11642: 08219181             	BSTART.TEPL	TMUL, FP32
   11646: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:9961
   1164a: 203c                 	C.B.DIMI	128, 	->lb0
   1164c: 483c                 	C.B.DIMI	32, 	->lb1
   1164e: a03c                 	C.B.DIMI	128, 	->lb2
   11650: 820c4e93             	B.IOT	m#1, m#1, mask=1111, last, 	->u<16KB>
   11654: 08019181             	BSTART.TEPL	TADD, FP32
   11658: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:9763
   1165c: 203c                 	C.B.DIMI	128, 	->lb0
   1165e: 483c                 	C.B.DIMI	32, 	->lb1
   11660: a03c                 	C.B.DIMI	128, 	->lb2
   11662: 400c4e13             	B.IOT	t#1, u#1, mask=1111, last, 	->t<16KB>
   11666: 0c019181 19f01ea3    	TROWSUM           <Row=32, Col=128, FP32, CUBE_M32>, T#1, ->T<16KB>
          483c203c 5e13a03c
          000c
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:14872
   11678: 0d019181 19f01ea3    	TCOLSUM           <Row=32, Col=128, ValidCol=1, FP32, CUBE_M32>, T#1, ->T<16KB>
          483c007c 5e13a03c
          000c
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:15423
   1168a: 69c6                 	c.movr	a5, 	->s2
   1168c: 0a219181             	BSTART.TEPL	TMULS, FP32
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:13218
   11690: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:13220
   11694: 007c                 	C.B.DIMI	1, 	->lb0
   11696: 0008de13             	B.IOT	t#1, mask=1111, last, 	->t<128B>
   1169a: 000000d3             	B.SUBVIEW	0, zero, 0, 1
   1169e: 00068013             	B.IOR	[s2], []
   116a2: ffffff87             	addtpc	-1, 	->t
   116a6: b76c26a9             	lwi.u	[t#1, -1162], 	->s2
   116aa: 0a019181             	BSTART.TEPL	TADDS, FP32
   116ae: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:12027
   116b2: 007c                 	C.B.DIMI	1, 	->lb0
   116b4: 0008de13             	B.IOT	t#1, mask=1111, last, 	->t<128B>
   116b8: 00068013             	B.IOR	[s2], []
   116bc: 09419181             	BSTART.TEPL	TRECIP, FP32
   116c0: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:11700
   116c4: 007c                 	C.B.DIMI	1, 	->lb0
   116c6: 0008de93             	B.IOT	t#1, mask=1111, last, 	->u<128B>
   116ca: 09519181             	BSTART.TEPL	TSQRT, FP32
   116ce: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:11773
   116d2: 007c                 	C.B.DIMI	1, 	->lb0
   116d4: 0108df13             	B.IOT	u#1, mask=1111, last, 	->m<128B>
   116d8: ffffff87             	addtpc	-1, 	->t
   116dc: b38c26a9             	lwi.u	[t#1, -1224], 	->s2
   116e0: 0a219181             	BSTART.TEPL	TMULS, FP32
   116e4: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:12212
   116e8: 007c                 	C.B.DIMI	1, 	->lb0
   116ea: 0008df93             	B.IOT	t#1, mask=1111, last, 	->n<128B>
   116ee: 00068013             	B.IOR	[s2], []
   116f2: 08219181             	BSTART.TEPL	TMUL, FP32
   116f6: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:9903
   116fa: 007c                 	C.B.DIMI	1, 	->lb0
   116fc: 8308cf93             	B.IOT	n#1, m#1, mask=1111, last, 	->n<128B>
   11700: 08219181             	BSTART.TEPL	TMUL, FP32
   11704: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
   11708: 007c                 	C.B.DIMI	1, 	->lb0
   1170a: 8308cf93             	B.IOT	n#1, m#1, mask=1111, last, 	->n<128B>
   1170e: ffffff87             	addtpc	-1, 	->t
   11712: afec26a9             	lwi.u	[t#1, -1282], 	->s2
   11716: 0a019181             	BSTART.TEPL	TADDS, FP32
   1171a: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:12027
   1171e: 007c                 	C.B.DIMI	1, 	->lb0
   11720: 0308df93             	B.IOT	n#1, mask=1111, last, 	->n<128B>
   11724: 00068013             	B.IOR	[s2], []
   11728: 08219181             	BSTART.TEPL	TMUL, FP32
   1172c: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:9903
   11730: 007c                 	C.B.DIMI	1, 	->lb0
   11732: c208cf13             	B.IOT	m#1, n#1, mask=1111, last, 	->m<128B>
   11736: ffffff87             	addtpc	-1, 	->t
   1173a: ad2c26a9             	lwi.u	[t#1, -1326], 	->s2
   1173e: 0a219181             	BSTART.TEPL	TMULS, FP32
   11742: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:12212
   11746: 007c                 	C.B.DIMI	1, 	->lb0
   11748: 0008df93             	B.IOT	t#1, mask=1111, last, 	->n<128B>
   1174c: 00068013             	B.IOR	[s2], []
   11750: 08219181             	BSTART.TEPL	TMUL, FP32
   11754: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:9903
   11758: 007c                 	C.B.DIMI	1, 	->lb0
   1175a: 4308cf93             	B.IOT	n#1, u#1, mask=1111, last, 	->n<128B>
   1175e: ffffff87             	addtpc	-1, 	->t
   11762: aa6c2729             	lwi.u	[t#1, -1370], 	->s3
   11766: 0a019181             	BSTART.TEPL	TADDS, FP32
   1176a: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:12027
   1176e: 007c                 	C.B.DIMI	1, 	->lb0
   11770: 0308df93             	B.IOT	n#1, mask=1111, last, 	->n<128B>
   11774: 00070013             	B.IOR	[s3], []
   11778: 0a219181             	BSTART.TEPL	TMULS, FP32
   1177c: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:12212
   11780: 007c                 	C.B.DIMI	1, 	->lb0
   11782: 0208de13             	B.IOT	m#1, mask=1111, last, 	->t<128B>
   11786: 00068013             	B.IOR	[s2], []
   1178a: 08219181             	BSTART.TEPL	TMUL, FP32
   1178e: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:9903
   11792: 007c                 	C.B.DIMI	1, 	->lb0
   11794: 8008ce13             	B.IOT	t#1, m#1, mask=1111, last, 	->t<128B>
   11798: 08019181             	BSTART.TEPL	TADD, FP32
   1179c: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:9709
   117a0: 007c                 	C.B.DIMI	1, 	->lb0
   117a2: 0108ce93             	B.IOT	u#1, t#1, mask=1111, last, 	->u<128B>
   117a6: 08219181             	BSTART.TEPL	TMUL, FP32
   117aa: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:9903
   117ae: 007c                 	C.B.DIMI	1, 	->lb0
   117b0: 4028ce13             	B.IOT	t#3, u#1, mask=1111, last, 	->t<128B>
   117b4: 08019181             	BSTART.TEPL	TADD, FP32
   117b8: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:9709
   117bc: 007c                 	C.B.DIMI	1, 	->lb0
   117be: 0308ce13             	B.IOT	n#1, t#1, mask=1111, last, 	->t<128B>
   117c2: 08219181             	BSTART.TEPL	TMUL, FP32
   117c6: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:9903
   117ca: 007c                 	C.B.DIMI	1, 	->lb0
   117cc: 8008ce13             	B.IOT	t#1, m#1, mask=1111, last, 	->t<128B>
   117d0: ffffff87             	addtpc	-1, 	->t
   117d4: a44c26a9             	lwi.u	[t#1, -1468], 	->s2
   117d8: 0a219181             	BSTART.TEPL	TMULS, FP32
   117dc: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:12212
   117e0: 007c                 	C.B.DIMI	1, 	->lb0
   117e2: 0008de13             	B.IOT	t#1, mask=1111, last, 	->t<128B>
   117e6: 00068013             	B.IOR	[s2], []
   117ea: 08019181             	BSTART.TEPL	TADD, FP32
   117ee: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:9709
   117f2: 007c                 	C.B.DIMI	1, 	->lb0
   117f4: 0208ce13             	B.IOT	m#1, t#1, mask=1111, last, 	->t<128B>
   117f8: 0d419181 19f01ea3    	TCOLEXPAND        <Row=32, Col=128, ValidCol=1, FP32, CUBE_M32>, T#1, ->T<16KB>
          483c007c 5e13a03c
          000c
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:15769
   1180a: 0c719181 19f01ea3    	TROWEXPANDMUL     <Row=32, Col=128, FP32, CUBE_M32>, N#8, T#1, ->N<16KB>
          483c203c 4f93a03c
          037c
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:16327
   1181c: 08219181             	BSTART.TEPL	TMUL, FP32
   11820: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:9961
   11824: 203c                 	C.B.DIMI	128, 	->lb0
   11826: 483c                 	C.B.DIMI	32, 	->lb1
   11828: a03c                 	C.B.DIMI	128, 	->lb2
   1182a: 3b0c4f93             	B.IOT	n#1, t#15, mask=1111, last, 	->n<16KB>
   1182e: 09b19181 18401023    	TCVT              <Col=1, ValidRow=32, ValidCol=128, FP32, FP16>, N#1, ->N<8KB>
          483c203c 030bdf93
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:253
   1183e: 20111181 19f01c23    	TSTORE            <Row=32, ValidCol=128, FP16, M322ND>, N#1, [base=s1, stride=x1]
          483c203c 03085e13
          01560013
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:3550
   11852: 0c719181 19f01ea3    	TROWEXPANDMUL     <Row=32, Col=128, FP32, CUBE_M32>, M#3, T#1, ->M<16KB>
          483c203c 4f13a03c
          022c
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:16327
   11864: 08219181             	BSTART.TEPL	TMUL, FP32
   11868: 19f01ea3             	B.DATR	CUBE_M32.normal, Null
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:9961
   1186c: 203c                 	C.B.DIMI	128, 	->lb0
   1186e: 483c                 	C.B.DIMI	32, 	->lb1
   11870: a03c                 	C.B.DIMI	128, 	->lb2
   11872: 4e0c4f13             	B.IOT	m#1, u#4, mask=1111, last, 	->m<16KB>
   11876: 09b19181 18401023    	TCVT              <Col=1, ValidRow=32, ValidCol=128, FP32, FP16>, M#1, ->M<8KB>
          483c203c 020bdf13
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:253
   11886: 20111181 19f01c23    	TSTORE            <Row=32, ValidCol=128, FP16, M322ND>, M#1, [base=x0, stride=x1]
          483c203c 02085e13
          015a0013
; /home/wangyu/Code/PtoNpu/linx-toolchain-build-mainline/output/linx_blockisa_llvm_musl/lib/clang/15.0.4/include/tileop-api/jcore/template_asm.hpp:3550
   1189a: f8211181             	BSTART.TLSU	TMOV, DTYPE_NONE
   1189e: 00ec5e13             	B.IOT	t#15, mask=1111, last, 	->t<16KB>
   118a2: f8211181             	BSTART.TLSU	TMOV, DTYPE_NONE
   118a6: 013c5e93             	B.IOT	u#4, mask=1111, last, 	->u<16KB>
   118aa: e944                 	C.BSTART.STD	COND, 0x115d2 <.LBB8_7>
   118ac: 00131315             	subi	a4, 1, 	->a4
; /home/wangyu/Code/PtoNpu/SuperNPUBench-main/benchmark/one-level-arch/kernels/solution/normalization/rms_norm/rms_norm_dynamic_tree_32k.hpp:231
   118b0: 01b6                 	c.setc.ne	a4, zero
   118b2: 00348485             	add	a7, a1, 	->a7

00000000000118b6 <.LBB8_61>:
   118b6: 40e5a041             	FRET.RA	[s0 ~ s3], sp!, 256
   118ba: 0800                 	C.BSTART.STD	
