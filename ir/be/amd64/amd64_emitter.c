/*
 * This file is part of libFirm.
 * Copyright (C) 2012 University of Karlsruhe.
 */

/**
 * @file
 * @brief   emit assembler for a backend graph
 */
#include "config.h"

#include <limits.h>

#include "be_t.h"
#include "error.h"
#include "xmalloc.h"
#include "tv.h"
#include "iredges.h"
#include "debug.h"
#include "irgwalk.h"
#include "irop_t.h"
#include "irargs_t.h"
#include "irprog.h"

#include "besched.h"
#include "begnuas.h"
#include "beblocksched.h"

#include "amd64_emitter.h"
#include "gen_amd64_emitter.h"
#include "gen_amd64_regalloc_if.h"
#include "amd64_nodes_attr.h"
#include "amd64_new_nodes.h"

#include "benode.h"

/*************************************************************
 *             _       _    __   _          _
 *            (_)     | |  / _| | |        | |
 *  _ __  _ __ _ _ __ | |_| |_  | |__   ___| |_ __   ___ _ __
 * | '_ \| '__| | '_ \| __|  _| | '_ \ / _ \ | '_ \ / _ \ '__|
 * | |_) | |  | | | | | |_| |   | | | |  __/ | |_) |  __/ |
 * | .__/|_|  |_|_| |_|\__|_|   |_| |_|\___|_| .__/ \___|_|
 * | |                                       | |
 * |_|                                       |_|
 *************************************************************/

/**
 * Returns the target block for a control flow node.
 */
static ir_node *get_cfop_target_block(const ir_node *irn)
{
	return (ir_node*)get_irn_link(irn);
}

void amd64_emitf(ir_node const *const node, char const *fmt, ...)
{
	va_list ap;
	va_start(ap, fmt);

	be_emit_char('\t');
	for (;;) {
		char const *start = fmt;

		while (*fmt != '%' && *fmt != '\n' && *fmt != '\0')
			++fmt;
		if (fmt != start) {
			be_emit_string_len(start, fmt - start);
		}

		if (*fmt == '\n') {
			be_emit_char('\n');
			be_emit_write_line();
			be_emit_char('\t');
			++fmt;
			continue;
		}

		if (*fmt == '\0')
			break;

		++fmt;

		switch (*fmt++) {
			arch_register_t const *reg;

			case '%':
				be_emit_char('%');
				break;

			case 'C': {
				amd64_attr_t const *const attr = get_amd64_attr_const(node);
				be_emit_irprintf("$0x%X", attr->ext.imm_value);
				break;
			}

			case 'D':
				if (*fmt < '0' || '9' <= *fmt)
					goto unknown;
				reg = arch_get_irn_register_out(node, *fmt++ - '0');
				goto emit_R;

			case 'E': {
				ir_entity const *const ent = va_arg(ap, ir_entity const*);
				be_gas_emit_entity(ent);
				break;
			}

			case 'L': {
				ir_node *const block = get_cfop_target_block(node);
				be_gas_emit_block_name(block);
				break;
			}

			case 'O': {
				amd64_SymConst_attr_t const *const attr = get_amd64_SymConst_attr_const(node);
				if (attr->fp_offset)
					be_emit_irprintf("%d", attr->fp_offset);
				break;
			}

			case 'R':
				reg = va_arg(ap, arch_register_t const*);
emit_R:
				be_emit_char('%');
				be_emit_string(reg->name);
				break;

			case 'S': {
				int pos;
				if ('0' <= *fmt && *fmt <= '9') {
					pos = *fmt++ - '0';
				} else if (*fmt == '*') {
					++fmt;
					pos = va_arg(ap, int);
				} else {
					goto unknown;
				}
				reg = arch_get_irn_register_in(node, pos);
				goto emit_R;
			}

			case 'd': {
				int const num = va_arg(ap, int);
				be_emit_irprintf("%d", num);
				break;
			}

			case 's': {
				char const *const str = va_arg(ap, char const*);
				be_emit_string(str);
				break;
			}

			case 'u': {
				unsigned const num = va_arg(ap, unsigned);
				be_emit_irprintf("%u", num);
				break;
			}

			default:
unknown:
				panic("unknown format conversion");
		}
	}

	be_emit_finish_line_gas(node);
	va_end(ap);
}

