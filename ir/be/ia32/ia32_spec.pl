# Creation: 2005/10/19
# $Id$
# This is the specification for the ia32 assembler Firm-operations

# the cpu architecture (ia32, ia64, mips, sparc, ppc, ...)
$arch = "ia32";

# this strings mark the beginning and the end of a comment in emit
$comment_string     = "/*";
$comment_string_end = "*/";

# the number of additional opcodes you want to register
#$additional_opcodes = 0;

# The node description is done as a perl hash initializer with the
# following structure:
#
# %nodes = (
#
# <op-name> => {
#   "op_flags"  => "N|L|C|X|I|F|Y|H|c|K",
#   "irn_flags" => "R|N|I|S"
#   "arity"     => "0|1|2|3 ... |variable|dynamic|any",
#   "state"     => "floats|pinned|mem_pinned|exc_pinned",
#   "args"      => [
#                    { "type" => "type 1", "name" => "name 1" },
#                    { "type" => "type 2", "name" => "name 2" },
#                    ...
#                  ],
#   "comment"   => "any comment for constructor",
#   "reg_req"   => { "in" => [ "reg_class|register" ], "out" => [ "reg_class|register|in_rX" ] },
#   "cmp_attr"  => "c source code for comparing node attributes",
#   "emit"      => "emit code with templates",
#   "attr"      => "attitional attribute arguments for constructor"
#   "init_attr" => "emit attribute initialization template"
#   "rd_constructor" => "c source code which constructs an ir_node"
#   "latency"   => "latency of this operation (can be float)"
# },
#
# ... # (all nodes you need to describe)
#
# ); # close the %nodes initializer

# op_flags: flags for the operation, OPTIONAL (default is "N")
# the op_flags correspond to the firm irop_flags:
#   N   irop_flag_none
#   L   irop_flag_labeled
#   C   irop_flag_commutative
#   X   irop_flag_cfopcode
#   I   irop_flag_ip_cfopcode
#   F   irop_flag_fragile
#   Y   irop_flag_forking
#   H   irop_flag_highlevel
#   c   irop_flag_constlike
#   K   irop_flag_keep
#
# irn_flags: special node flags, OPTIONAL (default is 0)
# following irn_flags are supported:
#   R   rematerializeable
#   N   not spillable
#   I   ignore for register allocation
#   S   modifies stack pointer
#
# state: state of the operation, OPTIONAL (default is "floats")
#
# arity: arity of the operation, MUST NOT BE OMITTED
#
# args:  the OPTIONAL arguments of the node constructor (debug, irg and block
#        are always the first 3 arguments and are always autmatically
#        created)
#        If this key is missing the following arguments will be created:
#        for i = 1 .. arity: ir_node *op_i
#        ir_mode *mode
#
# outs:  if a node defines more than one output, the names of the projections
#        nodes having outs having automatically the mode mode_T
#        One can also annotate some flags for each out, additional to irn_flags.
#        They are separated from name with a colon ':', and concatenated by pipe '|'
#        Only I and S are available at the moment (same meaning as in irn_flags).
#        example: [ "frame:I", "stack:I|S", "M" ]
#
# comment: OPTIONAL comment for the node constructor
#
# rd_constructor: for every operation there will be a
#      new_rd_<arch>_<op-name> function with the arguments from above
#      which creates the ir_node corresponding to the defined operation
#      you can either put the complete source code of this function here
#
#      This key is OPTIONAL. If omitted, the following constructor will
#      be created:
#      if (!op_<arch>_<op-name>) assert(0);
#      for i = 1 to arity
#         set in[i] = op_i
#      done
#      res = new_ir_node(db, irg, block, op_<arch>_<op-name>, mode, arity, in)
#      return res
#
# NOTE: rd_constructor and args are only optional if and only if arity is 0,1,2 or 3
#
# latency: the latency of the operation, default is 1
#

# register types:
#   0 - no special type
#   1 - caller save (register must be saved by the caller of a function)
#   2 - callee save (register must be saved by the called function)
#   4 - ignore (do not assign this register)
#   8 - emitter can choose an arbitrary register of this class
#  16 - the register is a virtual one
# NOTE: Last entry of each class is the largest Firm-Mode a register can hold
%reg_classes = (
  "gp" => [
            { "name" => "eax", "type" => 1 },
            { "name" => "edx", "type" => 1 },
            { "name" => "ebx", "type" => 2 },
            { "name" => "ecx", "type" => 1 },
            { "name" => "esi", "type" => 2 },
            { "name" => "edi", "type" => 2 },
#            { "name" => "r11", "type" => 1 },
#            { "name" => "r12", "type" => 1 },
#            { "name" => "r13", "type" => 1 },
#            { "name" => "r14", "type" => 1 },
#            { "name" => "r15", "type" => 1 },
#            { "name" => "r16", "type" => 1 },
#            { "name" => "r17", "type" => 1 },
#            { "name" => "r18", "type" => 1 },
#            { "name" => "r19", "type" => 1 },
#            { "name" => "r20", "type" => 1 },
#            { "name" => "r21", "type" => 1 },
#            { "name" => "r22", "type" => 1 },
#            { "name" => "r23", "type" => 1 },
#            { "name" => "r24", "type" => 1 },
#            { "name" => "r25", "type" => 1 },
#            { "name" => "r26", "type" => 1 },
#            { "name" => "r27", "type" => 1 },
#            { "name" => "r28", "type" => 1 },
#            { "name" => "r29", "type" => 1 },
#            { "name" => "r30", "type" => 1 },
#            { "name" => "r31", "type" => 1 },
#            { "name" => "r32", "type" => 1 },
            { "name" => "ebp", "type" => 2 },
            { "name" => "esp", "type" => 4 },
            { "name" => "gp_NOREG", "type" => 2 | 4 | 16 },     # we need a dummy register for NoReg nodes
            { "name" => "gp_UKNWN", "type" => 2 | 4 | 8 | 16},  # we need a dummy register for Unknown nodes
			{ "mode" => "mode_P" }
          ],
  "xmm" => [
            { "name" => "xmm0", "type" => 1 },
            { "name" => "xmm1", "type" => 1 },
            { "name" => "xmm2", "type" => 1 },
            { "name" => "xmm3", "type" => 1 },
            { "name" => "xmm4", "type" => 1 },
            { "name" => "xmm5", "type" => 1 },
            { "name" => "xmm6", "type" => 1 },
            { "name" => "xmm7", "type" => 1 },
            { "name" => "xmm_NOREG", "type" => 2 | 4 | 16 },     # we need a dummy register for NoReg nodes
            { "name" => "xmm_UKNWN", "type" => 2 | 4 | 8 | 16},  # we need a dummy register for Unknown nodes
			{ "mode" => "mode_D" }
          ],
  "vfp" => [
            { "name" => "vf0", "type" => 1 | 16 },
            { "name" => "vf1", "type" => 1 | 16 },
            { "name" => "vf2", "type" => 1 | 16 },
            { "name" => "vf3", "type" => 1 | 16 },
            { "name" => "vf4", "type" => 1 | 16 },
            { "name" => "vf5", "type" => 1 | 16 },
            { "name" => "vf6", "type" => 1 | 16 },
            { "name" => "vf7", "type" => 1 | 16 },
            { "name" => "vfp_NOREG", "type" => 2 | 4 | 16 },     # we need a dummy register for NoReg nodes
            { "name" => "vfp_UKNWN", "type" => 2 | 4 | 8 | 16},  # we need a dummy register for Unknown nodes
			{ "mode" => "mode_E" }
          ],
  "st" => [
            { "name" => "st0", "type" => 1 },
            { "name" => "st1", "type" => 1 },
            { "name" => "st2", "type" => 1 },
            { "name" => "st3", "type" => 1 },
            { "name" => "st4", "type" => 1 },
            { "name" => "st5", "type" => 1 },
            { "name" => "st6", "type" => 1 },
            { "name" => "st7", "type" => 1 },
			{ "mode" => "mode_E" }
          ]
); # %reg_classes

%cpu = (
  "ALU"    => [ 1, "ALU1", "ALU2", "ALU3", "ALU4" ],
  "MUL"    => [ 1, "MUL1", "MUL2" ],
  "SSE"    => [ 1, "SSE1", "SSE2" ],
  "FPU"    => [ 1, "FPU1" ],
  "MEM"    => [ 1, "MEM1", "MEM2" ],
  "BRANCH" => [ 1, "BRANCH1", "BRANCH2" ],
  "DUMMY"  => [ 1, "DUMMY1", "DUMMY2", "DUMMY3", "DUMMY4" ]
); # %cpu

%vliw = (
	"bundle_size"       => 3,
	"bundels_per_cycle" => 2
); # vliw

