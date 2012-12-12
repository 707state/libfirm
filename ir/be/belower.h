/*
 * This file is part of libFirm.
 * Copyright (C) 2012 University of Karlsruhe.
 */

/**
 * @file
 * @brief       Performs lowering of perm nodes. Inserts copies to assure
 *              register constraints.
 * @author      Christian Wuerdig
 * @date        14.12.2005
 */
#ifndef FIRM_BE_BELOWER_H
#define FIRM_BE_BELOWER_H

#include "firm_types.h"

/**
 * Walks over all nodes to assure register constraints.
 *
 * @param irg  The graph
 */
void assure_constraints(ir_graph *irg);

/**
 * Walks over all blocks in an irg and performs lowering need to be
 * done after register allocation (e.g. perm lowering).
 *
 * @param irg       The graph
 * @param do_copy   1 == resolve cycles with a free reg if available
 */
void lower_nodes_after_ra(ir_graph *irg, int do_copy);

#endif
