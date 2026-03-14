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

%% Interactive Slicing UI Feature
% Create UI Panel at the bottom
uipanel('Parent', fig, 'Position', [0.0 0.0 1.0 0.1], 'BackgroundColor', [0.15 0.15 0.2]);

% Plane selection dropdown
uicontrol('Style', 'text', 'Parent', fig, 'Units', 'normalized', ...
          'Position', [0.02 0.04 0.08 0.03], 'String', 'Slice Plane:', ...
          'ForegroundColor', 'w', 'BackgroundColor', [0.15 0.15 0.2], 'FontSize', 12);
plane_menu = uicontrol('Style', 'popupmenu', 'Parent', fig, 'Units', 'normalized', ...
                       'Position', [0.11 0.04 0.1 0.03], 'String', {'XY (Top-Down)', 'XZ (Side)', 'YZ (Front)'}, ...
                       'FontSize', 11);

% Slider control
uicontrol('Style', 'text', 'Parent', fig, 'Units', 'normalized', ...
          'Position', [0.25 0.04 0.05 0.03], 'String', 'Pos:', ...
          'ForegroundColor', 'w', 'BackgroundColor', [0.15 0.15 0.2], 'FontSize', 12);
slice_slider = uicontrol('Style', 'slider', 'Parent', fig, 'Units', 'normalized', ...
                         'Position', [0.31 0.04 0.5 0.03], 'Min', 0, 'Max', 1, 'Value', 0.5);

% Value text display
val_text = uicontrol('Style', 'text', 'Parent', fig, 'Units', 'normalized', ...
                     'Position', [0.83 0.04 0.08 0.03], 'String', '0.00', ...
                     'ForegroundColor', 'w', 'BackgroundColor', [0.15 0.15 0.2], 'FontSize', 12);

% Initialize slice plane object
slice_patch = patch('XData', [], 'YData', [], 'ZData', [], ...
                    'FaceColor', [1 0.2 0.2], 'FaceAlpha', 0.3, 'EdgeColor', 'r', 'LineWidth', 2);

% Clipping controls
enable_cut = uicontrol('Style', 'checkbox', 'Parent', fig, 'Units', 'normalized', ...
                       'Position', [0.31 0.01 0.1 0.03], 'String', 'Enable Cut', ...
                       'Value', 1, 'ForegroundColor', 'w', 'BackgroundColor', [0.15 0.15 0.2], ...
                       'Callback', @(src,~) update_slice(src));
                       
flip_cut = uicontrol('Style', 'checkbox', 'Parent', fig, 'Units', 'normalized', ...
                     'Position', [0.42 0.01 0.1 0.03], 'String', 'Flip Cut Side', ...
                     'Value', 0, 'ForegroundColor', 'w', 'BackgroundColor', [0.15 0.15 0.2], ...
                     'Callback', @(src,~) update_slice(src));

% Get bounding box arrays to generate the plane
x_min = min(X_surf(:)); x_max = max(X_surf(:));
y_min = min(Y_surf(:)); y_max = max(Y_surf(:));
z_min = min(z); z_max = max(z);

% Find all surfaces and store their original data for clipping
surfaces = findobj(ax, 'Type', 'Surface');
for k = 1:numel(surfaces)
    surfaces(k).UserData = struct('X', surfaces(k).XData, ...
                                  'Y', surfaces(k).YData, ...
                                  'Z', surfaces(k).ZData);
end

% Bundle handles into a struct and store on figure
handles.plane_menu   = plane_menu;
handles.slice_slider = slice_slider;
handles.val_text     = val_text;
handles.slice_patch  = slice_patch;
handles.enable_cut   = enable_cut;
handles.flip_cut     = flip_cut;
handles.surfaces     = surfaces;
handles.x_min = x_min; handles.x_max = x_max;
handles.y_min = y_min; handles.y_max = y_max;
handles.z_min = z_min; handles.z_max = z_max;
guidata(fig, handles);

% Update callbacks to fetch handles from guidata
set(plane_menu,  'Callback', @(src,~) update_slider_limits(src));
set(slice_slider,'Callback', @(src,~) update_slice(src));

% Initialize state
update_slider_limits(plane_menu);

% Callbacks for UI interaction
function update_slider_limits(src)
    fig = ancestor(src, 'figure');
    h = guidata(fig);
    plane_idx = h.plane_menu.Value;
    if plane_idx == 1 % XY plane (slides along Z axis)
        set(h.slice_slider, 'Min', h.z_min, 'Max', h.z_max, 'Value', (h.z_min+h.z_max)/2);
    elseif plane_idx == 2 % XZ plane (slides along Y axis)
        set(h.slice_slider, 'Min', h.y_min, 'Max', h.y_max, 'Value', 0);
    else % YZ plane (slides along X axis)
        set(h.slice_slider, 'Min', h.x_min, 'Max', h.x_max, 'Value', 0);
    end
    update_slice(h.slice_slider);
end

function update_slice(src)
    fig = ancestor(src, 'figure');
    h = guidata(fig);
    v = get(h.slice_slider, 'Value');
    plane_idx = h.plane_menu.Value;
    set(h.val_text, 'String', sprintf('%.2f', v));
    
    % Extra padding for plane visually
    pad = 0.5; 
    
    if plane_idx == 1 % XY (Z = v)
        h.slice_patch.XData = [h.x_min-pad h.x_max+pad h.x_max+pad h.x_min-pad];
        h.slice_patch.YData = [h.y_min-pad h.y_min-pad h.y_max+pad h.y_max+pad];
        h.slice_patch.ZData = [v v v v];
    elseif plane_idx == 2 % XZ (Y = v)
        h.slice_patch.XData = [h.x_min-pad h.x_max+pad h.x_max+pad h.x_min-pad];
        h.slice_patch.YData = [v v v v];
        h.slice_patch.ZData = [h.z_min-pad h.z_min-pad h.z_max+pad h.z_max+pad];
    else % YZ (X = v)
        h.slice_patch.XData = [v v v v];
        h.slice_patch.YData = [h.y_min-pad h.y_max+pad h.y_max+pad h.y_min-pad];
        h.slice_patch.ZData = [h.z_min-pad h.z_min-pad h.z_max+pad h.z_max+pad];
    end
    
    % Apply clipping
    do_cut = h.enable_cut.Value;
    do_flip = h.flip_cut.Value;
    
    for k = 1:numel(h.surfaces)
        orig_X = h.surfaces(k).UserData.X;
        orig_Y = h.surfaces(k).UserData.Y;
        orig_Z = h.surfaces(k).UserData.Z;
        
        if do_cut
            % Find points to hide based on plane
            if plane_idx == 1
                mask = orig_Z < v;
            elseif plane_idx == 2
                mask = orig_Y < v;
            else
                mask = orig_X < v;
            end
            
            if do_flip
                mask = ~mask;
            end
            
            % Hide vertices by replacing Z with NaN
            new_Z = orig_Z;
            new_Z(mask) = NaN;
            set(h.surfaces(k), 'ZData', new_Z);
        else
            % Restore original
            set(h.surfaces(k), 'ZData', orig_Z);
        end
    end
end