#--------------------------------------------------#
#                        _                         #
#                       (_)                        #
#  _ __   _____      __  _ _ __    ___  _ __  ___  #
# | '_ \ / _ \ \ /\ / / | | '__|  / _ \| '_ \/ __| #
# | | | |  __/\ V  V /  | | |    | (_) | |_) \__ \ #
# |_| |_|\___| \_/\_/   |_|_|     \___/| .__/|___/ #
#                                      | |         #
#                                      |_|         #
#--------------------------------------------------#

$default_cmp_attr = "return ia32_compare_immop_attr(attr_a, attr_b);";

%operands = (
);

%nodes = (

#-----------------------------------------------------------------#
#  _       _                                         _            #
# (_)     | |                                       | |           #
#  _ _ __ | |_ ___  __ _  ___ _ __   _ __   ___   __| | ___  ___  #
# | | '_ \| __/ _ \/ _` |/ _ \ '__| | '_ \ / _ \ / _` |/ _ \/ __| #
# | | | | | ||  __/ (_| |  __/ |    | | | | (_) | (_| |  __/\__ \ #
# |_|_| |_|\__\___|\__, |\___|_|    |_| |_|\___/ \__,_|\___||___/ #
#                   __/ |                                         #
#                  |___/                                          #
#-----------------------------------------------------------------#

# commutative operations

# NOTE:
# All nodes supporting Addressmode have 5 INs:
# 1 - base    r1 == NoReg in case of no AM or no base
# 2 - index   r2 == NoReg in case of no AM or no index
# 3 - op1     r3 == always present
# 4 - op2     r4 == NoReg in case of immediate operation
# 5 - mem     NoMem in case of no AM otherwise it takes the mem from the Load

"Add" => {
  "irn_flags" => "R",
  "comment"   => "construct Add: Add(a, b) = Add(b, a) = a + b",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. add %ia32_emit_binop /* Add(%A3, %A4) -> %D1 */',
  "units"     => [ "ALU", "MEM" ],
},

"AddC" => {
  "comment"   => "construct Add with Carry: AddC(a, b) = Add(b, a) = a + b + carry",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. adc %ia32_emit_binop /* AddC(%A3, %A4) -> %D1 */',
  "units"     => [ "ALU", "MEM" ],
},

"Add64Bit" => {
  "irn_flags" => "R",
  "comment"   => "construct 64Bit Add: Add(a_l, a_h, b_l, b_h) = a_l + b_l; a_h + b_h + carry",
  "arity"     => 4,
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp" ], "out" => [ "!in", "!in" ] },
  "emit"      => '
. mov %D1, %S1 /* mov a_l into assigned l_res register */
. mov %D2, %S2 /* mov a_h into assigned h_res register */
. add %D1, %S3 /* a_l + b_l */
. adc %D2, %S4 /* a_h + b_h + carry */
',
  "outs"      => [ "low_res", "high_res" ],
  "units"     => [ "ALU", "MEM" ],
},

"l_Add" => {
  "op_flags"  => "C",
  "irn_flags" => "R",
  "cmp_attr"  => "return 1;",
  "comment"   => "construct lowered Add: Add(a, b) = Add(b, a) = a + b",
  "arity"     => 2,
},

"l_AddC" => {
  "op_flags"  => "C",
  "cmp_attr"  => "return 1;",
  "comment"   => "construct lowered Add with Carry: AddC(a, b) = Add(b, a) = a + b + carry",
  "arity"     => 2,
},

"MulS" => {
  # we should not rematrialize this node. It produces 2 results and has
  # very strict constrains
  "comment"   => "construct MulS: MulS(a, b) = MulS(b, a) = a * b",
  "reg_req"   => { "in" => [ "gp", "gp", "eax", "gp", "none" ], "out" => [ "eax", "edx" ] },
  "emit"      => '. mul %ia32_emit_unop /* Mul(%A1, %A2) -> %D1 */',
  "outs"      => [ "EAX", "EDX", "M" ],
  "latency"   => 10,
  "units"     => [ "MUL" ],
},

"l_MulS" => {
  # we should not rematrialize this node. It produces 2 results and has
  # very strict constrains
  "op_flags"  => "C",
  "cmp_attr"  => "return 1;",
  "comment"   => "construct lowered MulS: MulS(a, b) = MulS(b, a) = a * b",
  "outs"      => [ "EAX", "EDX", "M" ],
  "arity"     => 2
},

"Mul" => {
  "irn_flags" => "R",
  "comment"   => "construct Mul: Mul(a, b) = Mul(b, a) = a * b",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. imul %ia32_emit_binop /* Mul(%A1, %A2) -> %D1 */',
  "latency"   => 5,
  "units"     => [ "MUL" ],
},

"l_Mul" => {
  "op_flags"  => "C",
  "cmp_attr"  => "return 1;",
  "comment"   => "construct lowered Mul: Mul(a, b) = Mul(b, a) = a * b",
  "arity"     => 2
},

# Mulh is an exception from the 4 INs with AM because the target is always EAX:EDX
"Mulh" => {
  # we should not rematrialize this node. It produces 2 results and has
  # very strict constrains
  "comment"   => "construct Mul: Mul(a, b) = Mul(b, a) = a * b",
  "reg_req"   => { "in" => [ "gp", "gp", "eax", "gp", "none" ], "out" => [ "eax", "edx" ] },
  "emit"      => '. imul %ia32_emit_unop /* Mulh(%A1, %A2) -> %D1 */',
  "outs"      => [ "EAX", "EDX", "M" ],
  "latency"   => 5,
  "units"     => [ "MUL" ],
},

"And" => {
  "irn_flags" => "R",
  "comment"   => "construct And: And(a, b) = And(b, a) = a AND b",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. and %ia32_emit_binop /* And(%A1, %A2) -> %D1 */',
  "units"     => [ "ALU" ],
},

"Or" => {
  "irn_flags" => "R",
  "comment"   => "construct Or: Or(a, b) = Or(b, a) = a OR b",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. or %ia32_emit_binop /* Or(%A1, %A2) -> %D1 */',
  "units"     => [ "ALU" ],
},

"Eor" => {
  "irn_flags" => "R",
  "comment"   => "construct Eor: Eor(a, b) = Eor(b, a) = a EOR b",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. xor %ia32_emit_binop /* Xor(%A1, %A2) -> %D1 */',
  "units"     => [ "ALU" ],
},

"l_Eor" => {
  "op_flags"  => "C",
  "cmp_attr"  => "return 1;",
  "comment"   => "construct lowered Eor: Eor(a, b) = Eor(b, a) = a EOR b",
  "arity"     => 2
},

"Max" => {
  "irn_flags" => "R",
  "comment"   => "construct Max: Max(a, b) = Max(b, a) = a > b ? a : b",
  "reg_req"   => { "in" => [ "gp", "gp" ], "out" => [ "in_r1" ] },
  "emit"      =>
'2. cmp %S1, %S2 /* prepare Max (%S1 - %S2), (%A1, %A2) */
  if (mode_is_signed(get_irn_mode(n))) {
4.  cmovl %D1, %S2 /* %S1 is less %S2 */
  }
  else {
4.  cmovb %D1, %S2 /* %S1 is below %S2 */
  }
',
  "latency"   => 2,
  "units"     => [ "ALU" ],
},

"Min" => {
  "irn_flags" => "R",
  "comment"   => "construct Min: Min(a, b) = Min(b, a) = a < b ? a : b",
  "reg_req"   => { "in" => [ "gp", "gp" ], "out" => [ "in_r1" ] },
  "emit"      =>
'2. cmp %S1, %S2 /* prepare Min (%S1 - %S2), (%A1, %A2) */
  if (mode_is_signed(get_irn_mode(n))) {
2.  cmovg %D1, %S2 /* %S1 is greater %S2 */
  }
  else {
2.  cmova %D1, %S2, %D1 /* %S1 is above %S2 */
  }
',
  "latency"   => 2,
  "units"     => [ "ALU" ],
},

# not commutative operations

"Sub" => {
  "irn_flags" => "R",
  "comment"   => "construct Sub: Sub(a, b) = a - b",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. sub %ia32_emit_binop /* Sub(%A3, %A4) -> %D1 */',
  "units"     => [ "ALU" ],
},

"SubC" => {
  "comment"   => "construct Sub with Carry: SubC(a, b) = a - b - carry",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp", "none" ], "out" => [ "in_r3 !in_r4" ] },
  "emit"      => '. sbb %ia32_emit_binop /* SubC(%A3, %A4) -> %D1 */',
  "units"     => [ "ALU" ],
},

"Sub64Bit" => {
  "irn_flags" => "R",
  "comment"   => "construct 64Bit Sub: Sub(a_l, a_h, b_l, b_h) = a_l - b_l; a_h - b_h - borrow",
  "arity"     => 4,
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp" ], "out" => [ "!in", "!in" ] },
  "emit"      => '
. mov %D1, %S1 /* mov a_l into assigned l_res register */
. mov %D2, %S2 /* mov a_h into assigned h_res register */
. sub %D1, %S3 /* a_l - b_l */
. sbb %D2, %S4 /* a_h - b_h - borrow */
',
  "outs"      => [ "low_res", "high_res" ],
  "units"     => [ "ALU" ],
},

"l_Sub" => {
  "irn_flags" => "R",
  "cmp_attr"  => "return 1;",
  "comment"   => "construct lowered Sub: Sub(a, b) = a - b",
  "arity"     => 2,
},

"l_SubC" => {
  "cmp_attr"  => "return 1;",
  "comment"   => "construct lowered Sub with Carry: SubC(a, b) = a - b - carry",
  "arity"     => 2,
},

"DivMod" => {
  "op_flags"  => "F|L",
  "state"     => "exc_pinned",
  "reg_req"   => { "in" => [ "eax", "gp", "edx", "none" ], "out" => [ "eax", "edx" ] },
  "attr"      => "ia32_op_flavour_t dm_flav",
  "init_attr" => "  attr->data.op_flav = dm_flav;",
  "cmp_attr"  => "  return attr_a->data.op_flav != attr_b->data.op_flav;\n",
  "emit"      =>
'  if (mode_is_signed(get_ia32_res_mode(n))) {
4.  idiv %S2 /* signed DivMod(%S1, %S2) -> %D1, (%A1, %A2, %A3) */
  }
  else {
4.  div %S2 /* unsigned DivMod(%S1, %S2) -> %D1, (%A1, %A2, %A3) */
  }
',
  "outs"      => [ "div_res", "mod_res", "M" ],
  "latency"   => 25,
  "units"     => [ "ALU" ],
},

