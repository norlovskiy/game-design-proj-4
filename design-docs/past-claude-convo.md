Yes, the overall shape is sound and well scoped for a demo. Hand-made function rooms with Spelunky-style connective tissue is basically a smaller Dead Cells, and ending with simulated traversal is the right instinct. There's one structural issue to fix, plus a few smaller refinements.

## The main issue: corridors can bypass your lock

The lock room only works if it's the only way from the key side of the level to the goal side. If you place rooms first and then fill empty space with corridors that "connect one room to another," nothing stops a corridor from running from the start area straight to the goal room, going around the lock. Your simulation would catch it, but you'd be rerolling constantly, and the generator wouldn't be producing the structure you want; it would be producing random structures and hoping.

The fix is to decide connectivity before placement. Build a small graph first, for example start → shop → key room → back toward start → lock room → goal, or start branching to the key room and to the lock room, with the goal only past the lock. Then place rooms on the grid, and route corridors only along the edges of that graph. Corridors become implementations of edges you chose, not free-form fill. Mark grid cells as claimed when a corridor uses them, so two corridors can't merge and create a shortcut you didn't intend.

## Placement should respect the graph

Purely random placement makes routing harder, since the lock room might end up far from both the key and the goal while the start sits right next to the goal. Bias placement by topology: put the goal on the far side of the lock room relative to the start. Since it's a vertical lock, put the goal above it (or below, depending on the gate), so the gate is physically between the two regions. Start somewhere, place the next room in graph order at a random position within some distance range of its predecessor, and repeat. This keeps corridors short and reduces failed routes.

## Corridor routing

Treat corridor generation as pathfinding between door sockets. Run A* (or a random-walk biased toward the target, which looks more organic) over free grid cells from one room's exit to the next room's entrance. Then, like Spelunky, tag each corridor cell by which sides it opens to and pick a chunk template matching that tag. Give corridor chunks traversal tags too, so a corridor chunk that needs a wall jump doesn't appear on the pre-key side of the level by accident, which would make an unintended second lock.

Leftover empty cells can just be solid wall, or optionally hold short dead-end branches with an item, which gives the level some texture beyond a single line.

## Simulation: check both directions

Simulate traversal positively (with the key, can you reach everything, including the goal?) and negatively (without the key, is the goal unreachable, and is the key reachable?). The negative check is the one people forget, and it's exactly what catches the bypass problem. With a BFS over (cell, abilities held), both checks are just two runs with different starting ability sets.

## Suggested order

Put together: generate the room graph, place function rooms on the grid in graph order with spatial bias, route corridors along graph edges with A* and claim cells, choose corridor chunks by exit tags and traversal constraints, populate enemies and items, then run the positive and negative traversal checks and reroll on failure. For a demo, rerolling is a perfectly fine failure strategy; you only need repair logic if failures turn out to be common.