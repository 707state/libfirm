/**
 * Scheduling algorithms.
 * Just a simple list scheduling algorithm is here.
 * @date 20.10.2004
 * @author Sebastian Hack
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <limits.h>

#include "benode_t.h"

#include "obst.h"
#include "list.h"
#include "iterator.h"

#include "iredges_t.h"
#include "irgwalk.h"
#include "irnode_t.h"
#include "irmode_t.h"
#include "irdump.h"
#include "irprintf_t.h"
#include "array.h"
#include "debug.h"
#include "irtools.h"

#include "besched_t.h"
#include "beutil.h"
#include "belive_t.h"
#include "belistsched.h"
#include "beschedmris.h"
#include "bearch.h"
#include "bestat.h"

/**
 * All scheduling info needed per node.
 */
typedef struct _sched_irn_t {
	sched_timestep_t delay;     /**< The delay for this node if already calculated, else 0. */
	sched_timestep_t etime;     /**< The earliest time of this node. */
	unsigned already_sched : 1; /**< Set if this node is already scheduled */
	unsigned is_root       : 1; /**< is a root node of a block */
} sched_irn_t;

/**
 * Scheduling environment for the whole graph.
 */
typedef struct _sched_env_t {
	sched_irn_t *sched_info;                    /**< scheduling info per node */
	const list_sched_selector_t *selector;      /**< The node selector. */
	const arch_env_t *arch_env;                 /**< The architecture environment. */
	const ir_graph *irg;                        /**< The graph to schedule. */
	void *selector_env;                         /**< A pointer to give to the selector. */
} sched_env_t;

#if 0
/*
 * Ugly global variable for the compare function
 * since qsort(3) does not pass an extra pointer.
 */
static ir_node *curr_bl = NULL;

static int cmp_usage(const void *a, const void *b)
{
	struct trivial_sched_env *env;
	const ir_node *p = a;
	const ir_node *q = b;
	int res = 0;

	res = is_live_end(env->curr_bl, a) - is_live_end(env->curr_bl, b);

	/*
	 * One of them is live at the end of the block.
	 * Then, that one shall be scheduled at after the other
	 */
	if(res != 0)
		return res;


	return res;
}
#endif

/**
 * The trivial selector:
 * Just assure that branches are executed last, otherwise select
 * the first node ready.
 */
static ir_node *trivial_select(void *block_env, nodeset *ready_set)
{
	const arch_env_t *arch_env = block_env;
	ir_node *irn = NULL;
	int const_last = 0;

	/* assure that branches and constants are executed last */
	for (irn = nodeset_first(ready_set); irn; irn = nodeset_next(ready_set)) {
		if (! arch_irn_class_is(arch_env, irn, branch) && (const_last ? (! arch_irn_class_is(arch_env, irn, const)) : 1)) {
			nodeset_break(ready_set);
			return irn;
		}
	}

	/* assure that constants are executed before branches */
	if (const_last) {
		for (irn = nodeset_first(ready_set); irn; irn = nodeset_next(ready_set)) {
			if (! arch_irn_class_is(arch_env, irn, branch)) {
				nodeset_break(ready_set);
				return irn;
			}
		}
	}


	/* at last: schedule branches */
	irn = nodeset_first(ready_set);
	nodeset_break(ready_set);

	return irn;
}

static void *trivial_init_graph(const list_sched_selector_t *vtab, const arch_env_t *arch_env, ir_graph *irg)
{
	return (void *) arch_env;
}

static void *trivial_init_block(void *graph_env, ir_node *bl)
{
	return graph_env;
}

static INLINE int must_appear_in_schedule(const list_sched_selector_t *sel, void *block_env, const ir_node *irn)
{
	int res = -1;

	if(sel->to_appear_in_schedule)
		res = sel->to_appear_in_schedule(block_env, irn);

	return res >= 0 ? res : (to_appear_in_schedule(irn) || be_is_Keep(irn) || be_is_RegParams(irn));
}

static const list_sched_selector_t trivial_selector_struct = {
	trivial_init_graph,
	trivial_init_block,
	trivial_select,
	NULL,                /* to_appear_in_schedule */
	NULL,                /* exectime */
	NULL,                /* latency */
	NULL,                /* finish_block */
	NULL                 /* finish_graph */
};

const list_sched_selector_t *trivial_selector = &trivial_selector_struct;

