% 3D Wake Visualization - Continuous donut/vase shape
% Each depth has a ring whose radius = where peak velocity occurs

%% Load PIV data from static folder
%% These 3 files are used to match measured velocities at specific points with their coordinates.
static_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'static'); % build the path to the static folder relative to where this script lives
load(fullfile(static_dir, 'x_piv.mat')); % loads x_piv — the horizontal position of each PIV measurement point
load(fullfile(static_dir, 'z_piv.mat')); % loads z_piv — how deep each measurement point is below the drone
load(fullfile(static_dir, 'u_piv.mat')); % loads u_piv — the actual downward velocity measured at each point

%% Extract unique 1D grid vector
r = unique(x_piv(:))'; % pull out all the unique x positions as a row vector, these become our radial axis
z = unique(z_piv(:));  % same thing but for depth, gives us a clean list of depth levels

% Interpolate u_piv onto clean r/z grid
[R_orig, Z_orig] = meshgrid(r, z); % make a 2d grid from r and z so every (x,depth) combo has a coordinate
u2d = griddata(x_piv(:), z_piv(:), u_piv(:), R_orig, Z_orig, 'linear'); % scatter the PIV points onto that clean grid using linear interpolation
u2d(isnan(u2d)) = 0; % anywhere the interpolation couldnt figure out a value just set it to zero

n_z = length(z); % how many depth levels we have in total
n_r = length(r); % how many radial positions we have in total

%% For each depth, find the wake radius and peak velocity

% only look at the right half (x >= 0) since the wake is symmetric
r_pos      = r(r >= 0);          % just the positive radial positions
u2d_pos    = u2d(:, r >= 0);     % trim the velocity grid to match

wake_radius   = zeros(n_z, 1); % will store how wide the wake is at each depth
peak_velocity = zeros(n_z, 1); % will store the fastest velocity at each depth

for zi = 1:n_z
    profile           = u2d_pos(zi, :);          % velocity across all x positions at this depth
    peak_velocity(zi) = max(profile);             % strongest velocity in this slice
    idx               = find(profile >= 0.1 * peak_velocity(zi), 1, 'last'); % furthest point still at 10% of peak — thats the wake edge
    if ~isempty(idx)
        wake_radius(zi) = r_pos(idx);             % save that x position as the wake radius
    end
end

wake_radius = smoothdata(wake_radius, 'movmean', 20); % smooth out jaggedness with a 20-point moving average

%% At this point we have 1D profile of the wake shape — single column of numbers saying "at depth Z, the wake extends out to radius R, and peak velocity"

%% Build 3D surface by spinning the 1D profile 360 degrees around the z axis
n_angles = 90;                       % how many steps around the circle — 90 is smooth enough
theta    = linspace(0, 2*pi, n_angles); % the 90 angle values from 0 to 360 degrees

[TH, ~]  = meshgrid(theta, 1:n_z);               % grid of angle vs depth — every combination gets a point
X_surf   = repmat(wake_radius, 1, n_angles) .* cos(TH); % x = radius * cos(angle)
Y_surf   = repmat(wake_radius, 1, n_angles) .* sin(TH); % y = radius * sin(angle)
Z_surf   = repmat(z, 1, n_angles);                % depth just repeats across all angles
C_surf   = repmat(peak_velocity, 1, n_angles);    % color = peak velocity at each depth, same for all angles

