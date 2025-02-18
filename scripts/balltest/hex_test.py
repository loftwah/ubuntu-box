import pygame
import math

# Initialize Pygame
pygame.init()
width, height = 800, 600
screen = pygame.display.set_mode((width, height))
pygame.display.set_caption("Ball in Rotating Hexagon")
clock = pygame.time.Clock()

# Colors
WHITE = (255, 255, 255)
RED = (255, 0, 0)
BLACK = (0, 0, 0)

# Hexagon properties
center = (width // 2, height // 2)
hex_size = 200  # Distance from center to vertex
hex_angle = 0   # Rotation angle in degrees
rotation_speed = 2  # Degrees per frame

# Ball properties
ball_radius = 10
ball_pos = [width // 2, height // 2 - 100]  # Start near center
ball_vel = [3, 2]  # Initial velocity

# Calculate hexagon vertices
def get_hexagon_vertices(center, size, angle):
    vertices = []
    for i in range(6):
        theta = math.radians(angle + 60 * i)
        x = center[0] + size * math.cos(theta)
        y = center[1] + size * math.sin(theta)
        vertices.append((x, y))
    return vertices

# Check collision with line segment and reflect velocity
def reflect_velocity(pos, vel, p1, p2):
    # Line vector
    line_vec = (p2[0] - p1[0], p2[1] - p1[1])
    # Normal vector (perpendicular)
    normal = (-line_vec[1], line_vec[0])
    norm_len = math.sqrt(normal[0]**2 + normal[1]**2)
    normal = (normal[0]/norm_len, normal[1]/norm_len)
    
    # Dot product of velocity and normal
    dot = vel[0] * normal[0] + vel[1] * normal[1]
    # Reflect velocity
    new_vel = [vel[0] - 2 * dot * normal[0], vel[1] - 2 * dot * normal[1]]
    
    # Check if ball is too close to wall, push it out
    d = (pos[0] - p1[0]) * normal[0] + (pos[1] - p1[1]) * normal[1]
    if abs(d) < ball_radius:
        pos[0] += normal[0] * (ball_radius - abs(d))
        pos[1] += normal[1] * (ball_radius - abs(d))
    return new_vel

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

    # Update ball position
    ball_pos[0] += ball_vel[0]
    ball_pos[1] += ball_vel[1]

    # Collision detection with hexagon walls
    for i in range(6):
        p1 = vertices[i]
        p2 = vertices[(i + 1) % 6]
        # Vector from p1 to ball
        v1 = (ball_pos[0] - p1[0], ball_pos[1] - p1[1])
        # Vector of the wall
        wall = (p2[0] - p1[0], p2[1] - p1[1])
        wall_len = math.sqrt(wall[0]**2 + wall[1]**2)
        wall_unit = (wall[0]/wall_len, wall[1]/wall_len)
        
        # Project v1 onto wall
        proj_len = v1[0] * wall_unit[0] + v1[1] * wall_unit[1]
        if 0 <= proj_len <= wall_len:
            # Perpendicular distance to wall
            perp_vec = (v1[0] - proj_len * wall_unit[0], v1[1] - proj_len * wall_unit[1])
            dist = math.sqrt(perp_vec[0]**2 + perp_vec[1]**2)
            if dist <= ball_radius:
                ball_vel = reflect_velocity(ball_pos, ball_vel, p1, p2)

    # Draw hexagon
    pygame.draw.polygon(screen, WHITE, vertices, 2)
    # Draw ball
    pygame.draw.circle(screen, RED, (int(ball_pos[0]), int(ball_pos[1])), ball_radius)

    # Update display
    pygame.display.flip()
    clock.tick(60)

pygame.quit()