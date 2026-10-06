class_name DungeonItemPool
extends Resource
## A set of items and the rooms that draw from it.

## Room names that get items from this pool.
@export var rooms: PackedStringArray = ["item"]
@export var entries: Array[DungeonItemEntry] = []
@export_range(1, 5) var items_per_room := 1
## When off, an item isn't handed out again until every other item in the
## pool has been.
@export var allow_repeats := false
## Added to the spawn point, in pixels. Items spawn at the middle of a floor
## cell's surface; the default lifts them to hover above it.
@export var offset := Vector2(0, -18)
## Sell the items for each entry's price instead of giving them away.
@export var for_sale := false
## Leave out items that pools earlier in the table have already placed in
## this dungeon, so a shop only stocks what the player won't find for free.
@export var skip_placed := false