"Shl" => {
  "irn_flags" => "R",
  "comment"   => "construct Shl: Shl(a, b) = a << b",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "ecx", "none" ], "out" => [ "in_r3 !in_r4" ] },
  "emit"      => '. shl %ia32_emit_binop /* Shl(%A1, %A2) -> %D1 */',
  "units"     => [ "ALU1", "SSE1" ],
},

"l_Shl" => {
  "cmp_attr"  => "return 1;",
  "comment"   => "construct lowered Shl: Shl(a, b) = a << b",
  "arity"     => 2
},

"ShlD" => {
  "irn_flags" => "R",
  "comment"   => "construct ShlD: ShlD(a, b, c) = a, b << count (shift left count bits from b into a)",
  # Out requirements is: different from all in
  # This is because, out must be different from LowPart and ShiftCount.
  # We could say "!ecx !in_r4" but it can occur, that all values live through
  # this Shift and the only value dying is the ShiftCount. Then there would be a
  # register missing, as result must not be ecx and all other registers are
  # occupied. What we should write is "!in_r4 !in_r5", but this is not supported
  # (and probably never will). So we create artificial interferences of the result
  # with all inputs, so the spiller can always assure a free register.
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp", "ecx", "none" ], "out" => [ "!in" ] },
  "emit"      =>
'
if (get_ia32_immop_type(n) == ia32_ImmNone) {
  if (get_ia32_op_type(n) == ia32_AddrModeD) {
4. shld %ia32_emit_am, %S4, %%cl /* ShlD(%A3, %A4, %A5) -> %D1 */
  }
  else {
4. shld %S3, %S4, %%cl /* ShlD(%A3, %A4, %A5) -> %D1 */
  }
}
else {
  if (get_ia32_op_type(n) == ia32_AddrModeD) {
4. shld %ia32_emit_am, %S4, %C /* ShlD(%A3, %A4, %A5) -> %D1 */
  }
  else {
4. shld %S3, %S4, %C /* ShlD(%A3, %A4, %A5) -> %D1 */
  }
}
',
  "latency"   => 6,
  "units"     => [ "ALU1", "SSE1" ],
},

"l_ShlD" => {
  "cmp_attr"  => "return 1;",
  "comment"   => "construct lowered ShlD: ShlD(a, b, c) = a, b << count (shift left count bits from b into a)",
  "arity"     => 3
},

"Shr" => {
  "irn_flags" => "R",
  "comment"   => "construct Shr: Shr(a, b) = a >> b",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "ecx", "none" ], "out" => [ "in_r3 !in_r4" ] },
  "emit"      => '. shr %ia32_emit_binop /* Shr(%A1, %A2) -> %D1 */',
  "units"     => [ "ALU1", "SSE1" ],
},

"l_Shr" => {
  "cmp_attr"  => "return 1;",
  "comment"   => "construct lowered Shr: Shr(a, b) = a << b",
  "arity"     => 2
},

"ShrD" => {
  "irn_flags" => "R",
  "comment"   => "construct ShrD: ShrD(a, b, c) = a, b >> count (shift rigth count bits from a into b)",
  # Out requirements is: different from all in
  # This is because, out must be different from LowPart and ShiftCount.
  # We could say "!ecx !in_r4" but it can occur, that all values live through
  # this Shift and the only value dying is the ShiftCount. Then there would be a
  # register missing, as result must not be ecx and all other registers are
  # occupied. What we should write is "!in_r4 !in_r5", but this is not supported
  # (and probably never will). So we create artificial interferences of the result
  # with all inputs, so the spiller can always assure a free register.
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp", "ecx", "none" ], "out" => [ "!in" ] },
  "emit"      =>
'
if (get_ia32_immop_type(n) == ia32_ImmNone) {
  if (get_ia32_op_type(n) == ia32_AddrModeD) {
4. shrd %ia32_emit_am, %S4, %%cl /* ShrD(%A3, %A4, %A5) -> %D1 */
  }
  else {
4. shrd %S3, %S4, %%cl /* ShrD(%A3, %A4, %A5) -> %D1 */
  }
}
else {
  if (get_ia32_op_type(n) == ia32_AddrModeD) {
4. shrd %ia32_emit_am, %S4, %C /* ShrD(%A3, %A4, %A5) -> %D1 */
  }
  else {
4. shrd %S3, %S4, %C /* ShrD(%A3, %A4, %A5) -> %D1 */
  }
}
',
  "latency"   => 6,
  "units"     => [ "ALU1", "SSE1" ],
},

"l_ShrD" => {
  "cmp_attr"  => "return 1;",
  "comment"   => "construct lowered ShrD: ShrD(a, b, c) = a, b >> count (shift rigth count bits from a into b)",
  "arity"     => 3
},

"Shrs" => {
  "irn_flags" => "R",
  "comment"   => "construct Shrs: Shrs(a, b) = a >> b",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "ecx", "none" ], "out" => [ "in_r3 !in_r4" ] },
  "emit"      => '. sar %ia32_emit_binop /* Shrs(%A1, %A2) -> %D1 */',
  "units"     => [ "ALU1", "SSE1" ],
},

"l_Shrs" => {
  "cmp_attr"  => "return 1;",
  "comment"   => "construct lowered Shrs: Shrs(a, b) = a << b",
  "arity"     => 2
},

"RotR" => {
  "irn_flags" => "R",
  "comment"     => "construct RotR: RotR(a, b) = a ROTR b",
  "reg_req"     => { "in" => [ "gp", "gp", "gp", "ecx", "none" ], "out" => [ "in_r3 !in_r4" ] },
  "emit"        => '. ror %ia32_emit_binop /* RotR(%A1, %A2) -> %D1 */',
  "units"     => [ "ALU1", "SSE1" ],
},

"RotL" => {
  "irn_flags" => "R",
  "comment"   => "construct RotL: RotL(a, b) = a ROTL b",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "ecx", "none" ], "out" => [ "in_r3 !in_r4" ] },
  "emit"      => '. rol %ia32_emit_binop /* RotL(%A1, %A2) -> %D1 */',
  "units"     => [ "ALU1", "SSE1" ],
},

# unary operations

"Minus" => {
  "irn_flags" => "R",
  "comment"   => "construct Minus: Minus(a) = -a",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. neg %ia32_emit_unop /* Neg(%A1) -> %D1, (%A1) */',
  "units"     => [ "ALU" ],
},

"Minus64Bit" => {
  "irn_flags" => "R",
  "comment"   => "construct 64Bit Minus: Minus(a_l, a_h, 0) = 0 - a_l; 0 - a_h - borrow",
  "arity"     => 4,
  "reg_req"   => { "in" => [ "gp", "gp", "gp" ], "out" => [ "!in", "!in" ] },
  "emit"      => '
. mov %D1, %S1 /* l_res */
. mov %D2, %S1 /* h_res */
. sub %D1, %S2 /* 0 - a_l  ->  low_res */
. sbb %D2, %S3 /* 0 - a_h - borrow -> high_res */
',
  "outs"      => [ "low_res", "high_res" ],
  "units"     => [ "ALU" ],
},