typedef struct _usage_stats_t {
	ir_node *irn;
	struct _usage_stats_t *next;
	int max_hops;
	int uses_in_block;      /**< Number of uses inside the current block. */
	int already_consumed;   /**< Number of insns using this value already
							  scheduled. */
} usage_stats_t;

typedef struct {
	const list_sched_selector_t *vtab;
	const arch_env_t *arch_env;
} reg_pressure_main_env_t;

typedef struct {
	struct obstack obst;
	const reg_pressure_main_env_t *main_env;
	usage_stats_t *root;
	nodeset *already_scheduled;
} reg_pressure_selector_env_t;

static INLINE usage_stats_t *get_or_set_usage_stats(reg_pressure_selector_env_t *env, ir_node *irn)
{
	usage_stats_t *us = get_irn_link(irn);

	if(!us) {
		us                   = obstack_alloc(&env->obst, sizeof(us[0]));
		us->irn              = irn;
		us->already_consumed = 0;
		us->max_hops         = INT_MAX;
		us->next             = env->root;
		env->root            = us;
		set_irn_link(irn, us);
	}

	return us;
}

static INLINE usage_stats_t *get_usage_stats(ir_node *irn)
{
	usage_stats_t *us = get_irn_link(irn);
	assert(us && "This node must have usage stats");
	return us;
}

static int max_hops_walker(reg_pressure_selector_env_t *env, ir_node *irn, ir_node *curr_bl, int depth, unsigned visited_nr)
{
	ir_node *bl = get_nodes_block(irn);
	/*
	 * If the reached node is not in the block desired,
	 * return the value passed for this situation.
	 */
	if(get_nodes_block(irn) != bl)
		return block_dominates(bl, curr_bl) ? 0 : INT_MAX;

	/*
	 * If the node is in the current block but not
	 * yet scheduled, we keep on searching from that node.
	 */
	if(!nodeset_find(env->already_scheduled, irn)) {
		int i, n;
		int res = 0;
		for(i = 0, n = get_irn_arity(irn); i < n; ++i) {
			ir_node *operand = get_irn_n(irn, i);

			if(get_irn_visited(operand) < visited_nr) {
				int tmp;

				set_irn_visited(operand, visited_nr);
				tmp = max_hops_walker(env, operand, bl, depth + 1, visited_nr);
				res = MAX(tmp, res);
			}
		}

		return res;
	}

	/*
	 * If the node is in the current block and scheduled, return
	 * the depth which indicates the number of steps to the
	 * region of scheduled nodes.
	 */
	return depth;
}

static int compute_max_hops(reg_pressure_selector_env_t *env, ir_node *irn)
{
	ir_node *bl   = get_nodes_block(irn);
	ir_graph *irg = get_irn_irg(bl);
	int res       = 0;

	const ir_edge_t *edge;

	foreach_out_edge(irn, edge) {
		ir_node *user       = get_edge_src_irn(edge);
		unsigned visited_nr = get_irg_visited(irg) + 1;
		int max_hops;

		set_irg_visited(irg, visited_nr);
		max_hops = max_hops_walker(env, user, irn, 0, visited_nr);
		res      = MAX(res, max_hops);
	}

	return res;
}

static void *reg_pressure_graph_init(const list_sched_selector_t *vtab, const arch_env_t *arch_env, ir_graph *irg)
{
	reg_pressure_main_env_t *main_env = xmalloc(sizeof(main_env[0]));

	main_env->arch_env = arch_env;
	main_env->vtab     = vtab;
	irg_walk_graph(irg, firm_clear_link, NULL, NULL);

	return main_env;
}

static void *reg_pressure_block_init(void *graph_env, ir_node *bl)
{
	ir_node *irn;
	reg_pressure_selector_env_t *env  = xmalloc(sizeof(env[0]));

	obstack_init(&env->obst);
	env->already_scheduled = new_nodeset(32);
	env->root              = NULL;
	env->main_env          = graph_env;

	/*
	 * Collect usage statistics.
	 */
	sched_foreach(bl, irn) {
		if(must_appear_in_schedule(env->main_env->vtab, env, irn)) {
			int i, n;

			for(i = 0, n = get_irn_arity(irn); i < n; ++i) {
				//ir_node *op = get_irn_n(irn, i);
				if(must_appear_in_schedule(env->main_env->vtab, env, irn)) {
					usage_stats_t *us = get_or_set_usage_stats(env, irn);
#if 0 /* Liveness is not computed here! */
					if(is_live_end(bl, op))
						us->uses_in_block = 99999;
					else
#endif
						us->uses_in_block++;
				}
			}
		}
	}

	return env;
}

