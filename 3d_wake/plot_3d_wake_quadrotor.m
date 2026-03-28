% 3D Wake Visualization - Quadrotor (4 individual rotor wakes)
% Shows 4 distinct wake tubes, one per propeller

fprintf('\n=== Starting Quadrotor Wake Visualization ===\n');
tic; % Start timer

%% Load PIV data from static folder
fprintf('Loading PIV data...\n');
static_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'static');
load(fullfile(static_dir, 'x_piv.mat')); % horizontal position
load(fullfile(static_dir, 'z_piv.mat')); % depth below drone
load(fullfile(static_dir, 'u_piv.mat')); % downward velocity
fprintf('  Data loaded: %dx%d grid\n', size(x_piv,1), size(x_piv,2));

%% Extract unique 1D grid vectors
r = unique(x_piv(:))'; % radial positions (treating x as radial distance from rotor center)
z = unique(z_piv(:));  % depth levels

% Interpolate u_piv onto clean r/z grid
[R_orig, Z_orig] = meshgrid(r, z);
u2d = griddata(x_piv(:), z_piv(:), u_piv(:), R_orig, Z_orig, 'linear');
u2d(isnan(u2d)) = 0;

n_z = length(z);
n_r = length(r);

%% For each depth, find the wake radius and peak velocity
% Only look at positive r (assuming axisymmetry per rotor)
r_pos = r(r >= 0);
u2d_pos = u2d(:, r >= 0);

wake_radius = zeros(n_z, 1);
peak_velocity = zeros(n_z, 1);

for zi = 1:n_z
    profile = u2d_pos(zi, :);
    peak_velocity(zi) = max(profile);
    % Find wake edge at 10% of peak velocity
    idx = find(profile >= 0.1 * peak_velocity(zi), 1, 'last');
    if ~isempty(idx)
        wake_radius(zi) = r_pos(idx);
    end
end

wake_radius = smoothdata(wake_radius, 'movmean', 20);
fprintf('  Wake profile extracted (took %.2f sec)\n', toc);

%% Quadrotor rotor positions (square configuration)
% Typical arm length = 1.0 normalized units
arm_length = 1.0;
rotor_positions = arm_length / sqrt(2) * [
     1,  1;  % Front-right
     1, -1;  % Back-right
    -1,  1;  % Front-left
    -1, -1   % Back-left
];

%% Build 3D surfaces for each rotor
n_angles = 40;  % angular resolution per rotor (reduced for faster rendering)
theta = linspace(0, 2*pi, n_angles);

% Storage for all rotor surfaces
X_rotors = cell(4, 1);
Y_rotors = cell(4, 1);
Z_rotors = cell(4, 1);
C_rotors = cell(4, 1);

for rotor_idx = 1:4
    % Center position of this rotor
    rx0 = rotor_positions(rotor_idx, 1);
    ry0 = rotor_positions(rotor_idx, 2);

    % Create axisymmetric surface centered at this rotor
    [TH, ~] = meshgrid(theta, 1:n_z);
    X_rotors{rotor_idx} = rx0 + repmat(wake_radius, 1, n_angles) .* cos(TH);
    Y_rotors{rotor_idx} = ry0 + repmat(wake_radius, 1, n_angles) .* sin(TH);
    Z_rotors{rotor_idx} = repmat(z, 1, n_angles);
    C_rotors{rotor_idx} = repmat(peak_velocity, 1, n_angles);
end

%% Create grids for top caps of each rotor
n_cap_r = 15;  % reduced for faster rendering
cap_X = cell(4, 1);
cap_Y = cell(4, 1);
cap_Z = cell(4, 1);
cap_C = cell(4, 1);

for rotor_idx = 1:4
    rx0 = rotor_positions(rotor_idx, 1);
    ry0 = rotor_positions(rotor_idx, 2);

    [TH_cap, R_cap] = meshgrid(theta, linspace(0, wake_radius(1), n_cap_r));
    cap_X{rotor_idx} = rx0 + R_cap .* cos(TH_cap);
    cap_Y{rotor_idx} = ry0 + R_cap .* sin(TH_cap);
    cap_Z{rotor_idx} = ones(size(R_cap)) * z(1);

    % Interpolate velocity at cap
    R_cap_flat = R_cap(:);
    cap_velocities = interp1(r_pos, u2d_pos(1,:), R_cap_flat, 'linear', 0);
    cap_C{rotor_idx} = reshape(cap_velocities, size(R_cap));
end

%% Plot setup
fprintf('Building 3D surfaces...\n');
fig = figure('Color', [0.05 0.05 0.08], 'Position', [100 80 1400 900], 'Renderer', 'opengl');
ax = axes;
ax.Color = [0.05 0.05 0.08];
ax.GridColor = [0.25 0.25 0.3];
ax.GridAlpha = 0.4;
ax.XColor = [0.75 0.75 0.75];
ax.YColor = [0.75 0.75 0.75];
ax.ZColor = [0.75 0.75 0.75];
hold on; grid on;

