package game

import "core:fmt"
import "core:math"
import "core:mem"

int2    :: [2]int
float2  :: [2]f32

HGrid :: struct($T : typeid) {
    cells           : map[int2][dynamic]T,
    pos_ptr_offset  : u16,
    cell_size       : f32,
}

init_cell_data :: proc(grid : ^HGrid($T), cell_size : f32){
    grid.cell_size = cell_size
    grid.cells     = make(map[int2][dynamic]T)
}

delete_cell_data :: proc(using grid : HGrid($T)) {
    for cell_coord, &data in cells do delete(data)
    delete(cells)
}

clear_cell_data :: proc(using grid : ^HGrid($T)) {
    for cell_coord, &data in cells {
        if len(data) == 0 {
            delete(data)
            delete_key(&cells, cell_coord)
        }
        clear(&data)
    }
}

get_cell_coord :: #force_inline proc(using grid : HGrid($T), pos : float2) -> int2 {
    return {int(pos.x / cell_size), int(pos.y / cell_size)}
}

insert_cell_data :: proc(using grid : ^HGrid($T), cell_coord : int2, data : T, allocator := context.allocator) {
    values, ok := cells[cell_coord]

    if !ok {
        values = make([dynamic]T)
        cells[cell_coord] = values
    }

    append(&values, data)
    cells[cell_coord] = values
}

get_cell_data :: #force_inline proc(using grid : HGrid($T), cell_coord : int2) -> (data : []T, ok : bool) {
    result, success := cells[cell_coord]
    return result[:], success
}