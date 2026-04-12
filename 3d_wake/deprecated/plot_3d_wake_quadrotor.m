% 3D Wake Visualization - Quadrotor (retuned geometry + convergence)
% Supports:
%   - current: legacy square layout
%   - paper: inward-tilted, non-uniform rotor spacing layout
%   - both: overlays both for direct comparison

fprintf('\n=== Starting Quadrotor Wake Visualization ===\n');
tic; % Start timer

%% User-tunable model options
drone_mode = 'both';        % 'current' | 'paper' | 'both'
z_virtual_origin = -6.05;   % virtual origin in positive-down depth coordinates
wake_blend = 0.70;          % 0=data-driven only, 1=virtual-origin model only

%% Load PIV data from static folder
fprintf('Loading PIV data...\n');
static_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'static');
load(fullfile(static_dir, 'x_piv.mat')); % horizontal position
load(fullfile(static_dir, 'z_piv.mat')); % depth below drone
load(fullfile(static_dir, 'u_piv.mat')); % downward velocity
fprintf('  Data loaded: %dx%d grid\n', size(x_piv,1), size(x_piv,2));

%% Extract unique 1D grid vectors
r = unique(x_piv(:))'; % radial positions (treating x as radial distance from rotor center)
z = unique(z_piv(:));  % depth levels (positive-down convention for modeling)
z_vis = -z;            % visual convention for plotting (negative-down values)

% Interpolate u_piv onto clean r/z grid
[R_orig, Z_orig] = meshgrid(r, z);
u2d = griddata(x_piv(:), z_piv(:), u_piv(:), R_orig, Z_orig, 'linear');
u2d(isnan(u2d)) = 0;

n_z = length(z);
n_r = length(r); %#ok<NASGU>

%% Extract wake radius profile and retune with virtual-origin correction
% Only look at positive r (assuming axisymmetry per rotor)
r_pos = r(r >= 0);
u2d_pos = u2d(:, r >= 0);

wake_radius_data = zeros(n_z, 1);
peak_velocity = zeros(n_z, 1);

for zi = 1:n_z
    profile = u2d_pos(zi, :);
    peak_velocity(zi) = max(profile);
    idx = find(profile >= 0.1 * peak_velocity(zi), 1, 'last');
    if ~isempty(idx)
        wake_radius_data(zi) = r_pos(idx);
    end
end

wake_radius_data = smoothdata(wake_radius_data, 'movmean', 20);

% Force physically consistent expansion from a virtual origin (z0 = -6.05)
zz = z - z_virtual_origin;
zz(zz < 0) = 0;
k = (zz' * wake_radius_data) / (zz' * zz + eps);
wake_radius_virtual = k * zz;
wake_radius_virtual = wake_radius_virtual - wake_radius_virtual(1) + wake_radius_data(1);

% Blend measured profile with virtual-origin profile
wake_radius = (1 - wake_blend) * wake_radius_data + wake_blend * wake_radius_virtual;
wake_radius = smoothdata(max(wake_radius, 0), 'movmean', 12);
fprintf('  Wake profile extracted (took %.2f sec)\n', toc);

%% Build drone configurations
configs = build_drone_configs(drone_mode);

%% Build 3D surfaces for each rotor in each configuration
n_angles = 40;
theta = linspace(0, 2*pi, n_angles);

X_rotors = {};
Y_rotors = {};
Z_rotors = {};
C_rotors = {};
rotor_meta = struct('cfg_idx', {}, 'rotor_idx', {});

[TH, ~] = meshgrid(theta, 1:n_z);

for cfg_idx = 1:numel(configs)
    cfg = configs(cfg_idx);

    for rotor_idx = 1:size(cfg.rotor_positions, 1)
        p0 = cfg.rotor_positions(rotor_idx, :);
        base_xy = p0(1:2);
        z_offset = p0(3);

        inward_dir = -base_xy;
        if norm(inward_dir) < eps
            inward_dir = [0, 0];
        else
            inward_dir = inward_dir / norm(inward_dir);
        end

        axial_depth = (z - z(1));
        center_shift = tand(cfg.tilt_deg) * axial_depth;
        cx = base_xy(1) + inward_dir(1) * center_shift;
        cy = base_xy(2) + inward_dir(2) * center_shift;

        Xr = repmat(cx, 1, n_angles) + repmat(wake_radius, 1, n_angles) .* cos(TH);
        Yr = repmat(cy, 1, n_angles) + repmat(wake_radius, 1, n_angles) .* sin(TH);
        Zr = repmat(z_vis + z_offset, 1, n_angles);
        Cr = repmat(peak_velocity, 1, n_angles);

        X_rotors{end+1, 1} = Xr; %#ok<AGROW>
        Y_rotors{end+1, 1} = Yr; %#ok<AGROW>
        Z_rotors{end+1, 1} = Zr; %#ok<AGROW>
        C_rotors{end+1, 1} = Cr; %#ok<AGROW>

        rotor_meta(end+1).cfg_idx = cfg_idx; %#ok<AGROW>
        rotor_meta(end).rotor_idx = rotor_idx;
    end
end

%% Create top caps for each rotor
n_cap_r = 15;
cap_X = cell(numel(X_rotors), 1);
cap_Y = cell(numel(X_rotors), 1);
cap_Z = cell(numel(X_rotors), 1);
cap_C = cell(numel(X_rotors), 1);

[TH_cap, R_cap] = meshgrid(theta, linspace(0, wake_radius(1), n_cap_r));
R_cap_flat = R_cap(:);
cap_velocities = interp1(r_pos, u2d_pos(1,:), R_cap_flat, 'linear', 0);
cap_color_template = reshape(cap_velocities, size(R_cap));

