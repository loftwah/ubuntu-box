import pygame
import random
import os

# Initialize Pygame
pygame.init()

# Screen settings
WIDTH, HEIGHT = 800, 600
BLOCK_SIZE = 20
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Snake: Nibbles Nostalgia")

# Colors
BLACK = (0, 0, 0)
GREEN = (0, 255, 0)
RED = (255, 0, 0)
WHITE = (255, 255, 255)
YELLOW = (255, 255, 0)

# Font
font = pygame.font.SysFont("monospace", 48)
small_font = pygame.font.SysFont("monospace", 36)

# High score file
HIGH_SCORE_FILE = "high_scores.txt"
if not os.path.exists(HIGH_SCORE_FILE):
    with open(HIGH_SCORE_FILE, "w") as f:
        f.write("0\n0\n0")  # Top 3 scores default to 0

def load_high_scores():
    with open(HIGH_SCORE_FILE, "r") as f:
        return [int(line.strip()) for line in f.readlines()][:3]

def save_high_scores(scores):
    with open(HIGH_SCORE_FILE, "w") as f:
        for score in sorted(scores, reverse=True)[:3]:
            f.write(f"{score}\n")

# Game states
MENU, PLAYING, GAME_OVER = 0, 1, 2
state = MENU

# Snake properties
snake = [(WIDTH // 2, HEIGHT // 2)]
snake_dir = (BLOCK_SIZE, 0)
snake_speed = 15

# Food properties
food = (random.randint(0, (WIDTH - BLOCK_SIZE) // BLOCK_SIZE) * BLOCK_SIZE,
        random.randint(0, (HEIGHT - BLOCK_SIZE) // BLOCK_SIZE) * BLOCK_SIZE)

# Game variables
clock = pygame.time.Clock()
score = 0
session_high_score = 0
high_scores = load_high_scores()

def reset_game():
    global snake, snake_dir, food, score
    snake = [(WIDTH // 2, HEIGHT // 2)]
    snake_dir = (BLOCK_SIZE, 0)
    food = (random.randint(0, (WIDTH - BLOCK_SIZE) // BLOCK_SIZE) * BLOCK_SIZE,
            random.randint(0, (HEIGHT - BLOCK_SIZE) // BLOCK_SIZE) * BLOCK_SIZE)
    score = 0

def move_snake():
    global snake, food, score, state, session_high_score, high_scores
    head_x, head_y = snake[0]
    dir_x, dir_y = snake_dir
    new_head = ((head_x + dir_x) % WIDTH, (head_y + dir_y) % HEIGHT)

    if new_head in snake:
        session_high_score = max(session_high_score, score)
        high_scores.append(score)
        save_high_scores(high_scores)
        state = GAME_OVER
        return

    snake.insert(0, new_head)
    if new_head == food:
        score += 1
        food = (random.randint(0, (WIDTH - BLOCK_SIZE) // BLOCK_SIZE) * BLOCK_SIZE,
                random.randint(0, (HEIGHT - BLOCK_SIZE) // BLOCK_SIZE) * BLOCK_SIZE)
    else:
        snake.pop()

# Menu text
title = font.render("NIBBLES.PY", True, YELLOW)
start_text = small_font.render("Press S to Start", True, WHITE)
quit_text = small_font.render("Press Q to Quit", True, WHITE)

# Game loop
running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        if event.type == pygame.KEYDOWN:
            if state == MENU:
                if event.key == pygame.K_s:
                    reset_game()
                    state = PLAYING
                elif event.key == pygame.K_q:
                    running = False
            elif state == PLAYING:
                if event.key == pygame.K_UP and snake_dir != (0, BLOCK_SIZE):
                    snake_dir = (0, -BLOCK_SIZE)
                elif event.key == pygame.K_DOWN and snake_dir != (0, -BLOCK_SIZE):
                    snake_dir = (0, BLOCK_SIZE)
                elif event.key == pygame.K_LEFT and snake_dir != (BLOCK_SIZE, 0):
                    snake_dir = (-BLOCK_SIZE, 0)
                elif event.key == pygame.K_RIGHT and snake_dir != (-BLOCK_SIZE, 0):
                    snake_dir = (BLOCK_SIZE, 0)
            elif state == GAME_OVER:
                if event.key == pygame.K_r:
                    reset_game()
                    state = PLAYING
                elif event.key == pygame.K_m:
                    state = MENU

    # Update
    if state == PLAYING:
        move_snake()

    # Drawing
    screen.fill(BLACK)

    if state == MENU:
        # Draw menu
        screen.blit(title, title.get_rect(center=(WIDTH // 2, HEIGHT // 4)))
        screen.blit(start_text, start_text.get_rect(center=(WIDTH // 2, HEIGHT // 2)))
        screen.blit(quit_text, quit_text.get_rect(center=(WIDTH // 2, HEIGHT * 3 // 4)))
        # Draw high scores as plain numbers
        for i, hs in enumerate(high_scores):
            hs_text = small_font.render(f"{hs}", True, WHITE)
            screen.blit(hs_text, (10, 10 + i * 40))

    elif state == PLAYING:
        # Draw snake
        for segment in snake:
            pygame.draw.rect(screen, GREEN, (segment[0], segment[1], BLOCK_SIZE, BLOCK_SIZE))
        # Draw food
        pygame.draw.rect(screen, RED, (food[0], food[1], BLOCK_SIZE, BLOCK_SIZE))
        # Draw score and session high score
        score_text = small_font.render(f"Score: {score}", True, WHITE)
        hs_text = small_font.render(f"Session High: {session_high_score}", True, WHITE)
        screen.blit(score_text, (10, 10))
        screen.blit(hs_text, (10, 50))

    elif state == GAME_OVER:
        # Draw game over screen
        game_over_text = font.render("GAME OVER", True, RED)
        score_text = small_font.render(f"Score: {score}", True, WHITE)
        restart_text = small_font.render("Press R to Restart", True, WHITE)
        menu_text = small_font.render("Press M for Menu", True, WHITE)
        screen.blit(game_over_text, game_over_text.get_rect(center=(WIDTH // 2, HEIGHT // 3)))
        screen.blit(score_text, score_text.get_rect(center=(WIDTH // 2, HEIGHT // 2)))
        screen.blit(restart_text, restart_text.get_rect(center=(WIDTH // 2, HEIGHT * 2 // 3)))
        screen.blit(menu_text, menu_text.get_rect(center=(WIDTH // 2, HEIGHT * 3 // 4)))

    pygame.display.flip()
    clock.tick(snake_speed if state == PLAYING else 60)

pygame.quit()