% Color scheme for 4 rotors
rotor_colors = [
    0.95, 0.3, 0.3;   % Red-ish
    0.3, 0.95, 0.3;   % Green-ish
    0.3, 0.6, 0.95;   % Blue-ish
    0.95, 0.7, 0.2    % Orange-ish
];

%% Plot all 4 rotor wakes
surfaces = gobjects(4, 1);
caps = gobjects(4, 1);

for rotor_idx = 1:4
    % Main wake tube
    surfaces(rotor_idx) = surf(X_rotors{rotor_idx}, Y_rotors{rotor_idx}, ...
                                Z_rotors{rotor_idx}, C_rotors{rotor_idx}, ...
                                'EdgeColor', 'none', 'FaceAlpha', 0.85, 'Tag', 'main');

    % Top cap
    caps(rotor_idx) = surf(cap_X{rotor_idx}, cap_Y{rotor_idx}, ...
                            cap_Z{rotor_idx}, cap_C{rotor_idx}, ...
                            'EdgeColor', 'none', 'FaceAlpha', 0.90, 'Tag', 'main');
end

%% Add rotor markers at drone level
for rotor_idx = 1:4
    rx = rotor_positions(rotor_idx, 1);
    ry = rotor_positions(rotor_idx, 2);
    plot3(rx, ry, z(1)-0.2, 'wo', 'MarkerSize', 12, ...
          'MarkerFaceColor', rotor_colors(rotor_idx,:), 'LineWidth', 2);
end

% Drone body outline (square connecting rotors)
drone_x = [rotor_positions(1,1), rotor_positions(2,1), rotor_positions(4,1), ...
           rotor_positions(3,1), rotor_positions(1,1)];
drone_y = [rotor_positions(1,2), rotor_positions(2,2), rotor_positions(4,2), ...
           rotor_positions(3,2), rotor_positions(1,2)];
drone_z = ones(size(drone_x)) * (z(1) - 0.2);
plot3(drone_x, drone_y, drone_z, 'w-', 'LineWidth', 2.5);

% Label
text(0, 0, z(1)-0.8, 'Quadrotor', 'Color', 'white', 'FontSize', 14, ...
     'FontWeight', 'bold', 'HorizontalAlignment', 'center');

%% Colormap and colorbar
fprintf('  Surfaces rendered (took %.2f sec total)\n', toc);
fprintf('Setting up colormap and UI controls...\n');
colormap(turbo);
clim([0 1]);
cb = colorbar('Color', [0.85 0.85 0.85]);
cb.Label.String = 'u/U_i (normalized downwash velocity)';
cb.Label.FontSize = 14;
cb.Label.Rotation = 270;
cb.Label.Position(1) = 3.5;

%% Styling
set(gca, 'ZDir', 'reverse', 'FontSize', 12);
axis equal;
xlabel('$x/l$', 'Interpreter', 'latex', 'FontSize', 14, 'Color', [0.85 0.85 0.85]);
ylabel('$y/l$', 'Interpreter', 'latex', 'FontSize', 14, 'Color', [0.85 0.85 0.85]);
zlabel('$\Delta z/l$ (depth below drone)', 'Interpreter', 'latex', 'FontSize', 14, 'Color', [0.85 0.85 0.85]);
title('3D Wake Boundary — Quadrotor (4 Individual Rotors)', 'FontSize', 16, 'Color', 'white', 'FontWeight', 'bold');

camlight('headlight');
camlight('right');
lighting gouraud;
material([0.3 0.8 0.4 10]);
view([-35, 22]);

%% Interactive Slicing UI
uipanel('Parent', fig, 'Position', [0.0 0.0 1.0 0.1], 'BackgroundColor', [0.15 0.15 0.2]);

uicontrol('Style', 'text', 'Parent', fig, 'Units', 'normalized', ...
          'Position', [0.02 0.04 0.08 0.03], 'String', 'Slice Plane:', ...
          'ForegroundColor', 'w', 'BackgroundColor', [0.15 0.15 0.2], 'FontSize', 12);
plane_menu = uicontrol('Style', 'popupmenu', 'Parent', fig, 'Units', 'normalized', ...
                       'Position', [0.11 0.04 0.1 0.03], ...
                       'String', {'XY (Top-Down)', 'XZ (Side)', 'YZ (Front)'}, ...
                       'FontSize', 11);

uicontrol('Style', 'text', 'Parent', fig, 'Units', 'normalized', ...
          'Position', [0.25 0.04 0.05 0.03], 'String', 'Pos:', ...
          'ForegroundColor', 'w', 'BackgroundColor', [0.15 0.15 0.2], 'FontSize', 12);
slice_slider = uicontrol('Style', 'slider', 'Parent', fig, 'Units', 'normalized', ...
                         'Position', [0.31 0.04 0.5 0.03], 'Min', 0, 'Max', 1, 'Value', 0.5);

