/*
 * This file is part of libFirm.
 * Copyright (C) 2012 University of Karlsruhe.
 */

/**
 * @file
 * @brief       Contains some useful function for the backend.
 * @author      Sebastian Hack
 */
#ifndef FIRM_BE_BEUTIL_H
#define FIRM_BE_BEUTIL_H

#include "firm_types.h"

/**
 * Convenient block getter.
 * Works also, if the given node is a block.
 * @param  irn The node.
 * @return The block of the node, or the node itself, if the node is a
 *         block.
 */
static inline ir_node *get_block(ir_node *irn)
{
	return is_Block(irn) ? irn : get_nodes_block(irn);
}

static inline const ir_node *get_block_const(const ir_node *irn)
{
	return is_Block(irn) ? irn : get_nodes_block(irn);
}

/**
 * Clears the link fields of all nodes of the given graph.
 * @param irg The graph.
 */
void be_clear_links(ir_graph *irg);

/**
 * Gets the Proj with number pn from irn.
 */
ir_node *be_get_Proj_for_pn(const ir_node *irn, long pn);

/**
 * Returns an array (an ARR_F) of the programs blocks in reverse postorder
 * (note: caller has to free the memory with DEL_ARR_F after use;
 *  of course you can use ARR_LEN on the array too.)
 */
ir_node **be_get_cfgpostorder(ir_graph *irg);

/**
 * convenience function to return the first successor block
 * (it is often known that there is exactly 1 successor anyway)
 */
ir_node *get_first_block_succ(const ir_node *block);

#endif
