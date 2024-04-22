// HGrid, short for hash grid, is a data structure used to speed up spatial queries like "find all enemies close to a projectile"
// It does this by breaking up 2D space into a grid of cells, where each cell is a bucket for arbitrary data.

// In this game, each bucket stores enemies (or rather, their indices) 
// This lets us quickly find any enemies near an input position without having to check *every* enemy.
// Using the hash grid, we only need to check enemies in the same cell as the input position.
// We use this to speed up collision checks between projectiles and enemies, 
// as well as in the enemy movement behaviour which uses a boid flocking simulation

// HGrids are meant to be cleared and rebuilt each frame.

// Note: This is probably a super naive implementation! It just maps cell coordinates to a list of arbitrary data stored in the cell.

package game

import "core:fmt"
import "core:math"
import "core:mem"

int2    :: [2]int
float2  :: [2]f32

// HGrids can store arbitrary data, so the struct has a "parameterized type."
// This just means that when you declare an HGrid, you have to provide the type of data you want it to store.
// For example the following grid stores integers in each cell:
//      grid : HGrid(int)
//
// You can get the data stored in a specific cell via these two utility functions
//      cell_coord                      := get_cell_coord(grid, rl.GetMousePosition())
//      cell_data_under_mouse, exists   := get_cell_data(grid, cell_coord)
HGrid :: struct($T : typeid) {
    cells           : map[int2][dynamic]T,
    pos_ptr_offset  : u16,
    cell_size       : f32,
}

// Allocates data used by the grid and initializes the cell size
init_cell_data :: proc(grid : ^HGrid($T), cell_size : f32){
    grid.cell_size = cell_size
    grid.cells     = make(map[int2][dynamic]T)
}

// Frees data allocated by the grid
delete_cell_data :: proc(using grid : HGrid($T)) {
    for cell_coord, &data in cells do delete(data)
    delete(cells)
}

// Clears all data stored in the grid cells
clear_cell_data :: proc(using grid : ^HGrid($T)) {
    for cell_coord, &data in cells {
        if len(data) == 0 {
            delete(data)
            delete_key(&cells, cell_coord)
        }
        clear(&data)
    }
}

// Gets the coordinates of the grid cell that a position is within
get_cell_coord :: #force_inline proc(using grid : HGrid($T), pos : float2) -> int2 {
    return {int(pos.x / cell_size), int(pos.y / cell_size)}
}

// Inserts data into a cell
insert_cell_data :: proc(using grid : ^HGrid($T), cell_coord : int2, data : T, allocator := context.allocator) {
    // Get the current values stored in the cell, and whether the cell even exists yet
    values, ok := cells[cell_coord]
    
    // If the cell doesn't have any data, give it a new dynamic array
    if !ok {
        values = make([dynamic]T, allocator)
        cells[cell_coord] = values
    }

    // Add the new data to the list of data stored in the cell
    append(&values, data)
    cells[cell_coord] = values
}

// Returns the data stored in a grid cell
get_cell_data :: #force_inline proc(using grid : HGrid($T), cell_coord : int2) -> (data : []T, ok : bool) {
    result, success := cells[cell_coord]
    return result[:], success
}