package game

import "core:fmt"
import "core:math"
import "core:mem"

int2    :: [2]int
float2  :: [2]f32

HGrid :: struct($T : typeid) {
    cells           : map[int2][dynamic]^T,
    pos_ptr_offset  : u16,
    cell_size       : f32
}

init_cell_data :: proc(using self : ^HGrid($T), size : f32) {
    cell_size = size
    cells = make(map[int2][dynamic]^T)
}

delete_cell_data :: proc(using self : ^HGrid($T)) {
    for k, v in cells do delete(v)
    clear_map(&cells)
}

clear_cell_data :: proc(using self : ^HGrid($T)) {
    for key, &data in cells {
        if len(data) == 0 {
            delete(data)
            delete_key(&cells, key)
        }
    }
    for key in cells do clear_dynamic_array(&cells[key])
}

get_cell_coord :: proc(using self : ^HGrid($T), pos : float2) -> int2 {
    return {int(pos.x / cell_size), int(pos.y / cell_size)}
}

insert_cell_data :: proc(using self : ^HGrid($T), cell_coord : int2, data : ^T) {
    values, ok := cells[cell_coord]

    if !ok {
        values = make([dynamic]^T)
        cells[cell_coord] = values
    }

    append(&values, data)
    cells[cell_coord] = values
}

get_cell_data :: proc(using self : ^HGrid($T), cell_coord : int2) -> (data : []^T, ok : bool) {
    result, success := cells[cell_coord]
    return result[:], success
}