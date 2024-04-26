package game

ActionStack :: struct($Value, $Context : typeid) {
    actions : [dynamic]proc(value : ^Value, ctx : ^Context),
}

init_action_stack :: proc(stack : ^ActionStack($V, $C)) {
    stack.actions = make([dynamic]proc(value : ^V, ctx : ^C))
}

unload_action_stack :: proc(stack : ^ActionStack($V, $C)) {
    delete(stack.actions)
}

add_action :: proc(stack : ^ActionStack($V, $C), action : proc(value : ^V, ctx : ^C)) {
    append(&stack.actions, action)
}

execute_action_stack :: proc(stack : ActionStack($V, $C), value : ^V, ctx : ^C) {
    for action in stack.actions {
        action(value, ctx)
    }
}