"l_Minus" => {
  "cmp_attr"  => "return 1;",
  "comment"   => "construct lowered Minus: Minus(a) = -a",
  "arity"     => 1,
},

"Inc" => {
  "irn_flags" => "R",
  "comment"   => "construct Increment: Inc(a) = a++",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. inc %ia32_emit_unop /* Inc(%S1) -> %D1, (%A1) */',
  "units"     => [ "ALU" ],
},

"Dec" => {
  "irn_flags" => "R",
  "comment"   => "construct Decrement: Dec(a) = a--",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. dec %ia32_emit_unop /* Dec(%S1) -> %D1, (%A1) */',
  "units"     => [ "ALU" ],
},

"Not" => {
  "irn_flags" => "R",
  "comment"   => "construct Not: Not(a) = !a",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. not %ia32_emit_unop /* Not(%S1) -> %D1, (%A1) */',
  "units"     => [ "ALU" ],
},

# other operations

"CondJmp" => {
  "op_flags"  => "L|X|Y",
  "comment"   => "construct conditional jump: CMP A, B && JMPxx LABEL",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp", "none" ] },
  "outs"      => [ "false", "true" ],
  "latency"   => 3,
  "units"     => [ "BRANCH" ],
},

"TestJmp" => {
  "op_flags"  => "L|X|Y",
  "comment"   => "construct conditional jump: TEST A, B && JMPxx LABEL",
  "reg_req"  => { "in" => [ "gp", "gp" ] },
  "outs"      => [ "false", "true" ],
  "latency"   => 3,
  "units"     => [ "BRANCH" ],
},

"CJmpAM" => {
  "op_flags"  => "L|X|Y",
  "comment"   => "construct conditional jump without CMP (replaces CondJmp): JMPxx LABEL",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp", "none" ], "out" => [ "none", "none" ] },
  "outs"      => [ "false", "true" ],
  "units"     => [ "BRANCH" ],
},

"CJmp" => {
  "op_flags"  => "L|X|Y",
  "comment"   => "construct conditional jump without CMP (replaces TestJmp): JMPxx LABEL",
  "reg_req"   => { "in" => [ "gp", "gp" ] },
  "units"     => [ "BRANCH" ],
},

"SwitchJmp" => {
  "op_flags"  => "L|X|Y",
  "comment"   => "construct switch",
  "reg_req"   => { "in" => [ "gp" ], "out" => [ "none" ] },
  "latency"   => 3,
  "units"     => [ "BRANCH" ],
},

"Const" => {
  "op_flags"  => "c",
  "irn_flags" => "R",
  "comment"   => "represents an integer constant",
  "reg_req"   => { "out" => [ "gp" ] },
  "units"     => [ "ALU" ],
},

"Cdq" => {
  # we should not rematrialize this node. It produces 2 results and has
  # very strict constrains
  "comment"   => "construct CDQ: sign extend EAX -> EDX:EAX",
  "reg_req"   => { "in" => [ "gp" ], "out" => [ "eax in_r1", "edx" ] },
  "emit"      => '. cdq /* sign extend EAX -> EDX:EAX, (%A1) */',
  "outs"      => [ "EAX", "EDX" ],
  "units"     => [ "ALU" ],
},

# Load / Store

"Load" => {
  "op_flags"  => "L|F",
  "state"     => "exc_pinned",
  "comment"   => "construct Load: Load(ptr, mem) = LD ptr -> reg",
  "reg_req"   => { "in" => [ "gp", "gp", "none" ], "out" => [ "gp" ] },
  "latency"   => 3,
  "emit"      =>
'  if (get_mode_size_bits(get_ia32_ls_mode(n)) < 32) {
4.   mov%Mx %D1, %ia32_emit_am /* Load((%A1)) -> %D1 */
  }
  else {
4.   mov %D1, %ia32_emit_am /* Load((%A1)) -> %D1 */
  }
',
  "outs"      => [ "res", "M" ],
  "units"     => [ "MEM" ],
},

"l_Load" => {
  "op_flags"  => "L|F",
  "cmp_attr"  => "return 1;",
  "comment"   => "construct lowered Load: Load(ptr, mem) = LD ptr -> reg",
  "outs"      => [ "res", "M" ],
  "arity"     => 2,
},

"l_Store" => {
  "op_flags"  => "L|F",
  "cmp_attr"  => "return 1;",
  "state"     => "exc_pinned",
  "comment"   => "construct lowered Store: Store(ptr, val, mem) = ST ptr,val",
  "arity"     => 3,
  "mode"      => "mode_M",
},

"Store" => {
  "op_flags"  => "L|F",
  "state"     => "exc_pinned",
  "comment"   => "construct Store: Store(ptr, val, mem) = ST ptr,val",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "none" ] },
  "emit"      => '. mov %ia32_emit_binop /* Store(%A3) -> (%A1) */',
  "latency"   => 3,
  "units"     => [ "MEM" ],
  "mode"      => "mode_M",
},

"Store8Bit" => {
  "op_flags"  => "L|F",
  "state"     => "exc_pinned",
  "comment"   => "construct 8Bit Store: Store(ptr, val, mem) = ST ptr,val",
  "reg_req"   => { "in" => [ "gp", "gp", "eax ebx ecx edx", "none" ] },
  "emit"      => '. mov %ia32_emit_binop /* Store(%A3) -> (%A1) */',
  "latency"   => 3,
  "units"     => [ "MEM" ],
  "mode"      => "mode_M",
},

"Lea" => {
  "irn_flags" => "R",
  "comment"   => "construct Lea: Lea(a,b) = lea [a+b*const+offs] | res = a + b * const + offs with const = 0,1,2,4,8",
  "reg_req"   => { "in" => [ "gp", "gp" ], "out" => [ "in_r1" ] },
  "emit"      => '. lea %D1, %ia32_emit_am /* LEA(%A1, %A2) */',
  "latency"   => 2,
  "units"     => [ "ALU" ],
},

"Push" => {
  "comment"   => "push on the stack",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "esp", "none" ], "out" => [ "esp" ] },
  "emit"      => '. push %ia32_emit_unop /* PUSH(%A1) */',
  "outs"      => [ "stack:I|S", "M" ],
  "latency"   => 3,
  "units"     => [ "MEM" ],
},

"Pop" => {
  # We don't set class modify stack here (but we will do this on proj 1)
  "comment"   => "pop a gp register from the stack",
  "reg_req"   => { "in" => [ "gp", "gp", "esp", "none" ], "out" => [ "gp", "esp" ] },
  "emit"      => '. pop %ia32_emit_unop /* POP(%A1) */',
  "outs"      => [ "res", "stack:I|S", "M" ],
  "latency"   => 4,
  "units"     => [ "MEM" ],
},

"Enter" => {
  "comment"   => "create stack frame",
  "reg_req"   => { "in" => [ "esp" ], "out" => [ "ebp", "esp" ] },
  "emit"      => '. enter /* Enter */',
  "outs"      => [ "frame:I", "stack:I|S", "M" ],
  "latency"   => 15,
  "units"     => [ "MEM" ],
},

"Leave" => {
  "comment"   => "destroy stack frame",
  "reg_req"   => { "in" => [ "esp", "ebp" ], "out" => [ "ebp", "esp" ] },
  "emit"      => '. leave /* Leave */',
  "outs"      => [ "frame:I", "stack:I|S", "M" ],
  "latency"   => 3,
  "units"     => [ "MEM" ],
},

"AddSP" => {
  "irn_flags" => "I",
  "comment"   => "allocate space on stack",
  "reg_req"   => { "in" => [ "esp", "gp" ], "out" => [ "esp", "none" ] },
  "outs"      => [ "stack:S", "M" ],
  "units"     => [ "ALU" ],
},

"SubSP" => {
  "irn_flags" => "I",
  "comment"   => "free space on stack",
  "reg_req"   => { "in" => [ "esp", "gp" ], "out" => [ "esp", "none" ] },
  "outs"      => [ "stack:S", "M" ],
  "units"     => [ "ALU" ],
},

"LdTls" => {
  "irn_flags" => "R",
  "comment"   => "get the TLS base address",
  "reg_req"   => { "out" => [ "gp" ] },
  "units"     => [ "MEM" ],
},



#-----------------------------------------------------------------------------#
#   _____ _____ ______    __ _             _                     _            #
#  / ____/ ____|  ____|  / _| |           | |                   | |           #
# | (___| (___ | |__    | |_| | ___   __ _| |_   _ __   ___   __| | ___  ___  #
#  \___ \\___ \|  __|   |  _| |/ _ \ / _` | __| | '_ \ / _ \ / _` |/ _ \/ __| #
#  ____) |___) | |____  | | | | (_) | (_| | |_  | | | | (_) | (_| |  __/\__ \ #
# |_____/_____/|______| |_| |_|\___/ \__,_|\__| |_| |_|\___/ \__,_|\___||___/ #
#-----------------------------------------------------------------------------#