/***********************************************************************************
 *                  _          __                                             _
 *                 (_)        / _|                                           | |
 *  _ __ ___   __ _ _ _ __   | |_ _ __ __ _ _ __ ___   _____      _____  _ __| | __
 * | '_ ` _ \ / _` | | '_ \  |  _| '__/ _` | '_ ` _ \ / _ \ \ /\ / / _ \| '__| |/ /
 * | | | | | | (_| | | | | | | | | | | (_| | | | | | |  __/\ V  V / (_) | |  |   <
 * |_| |_| |_|\__,_|_|_| |_| |_| |_|  \__,_|_| |_| |_|\___| \_/\_/ \___/|_|  |_|\_\
 *
 ***********************************************************************************/

/**
 * Emit a SymConst.
 */
static void emit_amd64_SymConst(const ir_node *irn)
{
	const amd64_SymConst_attr_t *attr = get_amd64_SymConst_attr_const(irn);
	amd64_emitf(irn, "mov $%E, %D0", attr->entity);
}

/**
 * Emit a Conv.
 */
static void emit_amd64_Conv(const ir_node *irn)
{
	amd64_emitf(irn, "mov %S0, %D0");
}


/**
 * Returns the next block in a block schedule.
 */
static ir_node *sched_next_block(const ir_node *block)
{
    return (ir_node*)get_irn_link(block);
}

/**
 * Emit a Jmp.
 */
static void emit_amd64_Jmp(const ir_node *node)
{
	ir_node *block, *next_block;

	/* for now, the code works for scheduled and non-schedules blocks */
	block = get_nodes_block(node);

	/* we have a block schedule */
	next_block = sched_next_block(block);
	if (get_cfop_target_block(node) != next_block) {
		amd64_emitf(node, "jmp %L");
	} else if (be_options.verbose_asm) {
		amd64_emitf(node, "/* fallthrough to %L */");
	}
}

/**
 * Emit a Compare with conditional branch.
 */
static void emit_amd64_Jcc(const ir_node *irn)
{
	const ir_node      *proj_true  = NULL;
	const ir_node      *proj_false = NULL;
	const ir_node      *block;
	const ir_node      *next_block;
	const char         *suffix;
	const amd64_attr_t *attr      = get_amd64_attr_const(irn);
	ir_relation         relation  = attr->ext.relation;
	ir_node            *op1       = get_irn_n(irn, 0);
	const amd64_attr_t *cmp_attr  = get_amd64_attr_const(op1);
	bool                is_signed = !cmp_attr->data.cmp_unsigned;

	assert(is_amd64_Cmp(op1));

	foreach_out_edge(irn, edge) {
		ir_node *proj = get_edge_src_irn(edge);
		long nr = get_Proj_proj(proj);
		if (nr == pn_Cond_true) {
			proj_true = proj;
		} else {
			proj_false = proj;
		}
	}

	if (cmp_attr->data.ins_permuted) {
		relation = get_inversed_relation(relation);
	}

	/* for now, the code works for scheduled and non-schedules blocks */
	block = get_nodes_block(irn);

	/* we have a block schedule */
	next_block = sched_next_block(block);

	assert(relation != ir_relation_false);
	assert(relation != ir_relation_true);

	if (get_cfop_target_block(proj_true) == next_block) {
		/* exchange both proj's so the second one can be omitted */
		const ir_node *t = proj_true;

		proj_true  = proj_false;
		proj_false = t;
		relation   = get_negated_relation(relation);
	}

	switch (relation & ir_relation_less_equal_greater) {
		case ir_relation_equal:              suffix = "e"; break;
		case ir_relation_less:               suffix = is_signed ? "l"  : "b"; break;
		case ir_relation_less_equal:         suffix = is_signed ? "le" : "be"; break;
		case ir_relation_greater:            suffix = is_signed ? "g"  : "a"; break;
		case ir_relation_greater_equal:      suffix = is_signed ? "ge" : "ae"; break;
		case ir_relation_less_greater:       suffix = "ne"; break;
		case ir_relation_less_equal_greater: suffix = "mp"; break;
		default: panic("Cmp has unsupported pnc");
	}

	/* emit the true proj */
	amd64_emitf(proj_true, "j%s %L", suffix);

	if (get_cfop_target_block(proj_false) != next_block) {
		amd64_emitf(proj_false, "jmp %L");
	} else if (be_options.verbose_asm) {
		amd64_emitf(proj_false, "/* fallthrough to %L */");
	}
}