static void reg_pressure_block_free(void *block_env)
{
	reg_pressure_selector_env_t *env = block_env;
	usage_stats_t *us;

	for(us = env->root; us; us = us->next)
		set_irn_link(us->irn, NULL);

	obstack_free(&env->obst, NULL);
	del_nodeset(env->already_scheduled);
	free(env);
}

static int get_result_hops_sum(reg_pressure_selector_env_t *env, ir_node *irn)
{
	int res = 0;
	if(get_irn_mode(irn) == mode_T) {
		const ir_edge_t *edge;

		foreach_out_edge(irn, edge)
			res += get_result_hops_sum(env, get_edge_src_irn(edge));
	}

	else if(mode_is_data(get_irn_mode(irn)))
		res = compute_max_hops(env, irn);


	return res;
}

static INLINE int reg_pr_costs(reg_pressure_selector_env_t *env, ir_node *irn)
{
	int i, n;
	int sum = 0;

	for(i = 0, n = get_irn_arity(irn); i < n; ++i) {
		ir_node *op = get_irn_n(irn, i);

		if(must_appear_in_schedule(env->main_env->vtab, env, op))
			sum += compute_max_hops(env, op);
	}

	sum += get_result_hops_sum(env, irn);

	return sum;
}

static ir_node *reg_pressure_select(void *block_env, nodeset *ready_set)
{
	reg_pressure_selector_env_t *env = block_env;
	ir_node *irn, *res     = NULL;
	int curr_cost          = INT_MAX;

	assert(nodeset_count(ready_set) > 0);

	for (irn = nodeset_first(ready_set); irn; irn = nodeset_next(ready_set)) {
		/*
			Ignore branch instructions for the time being.
			They should only be scheduled if there is nothing else.
		*/
		if (! arch_irn_class_is(env->main_env->arch_env, irn, branch)) {
			int costs = reg_pr_costs(env, irn);
			if (costs <= curr_cost) {
				res       = irn;
				curr_cost = costs;
			}
		}
	}

	/*
		There was no result so we only saw a branch.
		Take it and finish.
	*/

	if(!res) {
		res = nodeset_first(ready_set);
		nodeset_break(ready_set);

		assert(res && "There must be a node scheduled.");
	}

	nodeset_insert(env->already_scheduled, res);
	return res;
}

/**
 * Environment for a block scheduler.
 */
typedef struct _block_sched_env_t {
	sched_irn_t *sched_info;                    /**< scheduling info per node, copied from the global scheduler object */
	sched_timestep_t curr_time;                 /**< current time of the scheduler */
	nodeset *cands;                             /**< the set of candidates */
	ir_node *block;                             /**< the current block */
	sched_env_t *sched_env;                     /**< the scheduler environment */
	const list_sched_selector_t *selector;
	void *selector_block_env;
	DEBUG_ONLY(firm_dbg_module_t *dbg;)
} block_sched_env_t;

/**
 * Returns non-zero if the node is already scheduled
 */
static INLINE int is_already_scheduled(block_sched_env_t *env, ir_node *n)
{
	int idx = get_irn_idx(n);

	assert(idx < ARR_LEN(env->sched_info));
	return env->sched_info[idx].already_sched;
}

/**
 * Mark a node as already scheduled
 */
static INLINE void mark_already_scheduled(block_sched_env_t *env, ir_node *n)
{
	int idx = get_irn_idx(n);

	assert(idx < ARR_LEN(env->sched_info));
	env->sched_info[idx].already_sched = 1;
}

/**
 * Returns non-zero if the node is a root node
 */
static INLINE unsigned is_root_node(block_sched_env_t *env, ir_node *n)
{
	int idx = get_irn_idx(n);

	assert(idx < ARR_LEN(env->sched_info));
	return env->sched_info[idx].is_root;
}

/**
 * Mark a node as roto node
 */
static INLINE void mark_root_node(block_sched_env_t *env, ir_node *n)
{
	int idx = get_irn_idx(n);

	assert(idx < ARR_LEN(env->sched_info));
	env->sched_info[idx].is_root = 1;
}

/**
 * Get the current delay.
 */