# commutative operations

"xAdd" => {
  "irn_flags" => "R",
  "comment"   => "construct SSE Add: Add(a, b) = Add(b, a) = a + b",
  "reg_req"   => { "in" => [ "gp", "gp", "xmm", "xmm", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. adds%M %ia32_emit_binop /* SSE Add(%A3, %A4) -> %D1 */',
  "latency"   => 4,
  "units"     => [ "SSE" ],
},

"xMul" => {
  "irn_flags" => "R",
  "comment"   => "construct SSE Mul: Mul(a, b) = Mul(b, a) = a * b",
  "reg_req"   => { "in" => [ "gp", "gp", "xmm", "xmm", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. muls%M %ia32_emit_binop /* SSE Mul(%A3, %A4) -> %D1 */',
  "latency"   => 4,
  "units"     => [ "SSE" ],
},

"xMax" => {
  "irn_flags" => "R",
  "comment"   => "construct SSE Max: Max(a, b) = Max(b, a) = a > b ? a : b",
  "reg_req"   => { "in" => [ "gp", "gp", "xmm", "xmm", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. maxs%M %ia32_emit_binop /* SSE Max(%A3, %A4) -> %D1 */',
  "latency"   => 2,
  "units"     => [ "SSE" ],
},

"xMin" => {
  "irn_flags" => "R",
  "comment"   => "construct SSE Min: Min(a, b) = Min(b, a) = a < b ? a : b",
  "reg_req"   => { "in" => [ "gp", "gp", "xmm", "xmm", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. mins%M %ia32_emit_binop /* SSE Min(%A3, %A4) -> %D1 */',
  "latency"   => 2,
  "units"     => [ "SSE" ],
},

"xAnd" => {
  "irn_flags" => "R",
  "comment"   => "construct SSE And: And(a, b) = a AND b",
  "reg_req"   => { "in" => [ "gp", "gp", "xmm", "xmm", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. andp%M %ia32_emit_binop /* SSE And(%A3, %A4) -> %D1 */',
  "latency"   => 3,
  "units"     => [ "SSE" ],
},

"xOr" => {
  "irn_flags" => "R",
  "comment"   => "construct SSE Or: Or(a, b) = a OR b",
  "reg_req"   => { "in" => [ "gp", "gp", "xmm", "xmm", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. orp%M %ia32_emit_binop /* SSE Or(%A3, %A4) -> %D1 */',
  "units"     => [ "SSE" ],
},

"xEor" => {
  "irn_flags" => "R",
  "comment"   => "construct SSE Eor: Eor(a, b) = a XOR b",
  "reg_req"   => { "in" => [ "gp", "gp", "xmm", "xmm", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. xorp%M %ia32_emit_binop /* SSE Xor(%A3, %A4) -> %D1 */',
  "latency"   => 3,
  "units"     => [ "SSE" ],
},

# not commutative operations

"xAndNot" => {
  "irn_flags" => "R",
  "comment"   => "construct SSE AndNot: AndNot(a, b) = a AND NOT b",
  "reg_req"   => { "in" => [ "gp", "gp", "xmm", "xmm", "none" ], "out" => [ "in_r3 !in_r4" ] },
  "emit"      => '. andnp%M %ia32_emit_binop /* SSE AndNot(%A3, %A4) -> %D1 */',
  "latency"   => 3,
  "units"     => [ "SSE" ],
},

"xSub" => {
  "irn_flags" => "R",
  "comment"   => "construct SSE Sub: Sub(a, b) = a - b",
  "reg_req"   => { "in" => [ "gp", "gp", "xmm", "xmm", "none" ], "out" => [ "in_r3" ] },
  "emit"      => '. subs%M %ia32_emit_binop /* SSE Sub(%A1, %A2) -> %D1 */',
  "latency"   => 4,
  "units"     => [ "SSE" ],
},

"xDiv" => {
  "irn_flags" => "R",
  "comment"   => "construct SSE Div: Div(a, b) = a / b",
  "reg_req"   => { "in" => [ "gp", "gp", "xmm", "xmm", "none" ], "out" => [ "in_r3 !in_r4" ] },
  "outs"      => [ "res", "M" ],
  "emit"      => '. divs%M %ia32_emit_binop /* SSE Div(%A1, %A2) -> %D1 */',
  "latency"   => 16,
  "units"     => [ "SSE" ],
},

# other operations

"xCmp" => {
  "irn_flags" => "R",
  "comment"   => "construct SSE Compare: Cmp(a, b) == a = a cmp b",
  "reg_req"   => { "in" => [ "gp", "gp", "xmm", "xmm", "none" ], "out" => [ "in_r3 !in_r4" ] },
  "latency"   => 3,
  "units"     => [ "SSE" ],
},

"xCondJmp" => {
  "op_flags"  => "L|X|Y",
  "comment"   => "construct conditional jump: UCOMIS A, B && JMPxx LABEL",
  "reg_req"   => { "in" => [ "gp", "gp", "xmm", "xmm", "none" ], "out" => [ "none", "none" ] },
  "outs"      => [ "false", "true" ],
  "latency"   => 5,
  "units"     => [ "SSE" ],
},

"xConst" => {
  "op_flags"  => "c",
  "irn_flags" => "R",
  "comment"   => "represents a SSE constant",
  "reg_req"   => { "out" => [ "xmm" ] },
  "emit"      => '. movs%M %D1, %C /* Load fConst into register */',
  "latency"   => 2,
  "units"     => [ "SSE" ],
},

# Load / Store

"xLoad" => {
  "op_flags"  => "L|F",
  "state"     => "exc_pinned",
  "comment"   => "construct SSE Load: Load(ptr, mem) = LD ptr",
  "reg_req"   => { "in" => [ "gp", "gp", "none" ], "out" => [ "xmm" ] },
  "emit"      => '. movs%M %D1, %ia32_emit_am /* Load((%A1)) -> %D1 */',
  "outs"      => [ "res", "M" ],
  "latency"   => 2,
  "units"     => [ "SSE" ],
},

"xStore" => {
  "op_flags" => "L|F",
  "state"    => "exc_pinned",
  "comment"  => "construct Store: Store(ptr, val, mem) = ST ptr,val",
  "reg_req"  => { "in" => [ "gp", "gp", "xmm", "none" ] },
  "emit"     => '. movs%M %ia32_emit_binop /* Store(%S3) -> (%A1) */',
  "latency"  => 2,
  "units"    => [ "MEM" ],
  "mode"     => "mode_M",
},

"xStoreSimple" => {
  "op_flags" => "L|F",
  "state"    => "exc_pinned",
  "comment"  => "construct Store without index: Store(ptr, val, mem) = ST ptr,val",
  "reg_req"  => { "in" => [ "gp", "xmm", "none" ] },
  "emit"     => '. movs%M %ia32_emit_am, %S2 /* store XMM0 onto stack */',
  "latency"  => 2,
  "units"    => [ "MEM" ],
  "mode"     => "mode_M",
},

"l_X87toSSE" => {
  "op_flags" => "L|F",
  "comment"  => "construct: transfer a value from x87 FPU into a SSE register",
  "cmp_attr" => "return 1;",
  "arity"    => 3,
},

"l_SSEtoX87" => {
  "op_flags" => "L|F",
  "comment"  => "construct: transfer a value from SSE register to x87 FPU",
  "cmp_attr" => "return 1;",
  "arity"    => 3,
},

"GetST0" => {
  "op_flags" => "L|F",
  "irn_flags" => "I",
  "state"    => "exc_pinned",
  "comment"  => "store ST0 onto stack",
  "reg_req"  => { "in" => [ "gp", "gp", "none" ] },
  "emit"     => '. fstp %ia32_emit_am /* store ST0 onto stack */',
  "latency"  => 4,
  "units"    => [ "MEM" ],
  "mode"     => "mode_M",
},

"SetST0" => {
  "op_flags" => "L|F",
  "irn_flags" => "I",
  "state"    => "exc_pinned",
  "comment"  => "load ST0 from stack",
  "reg_req"  => { "in" => [ "gp", "none" ], "out" => [ "vf0", "none" ] },
  "emit"     => '. fld %ia32_emit_am /* load ST0 from stack */',
  "outs"     => [ "res", "M" ],
  "latency"  => 2,
  "units"     => [ "MEM" ],
},

# CopyB

"CopyB" => {
  "op_flags" => "F|H",
  "state"    => "pinned",
  "comment"  => "implements a memcopy: CopyB(dst, src, size, mem) == memcpy(dst, src, size)",
  "reg_req"  => { "in" => [ "edi", "esi", "ecx", "none" ], "out" => [ "edi", "esi", "ecx", "none" ] },
  "outs"     => [ "DST", "SRC", "CNT", "M" ],
  "units"     => [ "MEM" ],
},

"CopyB_i" => {
  "op_flags" => "F|H",
  "state"    => "pinned",
  "comment"  => "implements a memcopy: CopyB(dst, src, mem) == memcpy(dst, src, attr(size))",
  "reg_req"  => { "in" => [ "edi", "esi", "none" ], "out" => [  "edi", "esi", "none" ] },
  "outs"     => [ "DST", "SRC", "M" ],
  "units"     => [ "MEM" ],
},

# Conversions

"Conv_I2I" => {
  "reg_req"  => { "in" => [ "gp", "gp", "gp", "none" ], "out" => [ "in_r3", "none" ] },
  "comment"  => "construct Conv Int -> Int",
  "units"     => [ "ALU" ],
},

"Conv_I2I8Bit" => {
  "reg_req"  => { "in" => [ "gp", "gp", "eax ebx ecx edx", "none" ], "out" => [ "in_r3", "none" ] },
  "comment"  => "construct Conv Int -> Int",
  "units"     => [ "ALU" ],
},

"Conv_I2FP" => {
  "reg_req"  => { "in" => [ "gp", "gp", "gp", "none" ], "out" => [ "xmm", "none" ] },
  "comment"  => "construct Conv Int -> Floating Point",
  "latency"  => 10,
  "units"     => [ "SSE" ],
},

"Conv_FP2I" => {
  "reg_req"  => { "in" => [ "gp", "gp", "xmm", "none" ], "out" => [ "gp", "none" ] },
  "comment"  => "construct Conv Floating Point -> Int",
  "latency"  => 10,
  "units"     => [ "SSE" ],
},

"Conv_FP2FP" => {
  "reg_req"  => { "in" => [ "gp", "gp", "xmm", "none" ], "out" => [ "xmm", "none" ] },
  "comment"  => "construct Conv Floating Point -> Floating Point",
  "latency"  => 8,
  "units"     => [ "SSE" ],
},

"CmpCMov" => {
  "irn_flags" => "R",
  "comment"   => "construct Conditional Move: CMov(sel, a, b) == sel ? a : b",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp" ], "out" => [ "in_r4" ] },
  "latency"   => 2,
  "units"     => [ "ALU" ],
},

"PsiCondCMov" => {
  "irn_flags" => "R",
  "comment"   => "check if Psi condition tree evaluates to true and move result accordingly",
  "reg_req"   => { "in" => [ "gp", "gp", "gp" ], "out" => [ "in_r3" ] },
  "latency"   => 2,
  "units"     => [ "ALU" ],
},

"xCmpCMov" => {
  "irn_flags" => "R",
  "comment"   => "construct Conditional Move: SSE Compare + int CMov ",
  "reg_req"   => { "in" => [ "xmm", "xmm", "gp", "gp" ], "out" => [ "in_r4" ] },
  "latency"   => 5,
  "units"     => [ "SSE" ],
},

"vfCmpCMov" => {
  "irn_flags" => "R",
  "comment"   => "construct Conditional Move: x87 Compare + int CMov",
  "reg_req"   => { "in" => [ "vfp", "vfp", "gp", "gp" ], "out" => [ "in_r4" ] },
  "latency"   => 10,
  "units"     => [ "FPU" ],
},

"CmpSet" => {
  "irn_flags" => "R",
  "comment"   => "construct Set: Set(sel) == sel ? 1 : 0",
  "reg_req"   => { "in" => [ "gp", "gp", "gp", "gp", "none" ], "out" => [ "eax ebx ecx edx", "none" ] },
  "latency"   => 2,
  "units"     => [ "ALU" ],
},

"PsiCondSet" => {
  "irn_flags" => "R",
  "comment"   => "check if Psi condition tree evaluates to true and set result accordingly",
  "reg_req"   => { "in" => [ "gp" ], "out" => [ "eax ebx ecx edx" ] },
  "latency"   => 2,
  "units"     => [ "ALU" ],
},

"xCmpSet" => {
  "irn_flags" => "R",
  "comment"   => "construct Set: SSE Compare + int Set",
  "reg_req"   => { "in" => [ "gp", "gp", "xmm", "xmm", "none" ], "out" => [ "eax ebx ecx edx", "none" ] },
  "latency"   => 5,
  "units"     => [ "SSE" ],
},

"vfCmpSet" => {
  "irn_flags" => "R",
  "comment"   => "construct Set: x87 Compare + int Set",
  "reg_req"   => { "in" => [ "gp", "gp", "vfp", "vfp", "none" ], "out" => [ "eax ebx ecx edx", "none" ] },
  "latency"   => 10,
  "units"     => [ "FPU" ],
},

"vfCMov" => {
  "irn_flags" => "R",
  "comment"   => "construct x87 Conditional Move: vfCMov(sel, a, b) = sel ? a : b",
  "reg_req"   => { "in" => [ "vfp", "vfp", "vfp", "vfp" ], "out" => [ "vfp" ] },
  "latency"   => 10,
  "units"     => [ "FPU" ],
},

#----------------------------------------------------------#
#        _      _               _    __ _             _    #
#       (_)    | |             | |  / _| |           | |   #
# __   ___ _ __| |_ _   _  __ _| | | |_| | ___   __ _| |_  #
# \ \ / / | '__| __| | | |/ _` | | |  _| |/ _ \ / _` | __| #
#  \ V /| | |  | |_| |_| | (_| | | | | | | (_) | (_| | |_  #
#   \_/ |_|_|   \__|\__,_|\__,_|_| |_| |_|\___/ \__,_|\__| #
#                 | |                                      #
#  _ __   ___   __| | ___  ___                             #
# | '_ \ / _ \ / _` |/ _ \/ __|                            #
# | | | | (_) | (_| |  __/\__ \                            #
# |_| |_|\___/ \__,_|\___||___/                            #
#----------------------------------------------------------#

"vfadd" => {
  "irn_flags" => "R",
  "comment"   => "virtual fp Add: Add(a, b) = Add(b, a) = a + b",
  "reg_req"   => { "in" => [ "gp", "gp", "vfp", "vfp", "none" ], "out" => [ "vfp" ] },
  "latency"   => 4,
  "units"     => [ "FPU" ],
},

"vfmul" => {
  "irn_flags" => "R",
  "comment"   => "virtual fp Mul: Mul(a, b) = Mul(b, a) = a * b",
  "reg_req"   => { "in" => [ "gp", "gp", "vfp", "vfp", "none" ], "out" => [ "vfp" ] },
  "latency"   => 4,
  "units"     => [ "FPU" ],
},

"l_vfmul" => {
  "op_flags"  => "C",
  "cmp_attr"  => "return 1;",
  "comment"   => "lowered virtual fp Mul: Mul(a, b) = Mul(b, a) = a * b",
  "arity"     => 2,
},

"vfsub" => {
  "irn_flags" => "R",
  "comment"   => "virtual fp Sub: Sub(a, b) = a - b",
  "reg_req"   => { "in" => [ "gp", "gp", "vfp", "vfp", "none" ], "out" => [ "vfp" ] },
  "latency"   => 4,
  "units"     => [ "FPU" ],
},

"l_vfsub" => {
  "cmp_attr"  => "return 1;",
  "comment"   => "lowered virtual fp Sub: Sub(a, b) = a - b",
  "arity"     => 2,
},

"vfdiv" => {
  "comment"   => "virtual fp Div: Div(a, b) = a / b",
  "reg_req"   => { "in" => [ "gp", "gp", "vfp", "vfp", "none" ], "out" => [ "vfp" ] },
  "outs"      => [ "res", "M" ],
  "latency"   => 20,
  "units"     => [ "FPU" ],
},

"l_vfdiv" => {
  "cmp_attr"  => "return 1;",
  "comment"   => "lowered virtual fp Div: Div(a, b) = a / b",
  "arity"     => 2,
},

"vfprem" => {
  "comment"   => "virtual fp Rem: Rem(a, b) = a - Q * b (Q is integer)",
  "reg_req"   => { "in" => [ "gp", "gp", "vfp", "vfp", "none" ], "out" => [ "vfp" ] },
  "latency"   => 20,
  "units"     => [ "FPU" ],
},

"l_vfprem" => {
  "cmp_attr"  => "return 1;",
  "comment"   => "lowered virtual fp Rem: Rem(a, b) = a - Q * b (Q is integer)",
  "arity"     => 2,
},

"vfabs" => {
  "irn_flags" => "R",
  "comment"   => "virtual fp Abs: Abs(a) = |a|",
  "reg_req"   => { "in" => [ "vfp"], "out" => [ "vfp" ] },
  "latency"   => 2,
  "units"     => [ "FPU" ],
},

"vfchs" => {
  "irn_flags" => "R",
  "comment"   => "virtual fp Chs: Chs(a) = -a",
  "reg_req"   => { "in" => [ "vfp"], "out" => [ "vfp" ] },
  "latency"   => 2,
  "units"     => [ "FPU" ],
},

"vfsin" => {
  "irn_flags" => "R",
  "comment"   => "virtual fp Sin: Sin(a) = sin(a)",
  "reg_req"   => { "in" => [ "vfp"], "out" => [ "vfp" ] },
  "latency"   => 150,
  "units"     => [ "FPU" ],
},

"vfcos" => {
  "irn_flags" => "R",
  "comment"   => "virtual fp Cos: Cos(a) = cos(a)",
  "reg_req"   => { "in" => [ "vfp"], "out" => [ "vfp" ] },
  "latency"   => 150,
  "units"     => [ "FPU" ],
},

"vfsqrt" => {
  "irn_flags" => "R",
  "comment"   => "virtual fp Sqrt: Sqrt(a) = a ^ 0.5",
  "reg_req"   => { "in" => [ "vfp"], "out" => [ "vfp" ] },
  "latency"   => 30,
  "units"     => [ "FPU" ],
},

# virtual Load and Store

"vfld" => {
  "op_flags"  => "L|F",
  "state"     => "exc_pinned",
  "comment"   => "virtual fp Load: Load(ptr, mem) = LD ptr -> reg",
  "reg_req"   => { "in" => [ "gp", "gp", "none" ], "out" => [ "vfp", "none" ] },
  "outs"      => [ "res", "M" ],
  "latency"   => 2,
  "units"     => [ "FPU" ],
},

"vfst" => {
  "op_flags"  => "L|F",
  "state"     => "exc_pinned",
  "comment"   => "virtual fp Store: Store(ptr, val, mem) = ST ptr,val",
  "reg_req"   => { "in" => [ "gp", "gp", "vfp", "none" ] },
  "latency"   => 2,
  "units"     => [ "FPU" ],
  "mode"      => "mode_M",
},

# Conversions

"vfild" => {
  "comment"   => "virtual fp integer Load: Load(ptr, mem) = iLD ptr -> reg",
  "reg_req"   => { "in" => [ "gp", "gp", "none" ], "out" => [ "vfp", "none" ] },
  "outs"      => [ "res", "M" ],
  "latency"   => 4,
  "units"     => [ "FPU" ],
},

"l_vfild" => {
  "cmp_attr"  => "return 1;",
  "comment"   => "lowered virtual fp integer Load: Load(ptr, mem) = iLD ptr -> reg",
  "outs"      => [ "res", "M" ],
  "arity"     => 2,
},

"vfist" => {
  "comment"   => "virtual fp integer Store: Store(ptr, val, mem) = iST ptr,val",
  "reg_req"   => { "in" => [ "gp", "gp", "vfp", "none" ] },
  "latency"   => 4,
  "units"     => [ "FPU" ],
  "mode"      => "mode_M",
},

"l_vfist" => {
  "cmp_attr"  => "return 1;",
  "comment"   => "lowered virtual fp integer Store: Store(ptr, val, mem) = iST ptr,val",
  "arity"     => 3,
  "mode"      => "mode_M",
},


# constants

"vfldz" => {
  "irn_flags" => "R",
  "comment"   => "virtual fp Load 0.0: Ld 0.0 -> reg",
  "reg_req"   => { "out" => [ "vfp" ] },
  "latency"   => 4,
  "units"     => [ "FPU" ],
},

"vfld1" => {
  "irn_flags" => "R",
  "comment"   => "virtual fp Load 1.0: Ld 1.0 -> reg",
  "reg_req"   => { "out" => [ "vfp" ] },
  "latency"   => 4,
  "units"     => [ "FPU" ],
},

"vfldpi" => {
  "irn_flags" => "R",
  "comment"   => "virtual fp Load pi: Ld pi -> reg",
  "reg_req"   => { "out" => [ "vfp" ] },
  "latency"   => 4,
  "units"     => [ "FPU" ],
},

"vfldln2" => {
  "irn_flags" => "R",
  "comment"   => "virtual fp Load ln 2: Ld ln 2 -> reg",
  "reg_req"   => { "out" => [ "vfp" ] },
  "latency"   => 4,
  "units"     => [ "FPU" ],
},

"vfldlg2" => {
  "irn_flags" => "R",
  "comment"   => "virtual fp Load lg 2: Ld lg 2 -> reg",
  "reg_req"   => { "out" => [ "vfp" ] },
  "latency"   => 4,
  "units"     => [ "FPU" ],
},

"vfldl2t" => {
  "irn_flags" => "R",
  "comment"   => "virtual fp Load ld 10: Ld ld 10 -> reg",
  "reg_req"   => { "out" => [ "vfp" ] },
  "latency"   => 4,
  "units"     => [ "FPU" ],
},

"vfldl2e" => {
  "irn_flags" => "R",
  "comment"   => "virtual fp Load ld e: Ld ld e -> reg",
  "reg_req"   => { "out" => [ "vfp" ] },
  "latency"   => 4,
  "units"     => [ "FPU" ],
},

"vfConst" => {
  "op_flags"  => "c",
  "irn_flags" => "R",
  "init_attr" => "  set_ia32_ls_mode(res, mode);",
  "comment"   => "represents a virtual floating point constant",
  "reg_req"   => { "out" => [ "vfp" ] },
  "latency"   => 3,
  "units"     => [ "FPU" ],
},

# other

"vfCondJmp" => {
  "op_flags"  => "L|X|Y",
  "comment"   => "represents a virtual floating point compare",
  "reg_req"   => { "in" => [ "gp", "gp", "vfp", "vfp", "none" ], "out" => [ "none", "none", "eax" ] },
  "outs"      => [ "false", "true", "temp_reg_eax" ],
  "latency"   => 10,
  "units"     => [ "FPU" ],
},

#------------------------------------------------------------------------#
#       ___ _____    __ _             _                     _            #
# __  _( _ )___  |  / _| | ___   __ _| |_   _ __   ___   __| | ___  ___  #
# \ \/ / _ \  / /  | |_| |/ _ \ / _` | __| | '_ \ / _ \ / _` |/ _ \/ __| #
#  >  < (_) |/ /   |  _| | (_) | (_| | |_  | | | | (_) | (_| |  __/\__ \ #
# /_/\_\___//_/    |_| |_|\___/ \__,_|\__| |_| |_|\___/ \__,_|\___||___/ #
#------------------------------------------------------------------------#

"fadd" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 Add: Add(a, b) = Add(b, a) = a + b",
  "reg_req"   => { },
  "emit"      => '. fadd %ia32_emit_x87_binop /* x87 fadd(%A3, %A4) -> %D1 */',
},

"faddp" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 Add: Add(a, b) = Add(b, a) = a + b",
  "reg_req"   => { },
  "emit"      => '. faddp %ia32_emit_x87_binop /* x87 fadd(%A3, %A4) -> %D1 */',
},

"fmul" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp Mul: Mul(a, b) = Mul(b, a) = a + b",
  "reg_req"   => { },
  "emit"      => '. fmul %ia32_emit_x87_binop /* x87 fmul(%A3, %A4) -> %D1 */',
},

"fmulp" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp Mul: Mul(a, b) = Mul(b, a) = a + b",
  "reg_req"   => { },
  "emit"      => '. fmulp %ia32_emit_x87_binop /* x87 fmul(%A3, %A4) -> %D1 */',,
},

"fsub" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp Sub: Sub(a, b) = a - b",
  "reg_req"   => { },
  "emit"      => '. fsub %ia32_emit_x87_binop /* x87 fsub(%A3, %A4) -> %D1 */',
},

"fsubp" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp Sub: Sub(a, b) = a - b",
  "reg_req"   => { },
  "emit"      => '. fsubp %ia32_emit_x87_binop /* x87 fsub(%A3, %A4) -> %D1 */',
},

"fsubr" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "irn_flags" => "R",
  "comment"   => "x87 fp SubR: SubR(a, b) = b - a",
  "reg_req"   => { },
  "emit"      => '. fsubr %ia32_emit_x87_binop /* x87 fsubr(%A3, %A4) -> %D1 */',
},

"fsubrp" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "irn_flags" => "R",
  "comment"   => "x87 fp SubR: SubR(a, b) = b - a",
  "reg_req"   => { },
  "emit"      => '. fsubrp %ia32_emit_x87_binop /* x87 fsubr(%A3, %A4) -> %D1 */',
},

"fprem" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp Rem: Rem(a, b) = a - Q * b (Q is integer)",
  "reg_req"   => { },
  "emit"      => '. fprem1 /* x87 fprem(%A3, %A4) -> %D1 */',
},

# this node is just here, to keep the simulator running
# we can omit this when a fprem simulation function exists
"fpremp" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp Rem: Rem(a, b) = a - Q * b (Q is integer)",
  "reg_req"   => { },
  "emit"      => '. fprem1 /* x87 fprem(%A3, %A4) -> %D1 WITH POP */',
},

"fdiv" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp Div: Div(a, b) = a / b",
  "reg_req"   => { },
  "emit"      => '. fdiv %ia32_emit_x87_binop /* x87 fdiv(%A3, %A4) -> %D1 */',
},

"fdivp" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp Div: Div(a, b) = a / b",
  "reg_req"   => { },
  "emit"      => '. fdivp %ia32_emit_x87_binop /* x87 fdiv(%A3, %A4) -> %D1 */',
},

"fdivr" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp DivR: DivR(a, b) = b / a",
  "reg_req"   => { },
  "emit"      => '. fdivr %ia32_emit_x87_binop /* x87 fdivr(%A3, %A4) -> %D1 */',
},

"fdivrp" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp DivR: DivR(a, b) = b / a",
  "reg_req"   => { },
  "emit"      => '. fdivrp %ia32_emit_x87_binop /* x87 fdivr(%A3, %A4) -> %D1 */',
},

