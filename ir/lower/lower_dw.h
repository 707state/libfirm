/*
 * Copyright (C) 1995-2011 University of Karlsruhe.  All right reserved.
 *
 * This file is part of libFirm.
 *
 * This file may be distributed and/or modified under the terms of the
 * GNU General Public License version 2 as published by the Free Software
 * Foundation and appearing in the file LICENSE.GPL included in the
 * packaging of this file.
 *
 * Licensees holding valid libFirm Professional Edition licenses may use
 * this file in accordance with the libFirm Commercial License.
 * Agreement provided with the Software.
 *
 * This file is provided AS IS with NO WARRANTY OF ANY KIND, INCLUDING THE
 * WARRANTY OF DESIGN, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE.
 */

/**
 * @file
 * @brief   doubleword lowering operations
 * @author  Michael Beck, Matthias Braun
 */
#ifndef FIRM_LOWER_LOWER_DW_H
#define FIRM_LOWER_LOWER_DW_H

/**
 * Every double word node will be replaced,
 * we need some store to hold the replacement:
 */
typedef struct lower64_entry_t {
	ir_node *low_word;    /**< the low word */
	ir_node *high_word;   /**< the high word */
} lower64_entry_t;


/**
 * A callback type for creating an intrinsic entity for a given opcode.
 *
 * @param method   the method type of the emulation function entity
 * @param op       the emulated ir_op
 * @param imode    the input mode of the emulated opcode
 * @param omode    the output mode of the emulated opcode
 * @param context  the context parameter
 */
typedef ir_entity *(create_intrinsic_fkt)(ir_type *method, const ir_op *op,
                                          const ir_mode *imode,
                                          const ir_mode *omode, void *context);

/**
 * The lowering parameter description.
 */
typedef struct lwrdw_param_t {
	unsigned              little_endian : 1; /**< if true should be lowered for little endian, else big endian */
	unsigned              doubleword_size;   /**< bitsize of the doubleword mode */
	create_intrinsic_fkt *create_intrinsic;  /**< callback that creates the intrinsic entity */
	void                 *ctx;               /**< context parameter for the creator function */
} lwrdw_param_t;

/**
 * Prepare the doubleword lowering algorithm. Creates an environment
 * which can be used to register custom lowering functions
 */
void ir_prepare_dw_lowering(const lwrdw_param_t *param);

/**
 * Lower all doubleword operations in the program.
 * Must be called after ir_prepare_dw_lowering()
 */
void ir_lower_dw_ops(void);

typedef void (*lower_dw_func)(ir_node *node, ir_mode *mode);

/**
 * register a custom lowering function.
 * After lowering the custom function should call ir_set_dw_lowered()
 */
void ir_register_dw_lower_function(ir_op *op, lower_dw_func func);

/**
 * After lowering a node a custom doubleword lowering function has to call this.
 * It registers 2 new values for the high and low part of the lowered value.
 */
void ir_set_dw_lowered(ir_node *old, ir_node *new_low,
                                ir_node *new_high);

/**
 * Query lowering results of a node. In a lowering callback you can use this
 * on all predecessors of a node. The only exception are block and phi nodes.
 * Their predecessors are not necessarily transformed yet.
 */
lower64_entry_t *get_node_entry(ir_node *node);

static inline ir_node *get_lowered_low(ir_node *node)
{
	return get_node_entry(node)->low_word;
}

static inline ir_node *get_lowered_high(ir_node *node)
{
	return get_node_entry(node)->high_word;
}

/**
 * Default implementation. Context is unused.
 */
ir_entity *def_create_intrinsic_fkt(ir_type *method, const ir_op *op,
                                    const ir_mode *imode, const ir_mode *omode,
                                    void *context);

#endif
