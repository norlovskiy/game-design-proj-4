	
# Rooms

start room: one side entrance
goal room: one side entrance
item lock room: one top entrance (way in), one side entrance (locked, needs the key)
vertical lock room: two upper side entrances, two lower side entrances
item key room: one side entrance
random item room: one side entrance
shop room: two side entrances
boss room: one side entrance

rooms can be mirrored

# Progression

shop -> boss (grants double jump) -> vertical lock upper side B -> item key -> item lock -> goal

single jump: 3 tiles up, under 3 tiles across

# Connection rules

the map is a tree: exactly one route between any two rooms, so locks can't be bypassed

start room leads into a branching corridor network

vertical lock room, item lock room and shop are placed in random order
	each hangs off the corridor network, or behind a pass-through door of another
	the vertical lock is entered through a lower entrance

boss room MUST be behind the shop's far entrance

item key room MUST be behind vertical lock room upper side B
	upper side B needs double jump (higher door, 3 tile gap from the ledge)

goal room MUST be directly behind item lock room's locked side entrance

shop, boss and vertical lock can't be behind the item lock room

vertical lock room spare entrances:
	other lower entrance: carries on the tree, or takes a branch
	upper side A: optional item room, reachable with a single jump
	unused entrances are sealed

# Corridors

halls: 3 open tiles tall, 6-16 tiles long
	one solid tile above each doorway, so the opening is 2 tall like a room's door
shafts: 4 open tiles wide, platforms 3 tiles apart on alternating sides
	a door each side at the top and bottom
corridors branch only at shafts, and never cross

# Branches

2-4 random item rooms and 2-3 dead ends per map

# Not in v1

loops and shortcuts
double jump gated optional branches
simulated traversal check
