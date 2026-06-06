package main

import "core:c"
import "core:math/rand"
import "core:time"
import "vendor:raylib"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600
TITLE :: "Title"

GAP_SIZE :: 150
PIPE_WIDTH :: 80
PIPE_SPEED :: 150
PIPE_SPAWN_INTERVAL :: 2.0

GRAVITY :: 800
FLAP_VEL :: -350
BIRD_SIZE :: 30

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

Bird :: struct {
	pos_x: f32,
	pos_y: f32,
	vel_y: f32,
	size:  c.int,
	color: raylib.Color,
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

create_bird :: proc() -> Bird {
	return Bird {
		pos_x = f32(WINDOW_WIDTH) / 4,
		pos_y = f32(WINDOW_HEIGHT) / 2,
		vel_y = 0,
		size = BIRD_SIZE,
		color = raylib.YELLOW,
	}
}

draw_bird :: proc(bird: Bird) {
	raylib.DrawRectangle(i32(bird.pos_x), i32(bird.pos_y), bird.size, bird.size, bird.color)
}

update_bird :: proc(bird: ^Bird, dt: f32) {
	bird.vel_y += GRAVITY * dt
	bird.pos_y += bird.vel_y * dt
}

bird_rect :: proc(bird: Bird) -> raylib.Rectangle {
	return raylib.Rectangle {
		x = bird.pos_x,
		y = bird.pos_y,
		width = f32(bird.size),
		height = f32(bird.size),
	}
}

pipe_rect :: proc(pipe: Pipe) -> raylib.Rectangle {
	return raylib.Rectangle {
		x = pipe.pos_x,
		y = pipe.pos_y,
		width = f32(pipe.width),
		height = f32(pipe.height),
	}
}

check_collision :: proc(bird: Bird, pipes: [dynamic]PipePair) -> bool {
	br := bird_rect(bird)

	if bird.pos_y < 0 {
		return true
	}
	if bird.pos_y + BIRD_SIZE >= WINDOW_HEIGHT {
		return true
	}

	for pair in pipes {
		if raylib.CheckCollisionRecs(br, pipe_rect(pair.top)) {
			return true
		}
		if raylib.CheckCollisionRecs(br, pipe_rect(pair.bottom)) {
			return true
		}
	}
	return false
}

GameState :: enum {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER,
}

MenuType :: enum {
	MAIN,
	PAUSE,
	GAME_OVER,
}

Menu :: struct {
	options:  []cstring,
	selected: int,
	type:     MenuType,
	visible:  bool,
}

MAIN_MENU_OPTIONS := []cstring{"Start Game", "Quit"}
PAUSE_MENU_OPTIONS := []cstring{"Continue", "Restart", "Main Menu", "Quit"}
GAME_OVER_MENU_OPTIONS := []cstring{"Restart", "Main Menu", "Quit"}

create_menu :: proc(type: MenuType, selected: int = 0) -> Menu {
	options: []cstring
	switch type {
	case .MAIN:
		options = MAIN_MENU_OPTIONS
	case .PAUSE:
		options = PAUSE_MENU_OPTIONS
	case .GAME_OVER:
		options = GAME_OVER_MENU_OPTIONS
	}
	return Menu{options, selected, type, true}
}

draw_menu :: proc(menu: Menu, final_score: int = 0) {
	overlay_color := raylib.Fade(raylib.BLACK, 0.5)
	raylib.DrawRectangle(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT, overlay_color)

	title: cstring
	switch menu.type {
	case .MAIN:
		title = "FLAP"
	case .PAUSE:
		title = "PAUSED"
	case .GAME_OVER:
		title = "GAME OVER"
	}

	title_y := i32(WINDOW_HEIGHT / 4)
	raylib.DrawText(
		title,
		WINDOW_WIDTH / 2 - raylib.MeasureText(title, 50) / 2,
		title_y,
		50,
		raylib.WHITE,
	)

	if menu.type == .GAME_OVER {
		score_text := raylib.TextFormat("Final Score: %d", final_score)
		raylib.DrawText(
			score_text,
			WINDOW_WIDTH / 2 - raylib.MeasureText(score_text, 40) / 2,
			title_y + 70,
			40,
			raylib.GOLD,
		)
	}

	start_y := WINDOW_HEIGHT / 2
	for option, i in menu.options {
		color := raylib.YELLOW if i == menu.selected else raylib.WHITE
		x := WINDOW_WIDTH / 2 - raylib.MeasureText(option, 30) / 2
		y := start_y + (i * 50)
		raylib.DrawText(option, x, i32(y), 30, color)
	}
}

handle_menu_input :: proc(
	menu: ^Menu,
	game_state: ^GameState,
	bird: ^Bird,
	pipes: ^[dynamic]PipePair,
	score: ^int,
	spawn_timer: ^f32,
) -> bool {
	if raylib.IsKeyPressed(raylib.KeyboardKey.UP) && menu.selected > 0 {
		menu.selected -= 1
	}
	if raylib.IsKeyPressed(raylib.KeyboardKey.DOWN) && menu.selected < len(menu.options) - 1 {
		menu.selected += 1
	}

	if raylib.IsKeyPressed(raylib.KeyboardKey.ENTER) {
		switch menu.type {
		case .MAIN:
			switch menu.selected {
			case 0:
				game_state^ = .PLAYING
				menu.visible = false
				return true
			case 1:
				raylib.CloseWindow()
			}
		case .PAUSE:
			switch menu.selected {
			case 0:
				game_state^ = .PLAYING
				menu.visible = false
				return true
			case 1:
				game_state^ = .PLAYING
				bird^ = create_bird()
				clear(pipes)
				score^ = 0
				spawn_timer^ = 0
				menu.visible = false
				return true
			case 2:
				game_state^ = .MENU
				bird^ = create_bird()
				clear(pipes)
				score^ = 0
				spawn_timer^ = 0
				menu.visible = false
				return true
			case 3:
				raylib.CloseWindow()
			}
		case .GAME_OVER:
			switch menu.selected {
			case 0:
				game_state^ = .PLAYING
				bird^ = create_bird()
				clear(pipes)
				score^ = 0
				spawn_timer^ = 0
				menu.visible = false
				return true
			case 1:
				game_state^ = .MENU
				bird^ = create_bird()
				clear(pipes)
				score^ = 0
				spawn_timer^ = 0
				menu.visible = false
				return true
			case 2:
				raylib.CloseWindow()
			}
		}
	}
	return false
}

main :: proc() {
	raylib.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, TITLE)
	defer raylib.CloseWindow()

	raylib.SetExitKey(raylib.KeyboardKey.KEY_NULL)

	pipes: [dynamic]PipePair
	defer delete(pipes)

	bird := create_bird()
	spawn_timer: f32 = 0
	score: int = 0

	game_state: GameState = .MENU
	current_menu := create_menu(.MAIN)
	final_score := 0

	raylib.SetTargetFPS(60)

	for !raylib.WindowShouldClose() {
		dt := raylib.GetFrameTime()

		if game_state == .PLAYING {
			if raylib.IsKeyPressed(raylib.KeyboardKey.SPACE) {
				bird.vel_y = FLAP_VEL
			}
			if raylib.IsKeyPressed(raylib.KeyboardKey.ESCAPE) {
				game_state = .PAUSED
				current_menu = create_menu(.PAUSE)
			}
		} else {
			handle_menu_input(&current_menu, &game_state, &bird, &pipes, &score, &spawn_timer)
		}

		if game_state == .PLAYING {
			update_bird(&bird, dt)

			if check_collision(bird, pipes) {
				game_state = .GAME_OVER
				final_score = score
				current_menu = create_menu(.GAME_OVER)
			}

			spawn_timer += dt
			if spawn_timer >= PIPE_SPAWN_INTERVAL {
				append(&pipes, create_pipe_pair())
				spawn_timer = 0
			}

			for i := len(pipes) - 1; i >= 0; i -= 1 {
				update_pipe(&pipes[i].top, dt)
				update_pipe(&pipes[i].bottom, dt)

				if pipes[i].top.pos_x + f32(PIPE_WIDTH) < 0 {
					unordered_remove(&pipes, i)
				}

				if !pipes[i].scored && pipes[i].top.pos_x + f32(PIPE_WIDTH) < bird.pos_x {
					score += 1
					pipes[i].scored = true
				}
			}
		}

		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)

		if game_state != .MENU {
			for pair in pipes {
				draw_pipe(pair.top)
				draw_pipe(pair.bottom)
			}
			draw_bird(bird)
		}

		switch game_state {
		case .PLAYING:
			raylib.DrawText(raylib.TextFormat("Score: %d", score), 20, 20, 30, raylib.WHITE)
		case .MENU, .PAUSED, .GAME_OVER:
			final_score_to_show := final_score if game_state == .GAME_OVER else score
			draw_menu(current_menu, final_score_to_show)
		}

		raylib.EndDrawing()
	}
}