static sched_timestep_t get_irn_delay(block_sched_env_t *env, ir_node *n) {
	int idx = get_irn_idx(n);

	assert(idx < ARR_LEN(env->sched_info));
	return env->sched_info[idx].delay;
}

/**
 * Set the current delay.
 */
static void set_irn_delay(block_sched_env_t *env, ir_node *n, sched_timestep_t delay) {
	int idx = get_irn_idx(n);

	assert(idx < ARR_LEN(env->sched_info));
	env->sched_info[idx].delay = delay;
}

/**
 * Get the current etime.
 */
static sched_timestep_t get_irn_etime(block_sched_env_t *env, ir_node *n) {
	int idx = get_irn_idx(n);

	assert(idx < ARR_LEN(env->sched_info));
	return env->sched_info[idx].etime;
}

/**
 * Set the current etime.
 */
static void set_irn_etime(block_sched_env_t *env, ir_node *n, sched_timestep_t etime) {
	int idx = get_irn_idx(n);

	assert(idx < ARR_LEN(env->sched_info));
	env->sched_info[idx].etime = etime;
}

/**
 * returns the exec-time for node n.
 */
static sched_timestep_t exectime(sched_env_t *env, ir_node *n) {
  if (be_is_Keep(n) || is_Proj(n))
    return 0;
	if (env->selector->exectime)
		return env->selector->exectime(env->selector_env, n);
	return 1;
}

/**
 * Calculates the latency for between two ops
 */
static sched_timestep_t latency(sched_env_t *env, ir_node *pred, int pred_cycle, ir_node *curr, int curr_cycle) {
	/* a Keep hides a root */
  if (be_is_Keep(curr))
		return exectime(env, pred);

	/* Proj's are executed immediately */
	if (is_Proj(curr))
    return 0;

	/* predecessors Proj's must be skipped */
  if (is_Proj(pred))
    pred = get_Proj_pred(pred);

	if (env->selector->latency)
		return env->selector->latency(env->selector_env, pred, pred_cycle, curr, curr_cycle);
	return 1;
}

/**
 * Try to put a node in the ready set.
 * @param env   The block scheduler environment.
 * @param pred  The previous scheduled node.
 * @param irn   The node to make ready.
 * @return 1, if the node could be made ready, 0 else.
 */
static INLINE int make_ready(block_sched_env_t *env, ir_node *pred, ir_node *irn)
{
    int i, n;
		sched_timestep_t etime_p, etime;

    /* Blocks cannot be scheduled. */
    if (is_Block(irn))
        return 0;

    /*
     * Check, if the given ir node is in a different block as the
     * currently scheduled one. If that is so, don't make the node ready.
     */
    if (env->block != get_nodes_block(irn))
        return 0;

    for (i = 0, n = get_irn_arity(irn); i < n; ++i) {
        ir_node *op = get_irn_n(irn, i);

        /* if irn is an End we have keep-alives and op might be a block, skip that */
        if (is_Block(op)) {
          assert(get_irn_op(irn) == op_End);
          continue;
        }

        /* If the operand is local to the scheduled block and not yet
         * scheduled, this nodes cannot be made ready, so exit. */
        if (!is_already_scheduled(env, op) && get_nodes_block(op) == env->block)
            return 0;
    }

    nodeset_insert(env->cands, irn);

	/* calculate the etime of this node */
	etime = env->curr_time;
	if (pred) {
		etime_p  = get_irn_etime(env, pred);
		etime   += latency(env->sched_env, pred, 1, irn, 0);

		etime = etime_p > etime ? etime_p : etime;
	}

	set_irn_etime(env, irn, etime);

    DB((env->dbg, LEVEL_2, "\tmaking ready: %+F etime %u\n", irn, etime));

    return 1;
}

/**
 * Try, to make all users of a node ready.
 * In fact, a usage node can only be made ready, if all its operands
 * have already been scheduled yet. This is checked my make_ready().
 * @param env The block schedule environment.
 * @param irn The node, which usages (successors) are to be made ready.
 */
static INLINE void make_users_ready(block_sched_env_t *env, ir_node *irn)
{
	const ir_edge_t *edge;

	foreach_out_edge(irn, edge) {
		ir_node *user = edge->src;
		if(!is_Phi(user))
			make_ready(env, irn, user);
	}
}

/**
 * Append an instruction to a schedule.
 * @param env The block scheduling environment.
 * @param irn The node to add to the schedule.
 * @return    The given node.
 */
