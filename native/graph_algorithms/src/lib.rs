use petgraph::algo;
use petgraph::graph::{DiGraph, NodeIndex};
use petgraph::visit::EdgeRef;
use std::collections::HashMap;

mod atoms {
    rustler::atoms! { ok, error }
}

// ── Graph construction helpers ────────────────────────────────────────────────

fn build_graph(
    node_ids: &[String],
    edges: &[(String, String)],
) -> (DiGraph<String, ()>, HashMap<String, NodeIndex>) {
    let mut graph = DiGraph::new();
    let mut id_to_idx: HashMap<String, NodeIndex> = HashMap::new();

    for id in node_ids {
        let idx = graph.add_node(id.clone());
        id_to_idx.insert(id.clone(), idx);
    }

    for (src, tgt) in edges {
        if let (Some(&si), Some(&ti)) = (id_to_idx.get(src), id_to_idx.get(tgt)) {
            graph.add_edge(si, ti, ());
        }
    }

    (graph, id_to_idx)
}

/// For each node (in topo order), compute its longest distance from any source.
/// Nodes at the same depth can execute in parallel.
fn compute_depths(
    graph: &DiGraph<String, ()>,
    topo_order: &[NodeIndex],
) -> HashMap<NodeIndex, usize> {
    let mut depth: HashMap<NodeIndex, usize> = HashMap::new();

    for &idx in topo_order {
        let max_pred_depth = graph
            .edges_directed(idx, petgraph::Direction::Incoming)
            .map(|e| depth.get(&e.source()).copied().unwrap_or(0) + 1)
            .max()
            .unwrap_or(0);
        depth.insert(idx, max_pred_depth);
    }

    depth
}

// ── NIFs ─────────────────────────────────────────────────────────────────────

/// Proof-of-life NIF kept from Slice 0.
#[rustler::nif]
fn hello() -> rustler::Atom {
    atoms::ok()
}

/// Validates that the graph is a DAG (no cycles).
///
/// Returns `{:ok, topo_order}` where `topo_order` is a list of node IDs
/// in topological execution order, or `{:error, "cycle_detected"}`.
#[rustler::nif(schedule = "DirtyCpu")]
fn validate_dag(
    node_ids: Vec<String>,
    edges: Vec<(String, String)>,
) -> Result<Vec<String>, String> {
    let (graph, _) = build_graph(&node_ids, &edges);

    algo::toposort(&graph, None)
        .map(|order| order.iter().map(|&idx| graph[idx].clone()).collect())
        .map_err(|_| "cycle_detected".to_string())
}

/// Groups nodes by their execution depth (longest path from any source).
///
/// Returns `{:ok, [[node_id]]}` — a list of lists where each inner list
/// contains nodes that can execute in parallel at that depth level.
/// Returns `{:error, "cycle_detected"}` if the graph is not a DAG.
#[rustler::nif(schedule = "DirtyCpu")]
fn find_parallel_groups(
    node_ids: Vec<String>,
    edges: Vec<(String, String)>,
) -> Result<Vec<Vec<String>>, String> {
    let (graph, _) = build_graph(&node_ids, &edges);

    let topo_order = algo::toposort(&graph, None)
        .map_err(|_| "cycle_detected".to_string())?;

    let depth_map = compute_depths(&graph, &topo_order);
    let max_depth = depth_map.values().copied().max().unwrap_or(0);

    let mut groups: Vec<Vec<String>> = vec![vec![]; max_depth + 1];
    for &idx in &topo_order {
        let d = depth_map[&idx];
        groups[d].push(graph[idx].clone());
    }

    Ok(groups)
}

/// Returns the critical path through the DAG — the longest chain of nodes
/// from any source to any sink, as an ordered list of node IDs.
///
/// Returns `{:error, "cycle_detected"}` if the graph is not a DAG.
#[rustler::nif(schedule = "DirtyCpu")]
fn find_critical_path(
    node_ids: Vec<String>,
    edges: Vec<(String, String)>,
) -> Result<Vec<String>, String> {
    let (graph, _) = build_graph(&node_ids, &edges);

    let topo_order = algo::toposort(&graph, None)
        .map_err(|_| "cycle_detected".to_string())?;

    if topo_order.is_empty() {
        return Ok(vec![]);
    }

    let depth_map = compute_depths(&graph, &topo_order);

    // Start from the node with maximum depth (the deepest sink)
    let &last = topo_order
        .iter()
        .max_by_key(|&&idx| depth_map[&idx])
        .unwrap();

    // Backtrack through predecessors, always taking the deepest one
    let mut path = vec![graph[last].clone()];
    let mut current = last;

    loop {
        let preds: Vec<NodeIndex> = graph
            .edges_directed(current, petgraph::Direction::Incoming)
            .map(|e| e.source())
            .collect();

        if preds.is_empty() {
            break;
        }

        let best_pred = *preds.iter().max_by_key(|&&idx| depth_map[&idx]).unwrap();
        path.push(graph[best_pred].clone());
        current = best_pred;
    }

    path.reverse();
    Ok(path)
}

rustler::init!(
    "Elixir.Fitzyo.GraphAlgorithms",
    [hello, validate_dag, find_parallel_groups, find_critical_path]
);
