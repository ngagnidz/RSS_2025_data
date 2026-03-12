% 3D Wake Visualization - Continuous donut/vase shape
% Each depth has a ring whose radius = where peak velocity occurs
close all; clear all; clc

%% Load PIV data from static folder
%% These 3 files are used to match measured velocities at specific points with their coordinates. 
static_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'static');
load(fullfile(static_dir, 'x_piv.mat')); %% Horizontal coordinate of measurement point 
load(fullfile(static_dir, 'z_piv.mat')); %% The depth of measurement point 
load(fullfile(static_dir, 'u_piv.mat')); %% Downward velocity of each measurment poiunt 


%% Extract unique 1D grid vector
r = unique(x_piv(:))'; %% Unique x values (1D) 
z = unique(z_piv(:)); %% Unique z values (1D)

% Interpolate u_piv onto clean r/z grid
[R_orig, Z_orig] = meshgrid(r, z); %XZ plane
u2d = griddata(x_piv(:), z_piv(:), u_piv(:), R_orig, Z_orig, 'linear'); %Fills in velocity values on the clean grid 
u2d(isnan(u2d)) = 0; % Fill in NaN velocity values with 0. 

n_z = length(z); %Number of depth levels
n_r = length(r); %Number of radial positions 

%% For each depth, find the radius at which peak velocity occurs


% Cut the grid in half and filter out the right side only because the wake is symmetric. 
r_pos_mask = r >= 0;
r_pos = r(r_pos_mask);
u2d_pos = u2d(:, r_pos_mask);

wake_radius = zeros(n_z, 1);
peak_velocity = zeros(n_z, 1);

% For each depth level zi 
for zi = 1:n_z

    % Take one horizontal row which represents velocity across all x positions at this depth. 
    profile = u2d_pos(zi, :);

    % Find the faster air speed in that cross section 
    peak_velocity(zi) = max(profile);

    % Find the outermost x position where velocity is still at least 50% of that peak
    idx = find(profile >= 0.5 * peak_velocity(zi), 1, 'last');
    if isempty(idx)
        wake_radius(zi) = 0;
    else
        wake_radius(zi) = r_pos(idx);
    end
end

% Smooth wake_radius to ensure a continuous surface
wake_radius = smoothdata(wake_radius, 'movmean', 20);

%% Build continuous donut surface by revolving the wake boundary
n_angles = 150;
theta = linspace(0, 2*pi, n_angles);

% Outer surface (wake boundary)
[TH, ZI] = meshgrid(theta, 1:n_z);
R_surf = repmat(wake_radius, 1, n_angles);
Z_surf = repmat(z, 1, n_angles);
X_surf = R_surf .* cos(TH);
Y_surf = R_surf .* sin(TH);
C_surf = repmat(peak_velocity, 1, n_angles);  % color by peak velocity at each depth

%% Also build inner filled surface (solid tube showing velocity core)
n_angles2 = 150;
theta2 = linspace(0, 2*pi, n_angles2);
[TH2, RI2] = meshgrid(theta2, 1:n_r);
Z_tube = zeros(n_r, n_angles2);
X_tube = repmat(r', 1, n_angles2) .* cos(TH2);
Y_tube = repmat(r', 1, n_angles2) .* sin(TH2);





%% Plot
fig = figure('Color', [0.05 0.05 0.08], 'Position', [100 80 1200 850]);
ax = axes;
ax.Color = [0.05 0.05 0.08];
ax.GridColor = [0.25 0.25 0.3];
ax.GridAlpha = 0.4;
ax.XColor = [0.75 0.75 0.75];
ax.YColor = [0.75 0.75 0.75];
ax.ZColor = [0.75 0.75 0.75];
hold on; grid on;

% Draw continuous donut surface colored by velocity
s1 = surf(X_surf, Y_surf, Z_surf, C_surf, 'EdgeColor', 'none', 'FaceAlpha', 0.92);

% Cap the top with a filled disc at z(1)
theta_cap = linspace(0, 2*pi, 150);
r_cap = linspace(0, wake_radius(1), 35);
[TH_cap, R_cap] = meshgrid(theta_cap, r_cap);
X_cap = R_cap .* cos(TH_cap);
Y_cap = R_cap .* sin(TH_cap);
Z_cap = ones(size(X_cap)) * z(1);
u_cap = interp1(r, u2d(1,:), R_cap, 'linear', 0);
surf(X_cap, Y_cap, Z_cap, u_cap, 'EdgeColor', 'none', 'FaceAlpha', 0.95);

% Inner core slices — consolidated: every 20 steps instead of 5 (4x fewer objects = much faster)
slice_indices = 1:20:n_z;
for zi = slice_indices
    u_ring = u2d(zi, :);
    x_ring = repmat(r', 1, n_angles2) .* cos(TH2);
    y_ring = repmat(r', 1, n_angles2) .* sin(TH2);
    z_ring = ones(n_r, n_angles2) * z(zi);
    u_ring_2d = repmat(u_ring', 1, n_angles2);
    surf(x_ring, y_ring, z_ring, u_ring_2d, 'EdgeColor', 'none', 'FaceAlpha', 0.10);
end

colormap(turbo);
clim([0 1]);
cb = colorbar('Color', [0.85 0.85 0.85]);
cb.Label.String = '$\bar{u}/U_i$  (normalized downwash velocity)';
cb.Label.Interpreter = 'latex';
cb.Label.FontSize = 14;
cb.Label.Rotation = 270;
cb.Label.Position(1) = 3.5;

% Drone marker at top
plot3(0, 0, z(1)-0.3, 'w^', 'MarkerSize', 18, 'MarkerFaceColor', [0.9 0.9 1.0], 'LineWidth', 1.5);
text(0.2, 0, z(1)-0.5, 'Drone', 'Color', 'white', 'FontSize', 13, 'FontWeight', 'bold');

% Near-field ring annotation
theta_nf = linspace(0, 2*pi, 120);
r_nf = interp1(z, wake_radius, 6.6, 'linear');
plot3(r_nf.*cos(theta_nf), r_nf.*sin(theta_nf), ones(1,120)*6.6, ...
      '--', 'Color', [1 1 0.4], 'LineWidth', 1.8);
text(r_nf+0.1, 0, 6.6, '  \Deltaz/l = 6.6 (near-field)', ...
     'Color', [1 1 0.5], 'FontSize', 11, 'FontWeight', 'bold');

set(gca, 'ZDir', 'reverse', 'FontSize', 12);
axis equal;
xlabel('$x/l$', 'Interpreter', 'latex', 'FontSize', 14, 'Color', [0.85 0.85 0.85]);
ylabel('$y/l$', 'Interpreter', 'latex', 'FontSize', 14, 'Color', [0.85 0.85 0.85]);
zlabel('$\Delta z/l$ (depth below drone)', 'Interpreter', 'latex', 'FontSize', 14, 'Color', [0.85 0.85 0.85]);
title('3D Wake Boundary — Single Quadrotor Downwash', ...
      'FontSize', 16, 'Color', 'white', 'FontWeight', 'bold');

% Two lights for better depth/shading
camlight('headlight');
camlight('right');
lighting phong;
material([0.3 0.8 0.4 10]);   % [ambient diffuse specular shininess]
view([-35, 22]);

fprintf('Wake boundary defined at radius of peak velocity per depth.\n');
fprintf('Rotate with mouse to explore. Wide at top = strong near-field, narrows below.\n');