/**
 * Emits code for a call.
 */
static void emit_be_Call(const ir_node *node)
{
	ir_entity *entity = be_Call_get_entity(node);

	/* %eax/%rax is used in AMD64 to pass the number of vector parameters for
	 * variable argument counts */
	if (get_method_variadicity (be_Call_get_type((ir_node *) node))) {
		/* But this still is a hack... */
		amd64_emitf(node, "xor %%rax, %%rax");
	}

	if (entity) {
		amd64_emitf(node, "call %E", entity);
	} else {
		be_emit_pad_comment();
		be_emit_cstring("/* FIXME: call NULL entity?! */\n");
	}
}

/**
 * emit copy node
 */
static void emit_be_Copy(const ir_node *irn)
{
	ir_mode *mode = get_irn_mode(irn);

	if (arch_get_irn_register_in(irn, 0) == arch_get_irn_register_out(irn, 0)) {
		/* omitted Copy */
		return;
	}

	if (mode_is_float(mode)) {
		panic("move not supported for FP");
	} else if (mode_is_data(mode)) {
		amd64_emitf(irn, "mov %S0, %D0");
	} else {
		panic("move not supported for this mode");
	}
}

static void emit_be_Perm(const ir_node *node)
{
	arch_register_t const *const reg0 = arch_get_irn_register_out(node, 0);
	arch_register_t const *const reg1 = arch_get_irn_register_out(node, 1);

	arch_register_class_t const* const cls0 = reg0->reg_class;
	assert(cls0 == reg1->reg_class && "Register class mismatch at Perm");

	amd64_emitf(node, "xchg %R, %R", reg0, reg1);

	if (cls0 != &amd64_reg_classes[CLASS_amd64_gp]) {
		panic("unexpected register class in be_Perm (%+F)", node);
	}
}

static void emit_amd64_FrameAddr(const ir_node *irn)
{
	const amd64_SymConst_attr_t *attr =
		(const amd64_SymConst_attr_t*) get_amd64_attr_const(irn);

	amd64_emitf(irn, "mov %S0, %D0");
	amd64_emitf(irn, "add $%u, %D0", attr->fp_offset);
}

/**
 * Emits code to increase stack pointer.
 */
static void emit_be_IncSP(const ir_node *node)
{
	int offs = be_get_IncSP_offset(node);

	if (offs == 0)
		return;

	if (offs > 0) {
		amd64_emitf(node, "sub, $%d, %D0", offs);
	} else {
		amd64_emitf(node, "add, $%d, %D0", -offs);
	}
}

/**
 * Emits code for a return.
 */
static void emit_be_Return(const ir_node *node)
{
	be_emit_cstring("\tret");
	be_emit_finish_line_gas(node);
}


static void emit_amd64_binop_op(const ir_node *irn, int second_op)
{
	if (irn->op == op_amd64_Add) {
		amd64_emitf(irn, "add %S*, %D0", second_op);
	} else if (irn->op == op_amd64_Sub) {
		amd64_emitf(irn, "neg %S*",      second_op);
		amd64_emitf(irn, "add %S*, %D0", second_op);
		amd64_emitf(irn, "neg %S*",      second_op);
	}

}

