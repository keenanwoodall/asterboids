// A simple structure that lets you stack functions that modify an input value.
package game

ActionStack :: struct($Value, $Context : typeid) {
    // A list of functions which are passed a value and context reference.
    // The Value is the thing the action can modify. The Context is used to inform the action.
    // For this game, the context is almost always the Game struct
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