static ir_node *add_to_sched(block_sched_env_t *env, ir_node *irn)
{
    /* If the node consumes/produces data, it is appended to the schedule
     * list, otherwise, it is not put into the list */
    if(must_appear_in_schedule(env->selector, env->selector_block_env, irn)) {
        sched_info_t *info = get_irn_sched_info(irn);
        INIT_LIST_HEAD(&info->list);
        info->scheduled = 1;
        sched_add_before(env->block, irn);

        DBG((env->dbg, LEVEL_2, "\tadding %+F\n", irn));
    }

    /* Insert the node in the set of all already scheduled nodes. */
    mark_already_scheduled(env, irn);

    /* Remove the node from the ready set */
    if(nodeset_find(env->cands, irn))
        nodeset_remove(env->cands, irn);

    return irn;
}

/**
 * Add the proj nodes of a tuple-mode irn to the schedule immediately
 * after the tuple-moded irn. By pinning the projs after the irn, no
 * other nodes can create a new lifetime between the tuple-moded irn and
 * one of its projs. This should render a realistic image of a
 * tuple-moded irn, which in fact models a node which defines multiple
 * values.
 *
 * @param irn The tuple-moded irn.
 */
static void add_tuple_projs(block_sched_env_t *env, ir_node *irn)
{
	const ir_edge_t *edge;

	assert(get_irn_mode(irn) == mode_T && "Mode of node must be tuple");

	if(is_Bad(irn))
		return;

	foreach_out_edge(irn, edge) {
		ir_node *out = edge->src;

		assert(is_Proj(out) && "successor of a modeT node must be a proj");

		if (get_irn_mode(out) == mode_T)
			add_tuple_projs(env, out);
		else {
			add_to_sched(env, out);
			make_users_ready(env, out);
		}
	}
}

/**
 * Execute the heuristic function,
 */
static ir_node *select_node_heuristic(block_sched_env_t *be, nodeset *ns)
{
	ir_node *irn;

	for (irn = nodeset_first(ns); irn; irn = nodeset_next(ns)) {
		if (be_is_Keep(irn)) {
			nodeset_break(ns);
			return irn;
		}
	}

	return be->selector->select(be->selector_block_env, ns);
}

/**
 * Returns non-zero if root is a root in the block block.
 */
static int is_root(ir_node *root, ir_node *block) {
	const ir_edge_t *edge;

	foreach_out_edge(root, edge) {
		ir_node *succ = get_edge_src_irn(edge);

		if (is_Block(succ))
			continue;
		/* Phi nodes are always in "another block */
		if (is_Phi(succ))
			continue;
		if (get_nodes_block(succ) == block)
			return 0;
	}
	return 1;
}

/* we need a special mark */
static char _mark;
#define MARK	&_mark

static firm_dbg_module_t *xxxdbg;

/**
 * descent into a dag and create a pre-order list.
 */
static void descent(ir_node *root, ir_node *block, ir_node **list) {
	int i;

	if (! is_Phi(root)) {
		/* Phi nodes always leave the block */
		for (i = get_irn_arity(root) - 1; i >= 0; --i) {
			ir_node *pred = get_irn_n(root, i);

			DBG((xxxdbg, LEVEL_3, "   node %+F\n", pred));
			/* Blocks may happen as predecessors of End nodes */
			if (is_Block(pred))
				continue;

			/* already seen nodes are not marked */
			if (get_irn_link(pred) != MARK)
				continue;

			/* don't leave our block */
			if (get_nodes_block(pred) != block)
				continue;

			set_irn_link(pred, NULL);

			descent(pred, block, list);
		}
	}
	set_irn_link(root, *list);
	*list = root;
}

/**
 * Perform list scheduling on a block.
 *
 * Note, that the caller must compute a linked list of nodes in the block
 * using the link field before calling this function.
 *
 * Also the outs must have been computed.
 *
 * @param block The block node.
 * @param env Scheduling environment.
 */
