# The flake.lock graph, one problem per line (root V1); gate/lock-graph.sh
# runs it. One nixpkgs node, and every input named nixpkgs that is locked
# rather than followed points at it.
.nodes as $nodes
| [$nodes | to_entries[]
   | select(.value.locked.owner? == "NixOS" and .value.locked.repo? == "nixpkgs")
   | .key] as $nixpkgs
| (if ($nixpkgs | index("nixpkgs")) != null then "nixpkgs" else $nixpkgs[0] end) as $canonical
| (if ($nixpkgs | length) != 1
   then "\($nixpkgs | length) nixpkgs nodes, want 1: \($nixpkgs | join(", "))"
   else empty end),
  ($nodes | to_entries[]
   | select(.value.inputs.nixpkgs? | type == "string")
   | select(.value.inputs.nixpkgs != $canonical)
   | "\(.key) locks its own nixpkgs (node \(.value.inputs.nixpkgs)); make it follow")
