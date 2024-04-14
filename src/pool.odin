package game

Pool :: struct($N : int, $T : typeid) {
    count       : int,
    instances   : []T
}

pool_init :: proc(using pool : ^Pool($N, $T)) {
    instances = make([]T, N)
    count = 0
}

pool_delete :: proc(using pool : ^Pool($N, $T)) {
    delete(instances)
    count = 0
}

pool_add :: proc(using pool : ^Pool($N, $T), item : T) -> (added : bool) {
    if count == N {
        return false
    }
    instances[count] = item
    count += 1
    return true
}

pool_release :: proc(using pool : ^Pool($N, $T), index : int) {
    instances[index] = instances[count - 1]
    count -= 1
}

pool_clear :: proc(using pool : ^Pool($N, $T), index : int) {
    count = 0
}