val_text = uicontrol('Style', 'text', 'Parent', fig, 'Units', 'normalized', ...
                     'Position', [0.83 0.04 0.08 0.03], 'String', '0.00', ...
                     'ForegroundColor', 'w', 'BackgroundColor', [0.15 0.15 0.2], 'FontSize', 12);

slice_patch = patch('XData', [], 'YData', [], 'ZData', [], ...
                    'FaceColor', [1 0.2 0.2], 'FaceAlpha', 0.3, 'EdgeColor', 'r', 'LineWidth', 2);

enable_cut = uicontrol('Style', 'checkbox', 'Parent', fig, 'Units', 'normalized', ...
                       'Position', [0.31 0.01 0.1 0.03], 'String', 'Enable Cut', ...
                       'Value', 1, 'ForegroundColor', 'w', 'BackgroundColor', [0.15 0.15 0.2], ...
                       'Callback', @(src,~) update_slice(src));

flip_cut = uicontrol('Style', 'checkbox', 'Parent', fig, 'Units', 'normalized', ...
                     'Position', [0.42 0.01 0.1 0.03], 'String', 'Flip Cut Side', ...
                     'Value', 0, 'ForegroundColor', 'w', 'BackgroundColor', [0.15 0.15 0.2], ...
                     'Callback', @(src,~) update_slice(src));

% Get bounding box from all rotors
all_X = cell2mat(cellfun(@(x) x(:), X_rotors, 'UniformOutput', false));
all_Y = cell2mat(cellfun(@(x) x(:), Y_rotors, 'UniformOutput', false));
x_min = min(all_X); x_max = max(all_X);
y_min = min(all_Y); y_max = max(all_Y);
z_min = min(z); z_max = max(z);

% Store original data for clipping
all_surfaces = findobj(ax, 'Type', 'Surface');
for k = 1:numel(all_surfaces)
    all_surfaces(k).UserData = struct('X', all_surfaces(k).XData, ...
                                      'Y', all_surfaces(k).YData, ...
                                      'Z', all_surfaces(k).ZData);
end

% Bundle handles
handles.plane_menu = plane_menu;
handles.slice_slider = slice_slider;
handles.val_text = val_text;
handles.slice_patch = slice_patch;
handles.enable_cut = enable_cut;
handles.flip_cut = flip_cut;
handles.surfaces = all_surfaces;
handles.x_min = x_min; handles.x_max = x_max;
handles.y_min = y_min; handles.y_max = y_max;
handles.z_min = z_min; handles.z_max = z_max;
guidata(fig, handles);

set(plane_menu, 'Callback', @(src,~) update_slider_limits(src));
set(slice_slider, 'Callback', @(src,~) update_slice(src));

update_slider_limits(plane_menu);

%% Callback functions
function update_slider_limits(src)
    fig = ancestor(src, 'figure');
    h = guidata(fig);
    plane_idx = h.plane_menu.Value;
    if plane_idx == 1 % XY
        set(h.slice_slider, 'Min', h.z_min, 'Max', h.z_max, 'Value', (h.z_min+h.z_max)/2);
    elseif plane_idx == 2 % XZ
        set(h.slice_slider, 'Min', h.y_min, 'Max', h.y_max, 'Value', 0);
    else % YZ
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

    pad = 0.5;

    if plane_idx == 1 % XY
        h.slice_patch.XData = [h.x_min-pad h.x_max+pad h.x_max+pad h.x_min-pad];
        h.slice_patch.YData = [h.y_min-pad h.y_min-pad h.y_max+pad h.y_max+pad];
        h.slice_patch.ZData = [v v v v];
    elseif plane_idx == 2 % XZ
        h.slice_patch.XData = [h.x_min-pad h.x_max+pad h.x_max+pad h.x_min-pad];
        h.slice_patch.YData = [v v v v];
        h.slice_patch.ZData = [h.z_min-pad h.z_min-pad h.z_max+pad h.z_max+pad];
    else % YZ
        h.slice_patch.XData = [v v v v];
        h.slice_patch.YData = [h.y_min-pad h.y_max+pad h.y_max+pad h.y_min-pad];
        h.slice_patch.ZData = [h.z_min-pad h.z_min-pad h.z_max+pad h.z_max+pad];
    end

    do_cut = h.enable_cut.Value;
    do_flip = h.flip_cut.Value;

    for k = 1:numel(h.surfaces)
        orig_X = h.surfaces(k).UserData.X;
        orig_Y = h.surfaces(k).UserData.Y;
        orig_Z = h.surfaces(k).UserData.Z;

        if do_cut
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

            new_Z = orig_Z;
            new_Z(mask) = NaN;
            set(h.surfaces(k), 'ZData', new_Z);
        else
            set(h.surfaces(k), 'ZData', orig_Z);
        end
    end
end

%% Keep figure open (prevents auto-close in batch mode)
fprintf('\n=== Figure is now open ===\n');
fprintf('Total time: %.2f seconds\n', toc);
fprintf('Interact with the visualization using the controls at the bottom.\n');
fprintf('Close the figure window when done.\n\n');
