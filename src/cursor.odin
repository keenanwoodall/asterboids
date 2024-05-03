package game

import rl "vendor:raylib"

hide_cursor :: proc() {
    if rl.IsWindowFocused() {
        if rl.IsCursorOnScreen() {
            rl.HideCursor()
        }
        else if rl.IsCursorHidden() {
            rl.ShowCursor()
        }
    }
}