/**
 * Emits an arithmetic operation that handles arbitraty input registers.
 */
static void emit_amd64_binop(const ir_node *irn)
{
	const arch_register_t *reg_s1 = arch_get_irn_register_in(irn, 0);
	const arch_register_t *reg_s2 = arch_get_irn_register_in(irn, 1);
	const arch_register_t *reg_d1 = arch_get_irn_register_out(irn, 0);

	int second_op = 0;

	if (reg_d1 != reg_s1 && reg_d1 != reg_s2) {
		amd64_emitf(irn, "mov %R, %R", reg_s1, reg_d1);
		second_op = 1;
	} else if (reg_d1 == reg_s2 && reg_d1 != reg_s1) {
		second_op = 0;
	}

	emit_amd64_binop_op(irn, second_op);
}

/**
 * Enters the emitter functions for handled nodes into the generic
 * pointer of an opcode.
 */
static void amd64_register_emitters(void)
{
	/* first clear the generic function pointer for all ops */
	ir_clear_opcodes_generic_func();

	/* register all emitter functions defined in spec */
	amd64_register_spec_emitters();

	be_set_emitter(op_amd64_Add,        emit_amd64_binop);
	be_set_emitter(op_amd64_Conv,       emit_amd64_Conv);
	be_set_emitter(op_amd64_FrameAddr,  emit_amd64_FrameAddr);
	be_set_emitter(op_amd64_Jcc,        emit_amd64_Jcc);
	be_set_emitter(op_amd64_Jmp,        emit_amd64_Jmp);
	be_set_emitter(op_amd64_Sub,        emit_amd64_binop);
	be_set_emitter(op_amd64_SymConst,   emit_amd64_SymConst);
	be_set_emitter(op_be_Call,          emit_be_Call);
	be_set_emitter(op_be_Copy,          emit_be_Copy);
	be_set_emitter(op_be_IncSP,         emit_be_IncSP);
	be_set_emitter(op_be_Perm,          emit_be_Perm);
	be_set_emitter(op_be_Return,        emit_be_Return);

	be_set_emitter(op_Phi,      be_emit_nothing);
	be_set_emitter(op_be_Keep,  be_emit_nothing);
	be_set_emitter(op_be_Start, be_emit_nothing);
}

/**
 * Walks over the nodes in a block connected by scheduling edges
 * and emits code for each node.
 */
static void amd64_gen_block(ir_node *block, void *data)
{
	(void) data;

	if (! is_Block(block))
		return;

	be_gas_begin_block(block, true);

	sched_foreach(block, node) {
		be_emit_node(node);
	}
}


/**
 * Sets labels for control flow nodes (jump target)
 * TODO: Jump optimization
 */
static void amd64_gen_labels(ir_node *block, void *env)
{
	ir_node *pred;
	int n = get_Block_n_cfgpreds(block);
	(void) env;

	for (n--; n >= 0; n--) {
		pred = get_Block_cfgpred(block, n);
		set_irn_link(pred, block);
	}
}

/**
 * Main driver
 */
void amd64_gen_routine(ir_graph *irg)
{
	ir_entity *entity = get_irg_entity(irg);
	ir_node  **blk_sched;
	size_t i, n;

	/* register all emitter functions */
	amd64_register_emitters();

	blk_sched = be_create_block_schedule(irg);

	be_gas_emit_function_prolog(entity, 4, NULL);

	irg_block_walk_graph(irg, amd64_gen_labels, NULL, NULL);

	n = ARR_LEN(blk_sched);
	for (i = 0; i < n; i++) {
		ir_node *block = blk_sched[i];
		ir_node *next  = (i + 1) < n ? blk_sched[i+1] : NULL;

		set_irn_link(block, next);
	}

	for (i = 0; i < n; ++i) {
		ir_node *block = blk_sched[i];

		amd64_gen_block(block, 0);
	}

	be_gas_emit_function_epilog(entity);
}