"fabs" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp Abs: Abs(a) = |a|",
  "reg_req"   => { },
  "emit"      => '. fabs /* x87 fabs(%A1) -> %D1 */',
},

"fchs" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp Chs: Chs(a) = -a",
  "reg_req"   => { },
  "emit"      => '. fchs /* x87 fchs(%A1) -> %D1 */',
},

"fsin" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp Sin: Sin(a) = sin(a)",
  "reg_req"   => { },
  "emit"      => '. fsin /* x87 sin(%A1) -> %D1 */',
},

"fcos" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp Cos: Cos(a) = cos(a)",
  "reg_req"   => { },
  "emit"      => '. fcos /* x87 cos(%A1) -> %D1 */',
},

"fsqrt" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp Sqrt: Sqrt(a) = a ^ 0.5",
  "reg_req"   => { },
  "emit"      => '. fsqrt $ /* x87 sqrt(%A1) -> %D1 */',
},

# x87 Load and Store

"fld" => {
  "rd_constructor" => "NONE",
  "op_flags"  => "R|L|F",
  "state"     => "exc_pinned",
  "comment"   => "x87 fp Load: Load(ptr, mem) = LD ptr -> reg",
  "reg_req"   => { },
  "emit"      => '. fld %ia32_emit_am /* Load((%A1)) -> %D1 */',
},

