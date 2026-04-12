% 3D Lagrangian Particle Tracking Simulation - Quadrotor Wake
% Simulates individual air particles falling, tilting inward, and merging.

function simulate_wake_particles()
    fprintf('\n=== Starting 3D Particle Wake Simulation ===\n');
    
    %% 1. Simulation Parameters
    num_particles = 250;       % Total number of particles to simulate
    dt = 0.01;                  % Time step
    z_floor = -20;              % How far down the simulation goes (normalized z/R)
    
    % Aerodynamic Parameters
    V_z_base = 2.5;             % Base downward velocity
    tilt_deg = 40.5;             % Inward tilt of the rotors
    turbulence = 0.15;          % Amount of random jitter (simulates entrainment)
    
    %% 2. Drone Geometry (Paper-Inspired Model)
    D = 2.0;                    % Normalized by R, so D = 2
    front_sep = 1.35 * D;
    back_sep = 1.17 * D;
    long_sep = 1.25 * D;
    dz_fb = 0.18 * D;
    
    % Rotor Centers [x, y, z]
    rotors = [
         front_sep/2,  long_sep/2,  dz_fb/2;  % Front-Right
        -front_sep/2,  long_sep/2,  dz_fb/2;  % Front-Left
         back_sep/2,  -long_sep/2, -dz_fb/2;  % Back-Right
        -back_sep/2,  -long_sep/2, -dz_fb/2   % Back-Left
    ];
    rotor_radius = D / 2;
    
    %% 3. Initialize Particles
    % Preallocate particle state arrays
    P_x = zeros(num_particles, 1);
    P_y = zeros(num_particles, 1);
    P_z = zeros(num_particles, 1);
    P_color = zeros(num_particles, 1); % Color code by originating rotor
    
    % Randomly distribute particles among the 4 rotors to start
    for i = 1:num_particles
        [P_x(i), P_y(i), P_z(i), P_color(i)] = spawn_particle(rotors, rotor_radius, z_floor);
        % Randomize starting Z so they aren't all at the top initially
        P_z(i) = P_z(i) + rand() * z_floor; 
    end
    
    %% 4. Setup Plot
    fig = figure('Color', [0.05 0.05 0.08], 'Position', [100 100 1000 800], 'Name', 'Wake Particle Sim');
    ax = axes('Parent', fig, 'Color', [0.05 0.05 0.08]);
    hold on; grid on;
    
    % Plot drone markers
    plot3(rotors(:,1), rotors(:,2), rotors(:,3), 'wo', 'MarkerFaceColor', 'w', 'MarkerSize', 8);
    plot3(rotors([1 2 4 3 1],1), rotors([1 2 4 3 1],2), rotors([1 2 4 3 1],3), 'w--', 'LineWidth', 1.5);
    
    % Initialize scatter plot for particles
    % Using a custom colormap to distinguish the 4 rotor streams
    cmap = [0.9 0.3 0.3;  0.3 0.9 0.3;  0.3 0.6 0.9;  0.9 0.7 0.2];
    colormap(ax, cmap);
    scatter_h = scatter3(P_x, P_y, P_z, 10, P_color, 'filled', 'MarkerFaceAlpha', 0.6);
    
    % Styling
    axis equal;
    xlim([-10 10]); ylim([-10 10]); zlim([z_floor 2]);
    xlabel('x/R'); ylabel('y/R'); zlabel('z/R (Depth)');
    title('Lagrangian Particle Tracking: Wake Merging', 'Color', 'w', 'FontSize', 14);
    ax.XColor = [0.7 0.7 0.7]; ax.YColor = [0.7 0.7 0.7]; ax.ZColor = [0.7 0.7 0.7];
    ax.GridColor = [0.3 0.3 0.3];
    view([35 25]);
    
    %% 5. Animation Loop
    fprintf('Running simulation... Close the window to stop.\n');
    inward_factor = tand(tilt_deg);
    
    while ishandle(fig)
        % 1. Calculate Downward Movement (with slight random variation per particle)
        V_z = -V_z_base * (1 + 0.2 * randn(num_particles, 1));
        
        % 2. Calculate Inward Tilt (Vector pointing to center axis x=0, y=0)
        % Normalize the x,y position to get a direction vector
        dist_to_center = sqrt(P_x.^2 + P_y.^2) + eps; 
        dir_x = -P_x ./ dist_to_center;
        dir_y = -P_y ./ dist_to_center;
        
        % Apply inward velocity based on the 4.5 degree tilt
        V_x = dir_x .* abs(V_z) * inward_factor;
        V_y = dir_y .* abs(V_z) * inward_factor;
        
        % 3. Add Turbulence (Random walk / jitter)
        % Turbulence increases as they fall deeper (simulating messy far-field)
        turb_scale = turbulence * (1 + abs(P_z) / 5); 
        V_x = V_x + randn(num_particles, 1) .* turb_scale;
        V_y = V_y + randn(num_particles, 1) .* turb_scale;
        
        % 4. Update Positions
        P_x = P_x + V_x * dt;
        P_y = P_y + V_y * dt;
        P_z = P_z + V_z * dt;
        
        % 5. Recycle Particles that hit the floor
        dead_particles = find(P_z < z_floor);
        for k = 1:length(dead_particles)
            idx = dead_particles(k);
            [P_x(idx), P_y(idx), P_z(idx), P_color(idx)] = spawn_particle(rotors, rotor_radius, 0);
        end
        
        % 6. Update Plot efficiently
        set(scatter_h, 'XData', P_x, 'YData', P_y, 'ZData', P_z, 'CData', P_color);
        drawnow; 
    end
    fprintf('Simulation stopped.\n');
end

%% Helper Function: Spawn a particle at a random rotor
function [x, y, z, c] = spawn_particle(rotors, radius, z_offset)
    % Pick a random rotor (1 to 4)
    r_idx = randi(4);
    
    % Random point in a circle using polar coordinates
    ang = rand() * 2 * pi;
    r = radius * sqrt(rand()); 
    
    % Assign coordinates
    x = rotors(r_idx, 1) + r * cos(ang);
    y = rotors(r_idx, 2) + r * sin(ang);
    z = rotors(r_idx, 3) + z_offset; % Start at rotor height
    c = r_idx; % Color tag
end