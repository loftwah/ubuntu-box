import pygame
import math
import random

# Initialize Pygame
pygame.init()
width, height = 800, 600
screen = pygame.display.set_mode((width, height))
pygame.display.set_caption("Loftwah in Rotating Hexagon")
clock = pygame.time.Clock()

# Colors
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)

# Hexagon properties
center = (width // 2, height // 2)
hex_size = 200  # Distance from center to vertex
hex_angle = 0   # Rotation angle in degrees
rotation_speed = 2  # Degrees per frame

# Font and text setup (smaller size)
font = pygame.font.SysFont("Arial", 36, bold=True)  # Smaller text
text = "Loftwah"
base_text = font.render(text, True, WHITE)
text_rect = base_text.get_rect()

# Text animation variables
pos_x, pos_y = width // 2, height // 2  # Start at center
vel_x, vel_y = random.uniform(-3, 3), random.uniform(-3, 3)  # Slower velocity for control
angle = 0  # Rotation angle
color_shift = 0  # For color cycling

# Calculate hexagon vertices
def get_hexagon_vertices(center, size, angle):
    vertices = []
    for i in range(6):
        theta = math.radians(angle + 60 * i)
        x = center[0] + size * math.cos(theta)
        y = center[1] + size * math.sin(theta)
        vertices.append((x, y))
    return vertices

# Reflect velocity off a wall
def reflect_velocity(pos, vel, p1, p2):
    line_vec = (p2[0] - p1[0], p2[1] - p1[1])
    normal = (-line_vec[1], line_vec[0])
    norm_len = math.sqrt(normal[0]**2 + normal[1]**2)
    normal = (normal[0]/norm_len, normal[1]/norm_len)
    dot = vel[0] * normal[0] + vel[1] * normal[1]
    return [vel[0] - 2 * dot * normal[0], vel[1] - 2 * dot * normal[1]]

# Get rainbow color
def get_rainbow_color(shift):
    r = int(math.sin(shift) * 127 + 128)
    g = int(math.sin(shift + 2) * 127 + 128)
    b = int(math.sin(shift + 4) * 127 + 128)
    return (r, g, b)

# Main loop
running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

    # Clear screen
    screen.fill(BLACK)

    # Update hexagon rotation
    hex_angle += rotation_speed
    vertices = get_hexagon_vertices(center, hex_size, hex_angle)

    # Update text position
    pos_x += vel_x
    pos_y += vel_y

    # Collision detection with hexagon walls
    rotated_text = pygame.transform.rotate(base_text, angle)
    text_rect = rotated_text.get_rect(center=(pos_x, pos_y))
    for i in range(6):
        p1 = vertices[i]
        p2 = vertices[(i + 1) % 6]
        v1 = (pos_x - p1[0], pos_y - p1[1])
        wall = (p2[0] - p1[0], p2[1] - p1[1])
        wall_len = math.sqrt(wall[0]**2 + wall[1]**2)
        wall_unit = (wall[0]/wall_len, wall[1]/wall_len)
        proj_len = v1[0] * wall_unit[0] + v1[1] * wall_unit[1]
        if 0 <= proj_len <= wall_len:
            perp_vec = (v1[0] - proj_len * wall_unit[0], v1[1] - proj_len * wall_unit[1])
            dist = math.sqrt(perp_vec[0]**2 + perp_vec[1]**2)
            if dist <= max(text_rect.width, text_rect.height) / 2:
                vel_x, vel_y = reflect_velocity([pos_x, pos_y], [vel_x, vel_y], p1, p2)

    # Update rotation and color
    angle += 5  # Spin fast
    if angle >= 360:
        angle -= 360
    color_shift += 0.1
    color = get_rainbow_color(color_shift)

    # Create and draw rotated text
    rotated_text = pygame.transform.rotate(base_text, angle)
    text_rect = rotated_text.get_rect(center=(pos_x, pos_y))
    colored_text = font.render(text, True, color)
    rotated_colored = pygame.transform.rotate(colored_text, angle)
    screen.blit(rotated_colored, text_rect)

    # Draw hexagon
    pygame.draw.polygon(screen, WHITE, vertices, 2)

    # Update display
    pygame.display.flip()
    clock.tick(60)

pygame.quit()