"fst" => {
  "rd_constructor" => "NONE",
  "op_flags"  => "R|L|F",
  "state"     => "exc_pinned",
  "comment"   => "x87 fp Store: Store(ptr, val, mem) = ST ptr,val",
  "reg_req"   => { },
  "emit"      => '. fst %ia32_emit_am /* Store(%A3) -> (%A1) */',
  "mode"      => "mode_M",
},

"fstp" => {
  "rd_constructor" => "NONE",
  "op_flags"  => "R|L|F",
  "state"     => "exc_pinned",
  "comment"   => "x87 fp Store: Store(ptr, val, mem) = ST ptr,val",
  "reg_req"   => { },
  "emit"      => '. fstp %ia32_emit_am /* Store(%A3) -> (%A1) and pop */',
  "mode"      => "mode_M",
},

# Conversions

"fild" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp integer Load: Load(ptr, mem) = iLD ptr -> reg",
  "reg_req"   => { },
  "emit"      => '. fild %ia32_emit_am /* integer Load((%A1)) -> %D1 */',
},

"fist" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp integer Store: Store(ptr, val, mem) = iST ptr,val",
  "reg_req"   => { },
  "emit"      => '. fist %ia32_emit_am /* integer Store(%A3) -> (%A1) */',
  "mode"      => "mode_M",
},