static void list_sched_block(ir_node *block, void *env_ptr)
{
	sched_env_t *env                      = env_ptr;
	const list_sched_selector_t *selector = env->selector;
	ir_node *start_node                   = get_irg_start(get_irn_irg(block));
	sched_info_t *info                    = get_irn_sched_info(block);

	block_sched_env_t be;
	const ir_edge_t *edge;
	ir_node *irn;
	int j, m;

	ir_node *root = NULL, *preord = NULL;
	ir_node *curr;

	/* Initialize the block's list head that will hold the schedule. */
	INIT_LIST_HEAD(&info->list);

	/* Initialize the block scheduling environment */
	be.sched_info        = env->sched_info;
	be.block             = block;
	be.curr_time         = 0;
	be.cands             = new_nodeset(get_irn_n_edges(block));
	be.selector          = selector;
	be.sched_env         = env;
	FIRM_DBG_REGISTER(be.dbg, "firm.be.sched");
	FIRM_DBG_REGISTER(xxxdbg, "firm.be.sched");

	//	firm_dbg_set_mask(be.dbg, SET_LEVEL_3);

	if (selector->init_block)
		be.selector_block_env = selector->init_block(env->selector_env, block);

	DBG((be.dbg, LEVEL_1, "scheduling %+F\n", block));

	/* First step: Find the root set. */
	foreach_out_edge(block, edge) {
		ir_node *succ = get_edge_src_irn(edge);

		if (is_root(succ, block)) {
			mark_root_node(&be, succ);
			set_irn_link(succ, root);
			root = succ;
		}
		else
			set_irn_link(succ, MARK);
	}

	/* Second step: calculate the pre-order list. */
	preord = NULL;
	for (curr = root; curr; curr = irn) {
		irn = get_irn_link(curr);
		DBG((be.dbg, LEVEL_2, "   DAG root %+F\n", curr));
		descent(curr, block, &preord);
	}
	root = preord;

	/* Third step: calculate the Delay. Note that our
	* list is now in pre-order, starting at root
	*/
	for (curr = root; curr; curr = get_irn_link(curr)) {
		sched_timestep_t d;

		if (arch_irn_class_is(env->arch_env, curr, branch)) {
			/* assure, that branches can be executed last */
			d = 0;
		}
		else {
			if (is_root_node(&be, curr))
				d = exectime(env, curr);
			else {
				d = 0;
				foreach_out_edge(curr, edge) {
					ir_node *n = get_edge_src_irn(edge);

					if (get_nodes_block(n) == block) {
						sched_timestep_t ld;

						ld = latency(env, curr, 1, n, 0) + get_irn_delay(&be, n);
						d = ld > d ? ld : d;
					}
				}
			}
		}
		set_irn_delay(&be, curr, d);
		DB((be.dbg, LEVEL_2, "\t%+F delay %u\n", curr, d));

		/* set the etime of all nodes to 0 */
		set_irn_etime(&be, curr, 0);
	}


	/* Then one can add all nodes are ready to the set. */
	foreach_out_edge(block, edge) {
		ir_node *irn = get_edge_src_irn(edge);

		/* Skip the end node because of keepalive edges. */
		if (get_irn_opcode(irn) == iro_End)
			continue;

		if (is_Phi(irn)) {
			/* Phi functions are scheduled immediately, since they only transfer
			* data flow from the predecessors to this block. */

			/* Increase the time step. */
			be.curr_time += get_irn_etime(&be, irn);
			add_to_sched(&be, irn);
			make_users_ready(&be, irn);
		}
		else if (irn == start_node) {
			/* The start block will be scheduled as the first node */
			be.curr_time += get_irn_etime(&be, irn);

			add_to_sched(&be, irn);
			add_tuple_projs(&be, irn);
		}
		else {
			/* Other nodes must have all operands in other blocks to be made
			* ready */
			int ready = 1;

			/* Check, if the operands of a node are not local to this block */
			for (j = 0, m = get_irn_arity(irn); j < m; ++j) {
				ir_node *operand = get_irn_n(irn, j);

				if (get_nodes_block(operand) == block) {
					ready = 0;
					break;
				}
			}

			/* Make the node ready, if all operands live in a foreign block */
			if (ready) {
				DBG((be.dbg, LEVEL_2, "\timmediately ready: %+F\n", irn));
				make_ready(&be, NULL, irn);
			}
		}
	}

	while (nodeset_count(be.cands) > 0) {
		nodeset *mcands;                            /**< the set of candidates with maximum delay time */
		nodeset *ecands;                            /**< the set of nodes in mcands whose etime <= curr_time  */
		sched_timestep_t max_delay = 0;

		/* collect statistics about amount of ready nodes */
		be_do_stat_sched_ready(block, be.cands);

		/* calculate the max delay of all candidates */
		foreach_nodeset(be.cands, irn) {
			sched_timestep_t d = get_irn_delay(&be, irn);

			max_delay = d > max_delay ? d : max_delay;
		}
		mcands = new_nodeset(8);
		ecands = new_nodeset(8);

		/* calculate mcands and ecands */
		foreach_nodeset(be.cands, irn) {
			if (be_is_Keep(irn)) {
				nodeset_break(be.cands);
				break;
			}
			if (get_irn_delay(&be, irn) == max_delay) {
				nodeset_insert(mcands, irn);
				if (get_irn_etime(&be, irn) <= be.curr_time)
					nodeset_insert(ecands, irn);
			}
		}

		if (irn) {
			/* Keeps must be immediately scheduled */
		}
		else {
			DB((be.dbg, LEVEL_2, "\tbe.curr_time = %u\n", be.curr_time));

			/* select a node to be scheduled and check if it was ready */
			if (nodeset_count(mcands) == 1) {
				DB((be.dbg, LEVEL_3, "\tmcand = 1, max_delay = %u\n", max_delay));
				irn = nodeset_first(mcands);
			}
			else {
				int cnt = nodeset_count(ecands);
				if (cnt == 1) {
					irn = nodeset_first(ecands);

					if (arch_irn_class_is(env->arch_env, irn, branch)) {
						/* BEWARE: don't select a JUMP if others are still possible */
						goto force_mcands;
					}
					DB((be.dbg, LEVEL_3, "\tecand = 1, max_delay = %u\n", max_delay));
				}
				else if (cnt > 1) {
					DB((be.dbg, LEVEL_3, "\tecand = %d, max_delay = %u\n", cnt, max_delay));
					irn = select_node_heuristic(&be, ecands);
				}
				else {
force_mcands:
					DB((be.dbg, LEVEL_3, "\tmcand = %d\n", nodeset_count(mcands)));
					irn = select_node_heuristic(&be, mcands);
				}
			}
		}
		del_nodeset(mcands);
		del_nodeset(ecands);

		DB((be.dbg, LEVEL_2, "\tpicked node %+F\n", irn));

		/* Increase the time step. */
		be.curr_time += exectime(env, irn);

		/* Add the node to the schedule. */
		add_to_sched(&be, irn);

		if (get_irn_mode(irn) == mode_T)
			add_tuple_projs(&be, irn);
		else
			make_users_ready(&be, irn);

		/* remove the scheduled node from the ready list. */
		if (nodeset_find(be.cands, irn))
			nodeset_remove(be.cands, irn);
	}

	if (selector->finish_block)
		selector->finish_block(be.selector_block_env);

	del_nodeset(be.cands);
}