for rotor_global_idx = 1:numel(X_rotors)
    X0 = X_rotors{rotor_global_idx}(1, :);
    Y0 = Y_rotors{rotor_global_idx}(1, :);
    center_x = mean(X0);
    center_y = mean(Y0);
    center_z = Z_rotors{rotor_global_idx}(1, 1);

    cap_X{rotor_global_idx} = center_x + R_cap .* cos(TH_cap);
    cap_Y{rotor_global_idx} = center_y + R_cap .* sin(TH_cap);
    cap_Z{rotor_global_idx} = ones(size(R_cap)) * center_z;
    cap_C{rotor_global_idx} = cap_color_template;
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

%% Plot all rotor wakes (possibly multiple drone models)
surfaces = gobjects(numel(X_rotors), 1);
caps = gobjects(numel(X_rotors), 1); %#ok<NASGU>

for rotor_global_idx = 1:numel(X_rotors)
    cfg = configs(rotor_meta(rotor_global_idx).cfg_idx);

    surfaces(rotor_global_idx) = surf(X_rotors{rotor_global_idx}, Y_rotors{rotor_global_idx}, ...
                                      Z_rotors{rotor_global_idx}, C_rotors{rotor_global_idx}, ...
                                      'EdgeColor', 'none', 'FaceAlpha', cfg.tube_alpha, 'Tag', 'main');

    caps(rotor_global_idx) = surf(cap_X{rotor_global_idx}, cap_Y{rotor_global_idx}, ...
                                  cap_Z{rotor_global_idx}, cap_C{rotor_global_idx}, ...
                                  'EdgeColor', 'none', 'FaceAlpha', cfg.cap_alpha, 'Tag', 'main');
end

%% Add rotor markers and body outlines for each configuration
for cfg_idx = 1:numel(configs)
    cfg = configs(cfg_idx);
    rp = cfg.rotor_positions;

    for rotor_idx = 1:size(rp, 1)
          plot3(rp(rotor_idx, 1), rp(rotor_idx, 2), z_vis(1) + rp(rotor_idx, 3) - 0.2, ...
              'wo', 'MarkerSize', 10, 'MarkerFaceColor', cfg.marker_color, 'LineWidth', 1.8);
    end

    % Rotor order: FR, FL, BR, BL -> outline around perimeter
    order = [1 2 4 3 1];
    drone_x = rp(order, 1)';
    drone_y = rp(order, 2)';
    drone_z = (z_vis(1) - 0.2) + rp(order, 3)';
    plot3(drone_x, drone_y, drone_z, cfg.body_line_style, 'Color', cfg.body_color, 'LineWidth', 2.3);

    text(mean(rp(:,1)), mean(rp(:,2)), z_vis(1) - 0.9 + mean(rp(:,3)), cfg.label, ...
         'Color', cfg.body_color, 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
end

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
set(gca, 'FontSize', 12);
axis equal;
xlabel('$x/l$', 'Interpreter', 'latex', 'FontSize', 14, 'Color', [0.85 0.85 0.85]);
ylabel('$y/l$', 'Interpreter', 'latex', 'FontSize', 14, 'Color', [0.85 0.85 0.85]);
zlabel('$z/l$ (negative values are below drone)', 'Interpreter', 'latex', 'FontSize', 14, 'Color', [0.85 0.85 0.85]);
title(sprintf('3D Wake Boundary — Quadrotor (%s model)', upper(drone_mode)), ...
    'FontSize', 16, 'Color', 'white', 'FontWeight', 'bold');

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
all_Z = cell2mat(cellfun(@(x) x(:), Z_rotors, 'UniformOutput', false));
z_min = min(all_Z); z_max = max(all_Z);

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

%% Local helper: drone configurations
function cfgs = build_drone_configs(mode)
    mode = lower(string(mode));

    % --- Current (legacy) model ---
    arm_length = 1.0;
    rp_current_xy = arm_length / sqrt(2) * [
         1,  1;  % Front-right
        -1,  1;  % Front-left
         1, -1;  % Back-right
        -1, -1   % Back-left
    ];
    rp_current = [rp_current_xy, zeros(4,1)];

    current_cfg = struct( ...
        'label', 'Current', ...
        'rotor_positions', rp_current, ...
        'tilt_deg', 0.0, ...
        'tube_alpha', 0.82, ...
        'cap_alpha', 0.88, ...
        'body_color', [0.95 0.95 0.95], ...
        'marker_color', [0.70 0.85 1.00], ...
        'body_line_style', '-');

    % --- Paper-inspired model ---
    D = 2.0;  % normalized by rotor radius R, so D = 2R = 2.0
    front_sep = 1.35 * D;
    back_sep = 1.17 * D;
    body_longitudinal_sep = 1.25 * D;
    dz_fb = 0.18 * D;
    y_front = +body_longitudinal_sep / 2;
    y_back = -body_longitudinal_sep / 2;

    rp_paper = [
        +front_sep/2, y_front, +dz_fb/2;  % Front-right (higher)
        -front_sep/2, y_front, +dz_fb/2;  % Front-left  (higher)
        +back_sep/2,  y_back,  -dz_fb/2;  % Back-right  (lower)
        -back_sep/2,  y_back,  -dz_fb/2   % Back-left   (lower)
    ];

    paper_cfg = struct( ...
        'label', 'Paper-inspired', ...
        'rotor_positions', rp_paper, ...
        'tilt_deg', 4.5, ...
        'tube_alpha', 0.58, ...
        'cap_alpha', 0.65, ...
        'body_color', [1.00 0.85 0.30], ...
        'marker_color', [1.00 0.80 0.35], ...
        'body_line_style', '--');

    switch mode
        case "current"
            cfgs = current_cfg;
        case "paper"
            cfgs = paper_cfg;
        otherwise
            cfgs = [current_cfg, paper_cfg];
    end
end
