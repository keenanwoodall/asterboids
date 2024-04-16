package game

import rl "vendor:raylib"

@(private="file")
Rect :: rl.Rectangle

@(private="file")
Vector2 :: rl.Vector2

screen_rect :: proc() -> Rect {
    return {0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()) }
}

centered_rect :: proc {
    screen_centered_rect,
    rect_centered_rect,
    rect_centered_rect_label,
}

screen_centered_rect :: proc(width : f32, height : f32) -> Rect {
    return {
        f32(rl.GetScreenWidth()) / 2 - width / 2,
        f32(rl.GetScreenHeight()) / 2 - height / 2,
        width,
        height
    }
}

rect_centered_rect :: proc(rect : Rect, width : f32, height : f32) -> Rect {
    return {
        rect.x + rect.width / 2 - width / 2,
        rect.y + rect.height / 2 - height / 2,
        width,
        height
    }
}

rect_centered_rect_label :: proc(rect : Rect, height : f32, label : cstring) -> Rect {
    label_width := get_label_width(label)
    return {
        rect.x + rect.width / 2 - label_width / 2,
        rect.y + rect.height / 2 - height / 2 + 5,
        label_width,
        height
    }
}

padded_rect :: proc(using rect : Rect, left_pad : f32 = 0, right_pad : f32 = 0, top_pad : f32 = 0, bottom_pad : f32 = 0) -> Rect {
    return { rect.x + left_pad, rect.y + top_pad, rect.width - (right_pad + left_pad), rect.height - (bottom_pad + top_pad) }
}

uniform_padded_rect :: proc(using rect : Rect, pad : f32) -> Rect {
    return { rect.x + pad, rect.y + pad, rect.width - pad * 2, rect.height - pad * 2 }
}

centered_label_rect :: proc(rect : Rect, label : cstring, font_size : i32 = 10) -> Rect {
    label_width := get_label_width(label, font_size)
    return { 
        rect.x - (label_width - rect.width) / 2,
        rect.y,
        rect.width,
        rect.height
    }
}

top_padded_rect :: proc(using rect : Rect, pad : f32) -> Rect {
    rect := rect
    rect.height -= pad
    rect.y += pad
    return rect
}

h_padded_rect :: proc(using rect : Rect, pad : f32) -> Rect {
    return { rect.x + pad, rect.y, rect.width - pad * 2, rect.height }
}

v_padded_rect :: proc(using rect : Rect, pad : f32) -> Rect {
    return { rect.x, rect.y + pad, rect.width, rect.height - pad * 2 }
}

uniform_pad_rects :: proc(pad : f32, rects : ^[$N]Rect) {
    for &rect in rects do rect = uniform_padded_rect(rect, pad)
}

h_pad_rects :: proc(pad : f32, rects : ^[$N]Rect) {
    for &rect in rects do rect = h_padded_rect(rect, pad)
}

v_pad_rects :: proc(pad : f32, rects : ^[$N]Rect) {
    for &rect in rects do rect = v_padded_rect(rect, pad)
}

top_pad_rects :: proc(pad : f32, rects : ^[$N]Rect) {
    for &rect in rects do rect = top_padded_rect(rect, pad)
}

h_subdivide_rect ::proc(rect : Rect, $N : int) -> [N]Rect where N > 0 {
    width := rect.width / f32(N)
    rects : [N]Rect
    for i := 1; i <= N; i += 1 {
        rects[i - 1] = {
            rect.x + width * f32(i - 1),
            rect.y,
            width,
            rect.height
        }
    }

    return rects
}

v_subdivide_rect ::proc(rect : Rect, $N : int) -> [N]Rect where N > 0 {
    height := rect.height / f32(N)
    rects : [N]Rect
    for i := 1; i <= N; i += 1 {
        rects[i - 1] = {
            rect.x,
            rect.y + height * f32(i - 1),
            rect.width,
            height
        }
    }

    return rects
}

h_split_rect ::proc(rect : Rect, percent : f32 = 0.5, bias : f32 = 0) -> [2]Rect {
    left_width := rect.width * percent - bias
    right_width := rect.width - left_width
    return [2]Rect {
        {rect.x, rect.y, left_width, rect.height},
        {rect.x + left_width, rect.y, right_width, rect.height},
    }
}

v_split_rect ::proc(rect : Rect, percent : f32 = 0.5, bias : f32 = 0) -> [2]Rect {
    top_height := rect.height * percent - bias
    bottom_height := rect.height - top_height
    return [2]Rect {
        {rect.x, rect.y, rect.width, top_height},
        {rect.x, rect.y + top_height, rect.width, bottom_height},
    }
}

@(private="file")
get_label_width :: proc(label : cstring, font_size : i32 = 10) -> f32 {
    return f32(rl.MeasureText(label, font_size))
}