% grid for the inner horizontal discs (spans full radius from center outward)
[TH2, ~] = meshgrid(theta, 1:n_r);               % angle vs radial position grid
X_disc   = repmat(r', 1, n_angles) .* cos(TH2);  % x coords for a flat disc at any depth
Y_disc   = repmat(r', 1, n_angles) .* sin(TH2);  % y coords for a flat disc


%% Plot and Style
fig = figure('Color', [0.05 0.05 0.08], 'Position', [100 80 1200 850], 'Renderer', 'opengl'); % dark background figure
ax  = axes;
ax.Color     = [0.05 0.05 0.08]; % axes background matches figure
ax.GridColor = [0.25 0.25 0.3];
ax.GridAlpha = 0.4;
ax.XColor    = [0.75 0.75 0.75]; % light grey axis labels
ax.YColor    = [0.75 0.75 0.75];
ax.ZColor    = [0.75 0.75 0.75];
hold on; grid on;

% outer wake boundary tube
surf(X_surf, Y_surf, Z_surf, C_surf, 'EdgeColor', 'none', 'FaceAlpha', 0.92, 'Tag', 'main');

% top cap — filled disc closing off the top of the tube
[TH_cap, R_cap] = meshgrid(theta, linspace(0, wake_radius(1), 35)); % grid covering the top disc
surf(R_cap.*cos(TH_cap), R_cap.*sin(TH_cap), ones(size(R_cap))*z(1), ...
     interp1(r, u2d(1,:), R_cap, 'linear', 0), 'EdgeColor', 'none', 'FaceAlpha', 0.95, 'Tag', 'main');

% inner horizontal discs — one every 20 depth levels, very transparent so you can see inside
slice_indices = 1:20:n_z;
inner_slices  = gobjects(numel(slice_indices), 1);
for i = 1:numel(slice_indices)
    zi = slice_indices(i);
    inner_slices(i) = surf(X_disc, Y_disc, ones(n_r, n_angles)*z(zi), ...
                           repmat(u2d(zi,:)', 1, n_angles), ...
                           'EdgeColor', 'none', 'FaceAlpha', 0.10, 'Tag', 'inner');
end
inner_slice_z = z(slice_indices); % save the depth of each disc for the slider to reference later

colormap(turbo);
clim([0 1]);
cb = colorbar('Color', [0.85 0.85 0.85]);
cb.Label.String    = '$\bar{u}/U_i$  (normalized downwash velocity)';
cb.Label.Interpreter = 'latex';
cb.Label.FontSize  = 14;
cb.Label.Rotation  = 270;
cb.Label.Position(1) = 3.5;

% drone marker
plot3(0, 0, z(1)-0.3, 'w^', 'MarkerSize', 18, 'MarkerFaceColor', [0.9 0.9 1.0], 'LineWidth', 1.5);
text(0.2, 0, z(1)-0.5, 'Drone', 'Color', 'white', 'FontSize', 13, 'FontWeight', 'bold');

% near-field boundary ring at z = 6.6
r_nf      = interp1(z, wake_radius, 6.6, 'linear'); % wake radius at the near-field depth
theta_nf  = linspace(0, 2*pi, 120);
plot3(r_nf.*cos(theta_nf), r_nf.*sin(theta_nf), ones(1,120)*6.6, '--', 'Color', [1 1 0.4], 'LineWidth', 1.8);
text(r_nf+0.1, 0, 6.6, '  \Deltaz/l = 6.6 (near-field)', 'Color', [1 1 0.5], 'FontSize', 11, 'FontWeight', 'bold');

set(gca, 'ZDir', 'reverse', 'FontSize', 12); % flip z so depth goes downward
axis equal;
xlabel('$x/l$',                          'Interpreter', 'latex', 'FontSize', 14, 'Color', [0.85 0.85 0.85]);
ylabel('$y/l$',                          'Interpreter', 'latex', 'FontSize', 14, 'Color', [0.85 0.85 0.85]);
zlabel('$\Delta z/l$ (depth below drone)','Interpreter', 'latex', 'FontSize', 14, 'Color', [0.85 0.85 0.85]);
title('3D Wake Boundary — Single Quadrotor Downwash', 'FontSize', 16, 'Color', 'white', 'FontWeight', 'bold');

camlight('headlight');
camlight('right');
lighting gouraud;
material([0.3 0.8 0.4 10]);
view([-35, 22]);

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