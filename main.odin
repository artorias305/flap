package main

import "core:c"
import "core:math/rand"
import "core:time"
import "vendor:raylib"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600
TITLE :: "Flap"

GAP_SIZE :: 150
PIPE_WIDTH :: 80
PIPE_SPEED :: 150
PIPE_SPAWN_INTERVAL :: 2.0

Pipe :: struct {
	width:  c.int,
	height: c.int,
	pos_x:  f32,
	pos_y:  f32,
	color:  raylib.Color,
}

PipePair :: struct {
	top:    Pipe,
	bottom: Pipe,
	scored: bool,
}

draw_pipe :: proc(pipe: Pipe) {
	raylib.DrawRectangle(i32(pipe.pos_x), i32(pipe.pos_y), pipe.width, pipe.height, pipe.color)
}

create_pipe :: proc(
	width: c.int = 100,
	height: c.int = 100,
	pos_x: f32 = 0,
	pos_y: f32 = 0,
	color: raylib.Color = raylib.RAYWHITE,
) -> Pipe {
	return Pipe{width, height, pos_x, pos_y, color}
}

create_pipe_pair :: proc() -> PipePair {
	min_gap_y := GAP_SIZE
	max_gap_y := WINDOW_HEIGHT - GAP_SIZE
	gap_center_y := rand.int31_max(i32(max_gap_y - min_gap_y + 1)) + i32(min_gap_y)

	top_height := gap_center_y - GAP_SIZE / 2
	bottom_y := gap_center_y + GAP_SIZE / 2
	bottom_height := WINDOW_HEIGHT - bottom_y

	top := create_pipe(
		width = PIPE_WIDTH,
		height = top_height,
		pos_x = f32(WINDOW_WIDTH),
		pos_y = 0,
		color = raylib.GREEN,
	)

	bottom := create_pipe(
		width = PIPE_WIDTH,
		height = bottom_height,
		pos_x = f32(WINDOW_WIDTH),
		pos_y = f32(bottom_y),
		color = raylib.GREEN,
	)

	return PipePair{top, bottom, false}
}

update_pipe :: proc(pipe: ^Pipe, dt: f32) {
	pipe.pos_x -= PIPE_SPEED * dt
}

main :: proc() {
	raylib.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, TITLE)
	defer raylib.CloseWindow()

	pipes: [dynamic]PipePair
	defer delete(pipes)

	spawn_timer: f32 = 0

	raylib.SetTargetFPS(60)

	for !raylib.WindowShouldClose() {
		dt := raylib.GetFrameTime()

		spawn_timer += dt
		if spawn_timer >= PIPE_SPAWN_INTERVAL {
			spawn_timer = 0
			append(&pipes, create_pipe_pair())
		}

		for i := len(pipes) - 1; i >= 0; i-=1 {
			update_pipe(&pipes[i].top, dt)
			update_pipe(&pipes[i].bottom, dt)

			if pipes[i].top.pos_x + f32(PIPE_WIDTH) < 0 {
				unordered_remove(&pipes, i)
			}
		}

		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)

		for pair in pipes {
			draw_pipe(pair.top)
			draw_pipe(pair.bottom)
		}

		raylib.EndDrawing()
	}
}
