% nika-bruno-wake-model.m
%
% Combines Bruno's near-field 4-peak Gaussian fit with Nika's 2-ring far-field
% model and compares them in the overlap region (z/l = 1.0 to ~2.1).
%
% Key differences from near_field_z_loop_plot.m:
%   - RMSE normalized against peak amplitude (matches Nika's normalization)
%   - Nika's model overlaid in Cartesian x-coordinates for direct comparison
%   - Comparison figure restricted to the overlap domain (z/l >= 1.0)
%
% Coordinate systems:
%   Bruno's data:  x_piv in units of arm length l (lateral), z_piv in z/R (negative downward)
%   Nika's model:  r = radial distance from center in units of l, z in z/l (positive downward)
%   Mapping:       |x| = r, so Nika's u(r,z) maps to 4-peak Cartesian as shown below.
%   NOTE: verify x_piv units match l before trusting parameter comparison.

data_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'static');

R_mm = 22.5;
l_mm = 32.5;
scale = R_mm / l_mm;  % Bruno z/R * scale = z/l

load(fullfile(data_dir, 'x_piv.mat'));
load(fullfile(data_dir, 'z_piv.mat'));
load(fullfile(data_dir, 'u_piv.mat'));

unique_z = uniquetol(z_piv, 1e-4);
near_field_z = unique_z(unique_z < 0 & unique_z >= -3.0);
num_depths = length(near_field_z);

% columns: [Z_depth, A_inner, A_outer, Sigma, X_left, X_right, Radius, RMSE]
z_sweep_results = zeros(num_depths, 8);

