// This is a simple data type used to manage a pool of elements.
// Not very different from a dynamic array with a high capacity.

package game

// Pool is a parametric struct. 
// When declaring it you must define the max number of elements, as well as the element type (what's stored in the pool)
// For example the following pool stores up to 1000 vectors
//      pool : HGrid(1000, rl.Vector2)
Pool :: struct($N : int, $T : typeid) {
    count       : int,
    instances   : []T
}

init_pool :: proc(using pool : ^Pool($N, $T)) {
    instances = make([]T, N)
    count = 0
}

delete_pool :: proc(using pool : ^Pool($N, $T)) {
    delete(instances)
    count = 0
}

add_pool :: proc(using pool : ^Pool($N, $T), item : T) -> (added : bool) {
    if count == N {
        return false
    }
    instances[count] = item
    count += 1
    return true
}

release_pool :: proc(using pool : ^Pool($N, $T), index : int) {
    instances[index] = instances[count - 1]
    count -= 1
}

clear_pool :: proc(using pool : ^Pool($N, $T), index : int) {
    count = 0
}