static const list_sched_selector_t reg_pressure_selector_struct = {
	reg_pressure_graph_init,
	reg_pressure_block_init,
	reg_pressure_select,
	NULL,                    /* to_appear_in_schedule */
	NULL,                    /* exectime */
	NULL,                    /* latency */
	reg_pressure_block_free,
	free
};

const list_sched_selector_t *reg_pressure_selector = &reg_pressure_selector_struct;

/* List schedule a graph. */
void list_sched(const be_irg_t *birg, int enable_mris)
{
	const arch_env_t *arch_env = birg->main_env->arch_env;
	ir_graph *irg              = birg->irg;

	int num_nodes;
	sched_env_t env;
	mris_env_t *mris;

	/* Assure, that the out edges are computed */
	edges_assure(irg);

	if(enable_mris)
		mris = be_sched_mris_preprocess(birg);

	num_nodes = get_irg_last_idx(irg);

	memset(&env, 0, sizeof(env));
	env.selector   = arch_env->isa->impl->get_list_sched_selector(arch_env->isa);
	env.arch_env   = arch_env;
	env.irg        = irg;
	env.sched_info = NEW_ARR_F(sched_irn_t, num_nodes);

	memset(env.sched_info, 0, num_nodes * sizeof(*env.sched_info));

	if (env.selector->init_graph)
		env.selector_env = env.selector->init_graph(env.selector, arch_env, irg);

	/* Schedule each single block. */
	irg_block_walk_graph(irg, list_sched_block, NULL, &env);

	if (env.selector->finish_graph)
		env.selector->finish_graph(env.selector_env);

	if(enable_mris)
		be_sched_mris_free(mris);

	DEL_ARR_F(env.sched_info);
}