"fistp" => {
  "op_flags"  => "R",
  "rd_constructor" => "NONE",
  "comment"   => "x87 fp integer Store: Store(ptr, val, mem) = iST ptr,val",
  "reg_req"   => { },
  "emit"      => '. fistp %ia32_emit_am /* integer Store(%A3) -> (%A1) and pop */',
  "mode"      => "mode_M",
},

# constants

"fldz" => {
  "op_flags"  => "R|c",
  "irn_flags"  => "R",
  "comment"   => "x87 fp Load 0.0: Ld 0.0 -> reg",
  "reg_req"   => { "out" => [ "vfp" ] },
  "emit"      => '. fldz /* x87 0.0 -> %D1 */',
},

"fld1" => {
  "op_flags"  => "R|c",
  "irn_flags"  => "R",
  "comment"   => "x87 fp Load 1.0: Ld 1.0 -> reg",
  "reg_req"   => { "out" => [ "vfp" ] },
  "emit"      => '. fld1 /* x87 1.0 -> %D1 */',
},

"fldpi" => {
  "op_flags"  => "R|c",
  "irn_flags"  => "R",
  "comment"   => "x87 fp Load pi: Ld pi -> reg",
  "reg_req"   => { "out" => [ "vfp" ] },
  "emit"      => '. fldpi /* x87 pi -> %D1 */',
},

"fldln2" => {
  "op_flags"  => "R|c",
  "irn_flags"  => "R",
  "comment"   => "x87 fp Load ln 2: Ld ln 2 -> reg",
  "reg_req"   => { "out" => [ "vfp" ] },
  "emit"      => '. fldln2 /* x87 ln(2) -> %D1 */',
},

"fldlg2" => {
  "op_flags"  => "R|c",
  "irn_flags"  => "R",
  "comment"   => "x87 fp Load lg 2: Ld lg 2 -> reg",
  "reg_req"   => { "out" => [ "vfp" ] },
  "emit"      => '. fldlg2 /* x87 log(2) -> %D1 */',
},

"fldl2t" => {
  "op_flags"  => "R|c",
  "irn_flags"  => "R",
  "comment"   => "x87 fp Load ld 10: Ld ld 10 -> reg",
  "reg_req"   => { "out" => [ "vfp" ] },
  "emit"      => '. fldll2t /* x87 ld(10) -> %D1 */',
},

"fldl2e" => {
  "op_flags"  => "R|c",
  "irn_flags"  => "R",
  "comment"   => "x87 fp Load ld e: Ld ld e -> reg",
  "reg_req"   => { "out" => [ "vfp" ] },
  "emit"      => '. fldl2e /* x87 ld(e) -> %D1 */',
},

"fldConst" => {
  "op_flags"  => "R|c",
  "irn_flags" => "R",
  "rd_constructor" => "NONE",
  "comment"   => "represents a x87 constant",
  "reg_req"   => { "out" => [ "vfp" ] },
  "emit"      => '. fld %ia32_emit_adr /* Load fConst into register -> %D1 */',
},

# fxch, fpush, fpop
# Note that it is NEVER allowed to do CSE on these nodes
# Moreover, note the virtual register requierements!

"fxch" => {
  "op_flags"  => "R|K",
  "comment"   => "x87 stack exchange",
  "reg_req"   => { },
  "cmp_attr"  => "return 1;",
  "emit"      => '. fxch %X1 /* x87 swap %X1, %X3 */',
},

"fpush" => {
  "op_flags"  => "R|K",
  "comment"   => "x87 stack push",
  "reg_req"   => {},
  "cmp_attr"  => "return 1;",
  "emit"      => '. fld %X1 /* x87 push %X1 */',
},

"fpushCopy" => {
  "op_flags"  => "R",
  "comment"   => "x87 stack push",
  "reg_req"   => { "in" => [ "vfp"], "out" => [ "vfp" ] },
  "cmp_attr"  => "return 1;",
  "emit"      => '. fld %X1 /* x87 push %X1 */',
},

"fpop" => {
  "op_flags"  => "R|K",
  "comment"   => "x87 stack pop",
  "reg_req"   => { },
  "cmp_attr"  => "return 1;",
  "emit"      => '. fstp %X1 /* x87 pop %X1 */',
},

# compare

"fcomJmp" => {
  "op_flags"  => "L|X|Y",
  "comment"   => "floating point compare",
  "reg_req"   => { },
},

"fcompJmp" => {
  "op_flags"  => "L|X|Y",
  "comment"   => "floating point compare and pop",
  "reg_req"   => { },
},

"fcomppJmp" => {
  "op_flags"  => "L|X|Y",
  "comment"   => "floating point compare and pop twice",
  "reg_req"   => { },
},

"fcomrJmp" => {
  "op_flags"  => "L|X|Y",
  "comment"   => "floating point compare reverse",
  "reg_req"   => { },
},

"fcomrpJmp" => {
  "op_flags"  => "L|X|Y",
  "comment"   => "floating point compare reverse and pop",
  "reg_req"   => { },
},

"fcomrppJmp" => {
  "op_flags"  => "L|X|Y",
  "comment"   => "floating point compare reverse and pop twice",
  "reg_req"   => { },
},

); # end of %nodes