% Bruno's 4-peak model (Cartesian, left-right symmetric)
% inner peaks: X_left+R, X_right-R  (≈ ±Ri in Nika's notation)
% outer peaks: X_left-R, X_right+R  (≈ ±Ro in Nika's notation)
% p = [A_inner, A_outer, sigma, X_left, X_right, R]
near_field_model = @(p, x) ...
    p(1) * (exp(-((x - (p(4) + p(6))).^2) / (2*p(3)^2)) + ...
            exp(-((x - (p(5) - p(6))).^2) / (2*p(3)^2))) + ...
    p(2) * (exp(-((x - (p(4) - p(6))).^2) / (2*p(3)^2)) + ...
            exp(-((x - (p(5) + p(6))).^2) / (2*p(3)^2)));

% Nika's 2-ring model mapped to Cartesian x (exploits left-right symmetry)
% u(x,z) = Ai*[G(x-Ri) + G(x+Ri)] + Ao*[G(x-Ro) + G(x+Ro)]
% params_nika(z) = [Ai, Ao, sigma, Ri, Ro]
nika_model = @(p, x) ...
    p(1) * (exp(-((x - p(4)).^2) / (2*p(3)^2)) + ...
            exp(-((x + p(4)).^2) / (2*p(3)^2))) + ...
    p(2) * (exp(-((x - p(5)).^2) / (2*p(3)^2)) + ...
            exp(-((x + p(5)).^2) / (2*p(3)^2)));

% Nika's parameters from radial_fit_test.py output (fit domain: z/l = 1.0 to 3.5)
% Format: [z/l, Ai, Ao, sigma, Ri, Ro]
% sigma is shared between both rings at every depth (single-width model)
nika_params_table = [
    1.0,  1.0167, 0.8762, 0.2081, 0.6615, 1.3386;
    1.2,  0.9539, 0.8380, 0.2280, 0.6427, 1.3287;
    1.5,  0.8669, 0.7837, 0.2577, 0.6145, 1.3138;
    2.0,  0.7392, 0.7010, 0.3074, 0.5676, 1.2891;
    2.5,  0.6303, 0.6270, 0.3570, 0.5206, 1.2643;
    3.0,  0.5375, 0.5608, 0.4067, 0.4737, 1.2396;
    3.5,  0.4583, 0.5016, 0.4564, 0.4267, 1.2148;
];
% Bruno's data tops out at z/l ≈ 2.08 (near_field_z filter limit),
% so the usable overlap region is z/l = 1.0 to 2.0 (rows 1-4 above).

options = optimoptions('lsqcurvefit', 'Display', 'off');

initial_guess = [0.3, 0.3, 0.08, -1.35, 1.35, 0.02];
lb = [0.0, 0.0, 0.02, -3.0,  0.5, 0.02];
ub = [1.0, 1.0, 0.47, -0.5,  3.0, 1.5];

disp('Starting Z-Sweep...');

figure(1); clf; hold on;
xlabel('Normalized Radial Distance (x)');
ylabel('Depth (z/l)');
zlabel('Normalized Downwash Velocity (u)');
title('3D Waterfall — Bruno Near-Field Fits');
view(3);
grid on;

for i = 1:num_depths
    current_z = near_field_z(i);

    tolerance = 0.05;
    slice_idx = abs(z_piv - current_z) < tolerance;
    x_slice = x_piv(slice_idx);
    u_slice = u_piv(slice_idx);
    u_slice = u_slice - median(u_slice(x_slice < -3 | x_slice > 50));

    if length(x_slice) > 20
        current_z_l = -current_z * scale;

        % depth-dependent lower bound: prevent A_outer collapsing near rotor
        lb_slice = lb;
        if current_z_l < 0.5
            lb_slice(2) = 0.15;  % floor A_outer — optimizer otherwise drives it to ~0
        end

        candidates = {
            initial_guess, ...
            [0.5, 0.5, 0.05, -1.35, 1.35, 0.2], ...
            [0.3, 0.3, 0.08, -1.35, 1.35, 0.8], ...
            [0.4, 0.4, 0.12, -1.35, 1.35, 0.5], ...
            [0.2, 0.6, 0.04, -1.35, 1.35, 0.3], ...
            [0.3, 0.3, 0.03, -1.35, 1.35, 1.0], ...
        };
        best_rmse = inf;
        fitted_params = initial_guess;
        for c = 1:length(candidates)
            try
                p_try = lsqcurvefit(near_field_model, candidates{c}, x_slice, u_slice, lb_slice, ub, options);
                r = sqrt(mean((u_slice - near_field_model(p_try, x_slice)).^2));
                if r < best_rmse
                    best_rmse = r;
                    fitted_params = p_try;
                end
            catch
            end
        end

        u_fitted_slice = near_field_model(fitted_params, x_slice);
        rmse = sqrt(mean((u_slice - u_fitted_slice).^2));
        z_sweep_results(i, :) = [current_z, fitted_params, rmse];

        initial_guess = fitted_params;
        if current_z_l < 0.5
            initial_guess(2) = 0.4;
            initial_guess(3) = 0.04;
            initial_guess(6) = 0.25;
        else
            initial_guess(3) = 0.08;
        end

        x_smooth = linspace(min(x_slice), max(x_slice), 200);
        u_fitted = near_field_model(fitted_params, x_smooth);
        plot3(x_smooth, repmat(current_z_l, 1, 200), u_fitted, 'b-', 'LineWidth', 1.5);
    end
end
hold off;
disp('Z-Sweep Complete!');

valid_results = z_sweep_results(z_sweep_results(:,1) ~= 0, :);
z_display = -valid_results(:,1) * scale;

% parameter trends
figure(2); clf;
subplot(2,1,1);
plot(z_display, valid_results(:,2), 'r-o', 'LineWidth', 2); hold on;
plot(z_display, valid_results(:,3), 'b-o', 'LineWidth', 2); hold off;
legend('A_{inner}', 'A_{outer}');
xlabel('Depth (z/l)'); ylabel('Amplitude (A)');
title('Decay of Wake Amplitude over Depth');
grid on;

subplot(2,1,2);
plot(z_display, valid_results(:,4), 'g-o', 'LineWidth', 2);
xlabel('Depth (z/l)'); ylabel('Spread (\sigma)');
title('Expansion of Wake Spread over Depth');
grid on;

% RMSE vs depth — normalized against peak amplitude to match Nika's normalization
figure(3); clf;

% peak amplitude per depth: max of the fitted model over the x domain
peak_amp = zeros(size(valid_results, 1), 1);
for i = 1:size(valid_results, 1)
    p = valid_results(i, 2:7);
    x_eval = linspace(-4, 4, 500);
    peak_amp(i) = max(near_field_model(p, x_eval));
end
rmse_normalized_pct = 100 * valid_results(:,8) ./ peak_amp;

plot(z_display, rmse_normalized_pct, 'k-o', 'LineWidth', 2);
xlabel('Depth (z/l)'); ylabel('RMSE / peak amplitude (%)');
title('Normalized Fit Error vs Depth (peak-normalized, matches Nika convention)');
yline(3.1, 'r--', "Nika global 3.1%", 'LabelVerticalAlignment', 'bottom');
yline(5.0, 'm--', "Nika at z/l=1.0 (~5%)", 'LabelVerticalAlignment', 'bottom');
grid on;

% summary stats — peak-normalized, valid region only (z/l >= 0.5)
valid_deep_mask = z_display >= 0.5;
fprintf('--- RMSE Summary (peak-normalized, matches Nika convention) ---\n');
fprintf('All depths:       %.1f%%\n', mean(rmse_normalized_pct));
fprintf('z/l >= 0.5 only: %.1f%%\n', mean(rmse_normalized_pct(valid_deep_mask)));
fprintf('Nika global ref:  3.1%%  (z/l = 1.0-3.5, peak-normalized)\n');
fprintf('Nika at z/l=1.0:  ~5%%  (per-depth, top of her fit domain)\n');

% overlap comparison: Bruno vs Nika at matched depths (z/l = 1.0 to 2.0)
% Bruno's data tops out at z/l ≈ 2.08, so rows 1-4 of nika_params_table are usable
overlap_depths = [1.0, 1.2, 1.5, 2.0];
overlap_mask = z_display >= 1.0;
overlap_results = valid_results(overlap_mask, :);
overlap_z = z_display(overlap_mask);

% ---- DIAGNOSTIC: data/model alignment at z/l = 1.0 ----
diag_target = 1.0;
[~, diag_ib] = min(abs(overlap_z - diag_target));
diag_zR      = overlap_results(diag_ib, 1);
[~, diag_in] = min(abs(nika_params_table(:,1) - diag_target));
diag_pn      = nika_params_table(diag_in, 2:6);

diag_sidx = abs(z_piv - diag_zR) < 0.05;
diag_x    = x_piv(diag_sidx);
diag_u    = u_piv(diag_sidx);
diag_ubg  = median(diag_u(diag_x < -3 | diag_x > 50));
diag_u    = diag_u - diag_ubg;

fprintf('\n--- DIAGNOSTIC at z/l = 1.0 ---\n');
fprintf('  z/R slice used : %.4f\n',  diag_zR);
fprintf('  x_piv range    : [%.4f, %.4f]\n', min(diag_x), max(diag_x));
fprintf('  u_piv range    : [%.4f, %.4f]  (post bg-sub)\n', min(diag_u), max(diag_u));
fprintf('  u_bg           : %.6f\n',  diag_ubg);
fprintf('  Nika params    : Ai=%.4f Ao=%.4f sig=%.4f Ri=%.4f Ro=%.4f\n', diag_pn);
fprintf('  nika_model at key x:\n');
for tx = [0, diag_pn(4), diag_pn(5), 2.0]
    fprintf('    x=%6.4f  -> nika=%.4f  (data near this x: %.4f)\n', ...
        tx, nika_model(diag_pn, tx), ...
        mean(diag_u(abs(diag_x - tx) < 0.1)));
end
diag_pb = overlap_results(diag_ib, 2:7);
fprintf('  Bruno params   : Ai=%.4f Ao=%.4f sig=%.4f Xl=%.4f Xr=%.4f R=%.4f\n', diag_pb);
fprintf('  Bruno inner peaks at: %.4f, %.4f\n', diag_pb(4)+diag_pb(6), diag_pb(5)-diag_pb(6));
fprintf('  Bruno outer peaks at: %.4f, %.4f\n', diag_pb(4)-diag_pb(6), diag_pb(5)+diag_pb(6));
% ---- END DIAGNOSTIC ----

fprintf('\n--- Per-depth RMSE in overlap region (Bruno vs Nika) ---\n');
fprintf('%-8s  %-12s  %-12s\n', 'z/l', 'Bruno RMSE%', 'Nika RMSE%');

figure(4); clf;
for k = 1:length(overlap_depths)
    target_z_l = overlap_depths(k);

    % find closest Bruno slice
    [~, idx_b] = min(abs(overlap_z - target_z_l));
    actual_z_R = overlap_results(idx_b, 1);

    % find matching Nika parameter row
    [~, idx_n] = min(abs(nika_params_table(:,1) - target_z_l));
    p_nika = nika_params_table(idx_n, 2:6);  % [Ai, Ao, sigma, Ri, Ro]

    slice_idx = abs(z_piv - actual_z_R) < 0.05;
    x_diag = x_piv(slice_idx);
    u_diag = u_piv(slice_idx);
    u_bg   = median(u_diag(x_diag < -3 | x_diag > 50));
    u_diag = u_diag - u_bg;

    p_bruno = overlap_results(idx_b, 2:7);
    x_smooth = linspace(min(x_diag), max(x_diag), 300);

    % Scale Nika's normalized output to physical units using the data peak.
    % Nika's Ai/Ao are normalized (~1.0 at ring peaks); u_diag is in m/s.
    peak_data = max(u_diag);
    u_fit_bruno = near_field_model(p_bruno, x_smooth);
    u_fit_nika  = nika_model(p_nika, x_smooth) * peak_data;

    % per-depth RMSE for both models against background-subtracted PIV
    rmse_b = sqrt(mean((u_diag - near_field_model(p_bruno, x_diag)).^2));
    rmse_n = sqrt(mean((u_diag - nika_model(p_nika, x_diag) * peak_data).^2));
    peak_u = max(u_fit_bruno);
    fprintf('%-8.1f  %-12.1f  %-12.1f\n', target_z_l, ...
        100*rmse_b/peak_u, 100*rmse_n/peak_u);

    subplot(2, 2, k);
    scatter(x_diag, u_diag, 10, 'k', 'filled'); hold on;
    plot(x_smooth, u_fit_bruno, 'b-',  'LineWidth', 2);
    plot(x_smooth, u_fit_nika,  'r--', 'LineWidth', 2); hold off;
    xlabel('x (normalized)'); ylabel('u (normalized)');
    title(sprintf('z/l = %.1f', target_z_l));
    legend('PIV data', 'Bruno fit', 'Nika model');
    grid on;
end
sgtitle('Bruno vs Nika in Overlap Region (z/l = 1.0 to 2.0)');

% diagnostic: 3 representative depths across Bruno's full domain
diag_z_l   = [0.4, 0.7, 1.2];
diag_labels = {'z/l = 0.4 (near-rotor)', 'z/l = 0.7 (mid)', 'z/l = 1.2 (overlap)'};

figure(5); clf;
for k = 1:3
    target_z_R = -(diag_z_l(k) / scale);
    [~, idx] = min(abs(valid_results(:,1) - target_z_R));
    actual_z_R = valid_results(idx, 1);

    slice_idx = abs(z_piv - actual_z_R) < 0.05;
    x_diag = x_piv(slice_idx);
    u_diag = u_piv(slice_idx);
    u_diag = u_diag - median(u_diag(x_diag < -3 | x_diag > 50));

    p = valid_results(idx, 2:7);
    x_smooth = linspace(min(x_diag), max(x_diag), 300);
    u_fit = near_field_model(p, x_smooth);

    subplot(1, 3, k);
    scatter(x_diag, u_diag, 10, 'k', 'filled'); hold on;
    plot(x_smooth, u_fit, 'b-', 'LineWidth', 2); hold off;
    xlabel('x (normalized)'); ylabel('u (normalized)');
    title(diag_labels{k});
    legend('PIV data', 'Bruno fit');
    grid on;
end
sgtitle('Bruno Near-Field Fit — Diagnostic Depths');

% --- Figure 6: PIV slices placed in 3D physical space ---
%
% The current PIV plane cuts at angle theta_cut from the drone's x-axis.
% For a Crazyflie in x-config the prop arms sit at 45/135/225/315 deg,
% so a cut ALONG a prop arm is theta_cut = 45 deg → gives the W-shape.
% A cut at theta_cut = 0 deg goes between prop pairs, through the hub.
%
% Change theta_cut_deg to whichever angle your laser sheet is actually at.
% Set new_cut_deg to the angle of the proposed second PIV run.
theta_cut_deg = 45;
new_cut_deg   = 135;   % proposed second cut: other prop arm diagonal
theta_cut = theta_cut_deg * pi/180;
new_cut   = new_cut_deg   * pi/180;

prop_disk_r = R_mm / l_mm;          % prop disk radius in l units (≈ 0.69 l)
arm_len_l   = 1.0;                  % arm length in l units (by definition)
prop_arm_angles_deg = [45, 135, 225, 315];  % Crazyflie x-config

figure(6); clf; hold on;
colormap(turbo);

depth_step = max(1, floor(num_depths / 15));
plot_depths_idx = 1:depth_step:num_depths;

for i = plot_depths_idx
    current_z = near_field_z(i);
    sidx = abs(z_piv - current_z) < 0.05;
    xs = x_piv(sidx);
    us = u_piv(sidx);
    us = us - median(us(xs < -3 | xs > 50));

    [xs, si] = sort(xs);
    us = us(si);

    z3 = -current_z * scale;          % z/l, positive downward
    x3 = xs(:)' * cos(theta_cut);
    y3 = xs(:)' * sin(theta_cut);
    N  = length(xs);

    % ribbon surface: two rows at z3 ± tiny offset so surf() renders color
    X_s = [x3; x3];
    Y_s = [y3; y3];
    Z_s = [(z3 - 0.02) * ones(1, N); (z3 + 0.02) * ones(1, N)];
    C_s = [us(:)'; us(:)'];
    surf(X_s, Y_s, Z_s, C_s, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
end

% propeller disk outlines at rotor plane (z=0)
t_circ = linspace(0, 2*pi, 60);
for pa = prop_arm_angles_deg
    cx = arm_len_l * cosd(pa);
    cy = arm_len_l * sind(pa);
    plot3(cx + prop_disk_r * cos(t_circ), ...
          cy + prop_disk_r * sin(t_circ), ...
          zeros(1, 60), 'k-', 'LineWidth', 2);
    plot3(cx, cy, 0, 'k+', 'MarkerSize', 10, 'LineWidth', 2);
end

% proposed new cut plane (translucent grey reference surface)
max_z_l = max(-near_field_z * scale);
s_span  = linspace(-4, 4, 2);
[S_new, Z_new] = meshgrid(s_span, [0, max_z_l]);
surf(S_new * cos(new_cut), S_new * sin(new_cut), Z_new, ...
     'FaceColor', [0.55 0.55 0.55], 'FaceAlpha', 0.15, 'EdgeColor', 'k', ...
     'LineStyle', '--');

xlabel('x (l)'); ylabel('y (l)'); zlabel('Depth z/l (positive down)');
title(sprintf('PIV data in 3D  |  Current cut %d°  |  Proposed cut %d° (grey)', ...
    theta_cut_deg, new_cut_deg));
cb = colorbar;
cb.Label.String = 'u (normalized by U_i)';
clim([0, max(u_piv(:))]);
view(35, 25);
grid on;
axis equal;
hold off;
