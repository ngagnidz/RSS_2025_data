data_dir = 'static/';

% unit conversion: Bruno's data is in z/R (rotor radius), Nika's model uses z/l (arm length)
% Crazyflie specs: prop radius R = 22.5 mm, arm length l = 32.5 mm
R_mm = 22.5;
l_mm = 32.5;
scale = R_mm / l_mm;  % multiply Bruno's z/R values by this to get z/l

% load velocity variables
load(fullfile(data_dir, 'x_piv.mat'));
load(fullfile(data_dir, 'z_piv.mat'));
load(fullfile(data_dir, 'u_piv.mat'));

% 1. find all unique z-depths in the data
% using uniquetol to handle tiny floating-point inconsistencies
unique_z = uniquetol(z_piv, 1e-4);

% filter to only sweep the near-field (e.g., from the rotors z=0 down to z=-3.0)
% exclude the far-field so the 4-peak model doesn't try to fit a single merged jet
near_field_z = unique_z(unique_z < 0 & unique_z >= -3.0);

num_depths = length(near_field_z);

% prepare an array to store our fitted parameters for each depth
% columns: [Z_depth, A_inner, A_outer, Sigma, X_left, X_right, Radius, RMSE]
z_sweep_results = zeros(num_depths, 8);

% 4-peak model with independent inner/outer amplitudes
% inner peaks: X_left+R and X_right-R (closer to quadrotor center)
% outer peaks: X_left-R and X_right+R (further from center)
% p = [A_inner, A_outer, sigma, X_left, X_right, R]
near_field_model = @(p, x) ...
    p(1) * (exp(-((x - (p(4) + p(6))).^2) / (2*p(3)^2)) + ...
            exp(-((x - (p(5) - p(6))).^2) / (2*p(3)^2))) + ...
    p(2) * (exp(-((x - (p(4) - p(6))).^2) / (2*p(3)^2)) + ...
            exp(-((x - (p(5) + p(6))).^2) / (2*p(3)^2)));

% turning 'Display' off so it doesn't spam the console
options = optimoptions('lsqcurvefit', 'Display', 'off');

% initial guesses and bounds: [A_inner, A_outer, sigma, X_left, X_right, R]
initial_guess = [0.3, 0.3, 0.08, -1.35, 1.35, 0.02];
lb = [0.0, 0.0, 0.02, -3.0,  0.5, 0.02];
ub = [1.0, 1.0, 0.47, -0.5,  3.0, 1.5];


disp('Starting Z-Sweep...');

% prepare 3D figure to watch the waterfall of curves form
figure(1); clf; hold on;
xlabel('Normalized Radial Distance (x)');
ylabel('Depth (z/l)');
zlabel('Normalized Downwash Velocity (u)');
title('3D Waterfall Plot of Near-Field Fits');
view(3); 
grid on;

for i = 1:num_depths
    current_z = near_field_z(i);
    
    % Slice the data for the current depth
    tolerance = 0.05;
    slice_idx = abs(z_piv - current_z) < tolerance;
    x_slice = x_piv(slice_idx);
    u_slice = u_piv(slice_idx);
    u_slice = u_slice - median(u_slice(x_slice < -3 | x_slice > 50));


    % attempt a fit if there is sufficient data in this slice
    if length(x_slice) > 20
        % multi-start: try several initial guesses and keep the best fit
        % lsqcurvefit is a local optimizer and gets stuck in local minima
        candidates = {
            initial_guess, ...
            [0.5, 0.5, 0.05, -1.35, 1.35, 0.2], ...
            [0.3, 0.3, 0.08, -1.35, 1.35, 0.8], ...
            [0.4, 0.4, 0.12, -1.35, 1.35, 0.5], ...
            [0.2, 0.6, 0.04, -1.35, 1.35, 0.3], ...  % high A_outer for shallow outer peaks
            [0.3, 0.3, 0.03, -1.35, 1.35, 1.0], ...  % very tight sigma for deep dip at z/l=1.2
        };
        best_rmse = inf;
        fitted_params = initial_guess;
        for c = 1:length(candidates)
            try
                p_try = lsqcurvefit(near_field_model, candidates{c}, x_slice, u_slice, lb, ub, options);
                r = sqrt(mean((u_slice - near_field_model(p_try, x_slice)).^2));
                if r < best_rmse
                    best_rmse = r;
                    fitted_params = p_try;
                end
            catch
            end
        end
        % compute RMSE against the raw PIV slice
        u_fitted_slice = near_field_model(fitted_params, x_slice);
        rmse = sqrt(mean((u_slice - u_fitted_slice).^2));
        % store results
        z_sweep_results(i, :) = [current_z, fitted_params, rmse];
        % warm-start positions and amplitudes from this fit, but reset sigma
        % so each slice finds its own sharpness rather than inheriting a
        % large sigma from deeper slices where the wake is already diffuse
        initial_guess = fitted_params;
        current_z_l = -current_z * scale;
        if current_z_l < 0.5
            % near-rotor: inner/outer rings haven't separated, force a
            % collapsed-peak start so the optimizer doesn't get stuck at R~1
            initial_guess(2) = 0.4;    % boost A_outer — it undershoots here
            initial_guess(3) = 0.04;   % sharp sigma
            initial_guess(6) = 0.25;   % small R so pairs nearly merge
        else
            initial_guess(3) = 0.08;
        end
        % plot fitted curve as a line in the 3D waterfall plot
        x_smooth = linspace(min(x_slice), max(x_slice), 200);
        u_fitted = near_field_model(fitted_params, x_smooth);
        % convert z to Nika's convention: z/l, positive downward
        current_z_l = -current_z * scale;
        plot3(x_smooth, repmat(current_z_l, 1, 200), u_fitted, 'b-', 'LineWidth', 1.5);
    end
end
hold off;
disp('Z-Sweep Complete!');

% 2. plot the extracted parameter trends to see the physics in action
figure(2); clf;

% filter out rows where the fit skipped (amplitude = 0)
valid_results = z_sweep_results(z_sweep_results(:,1) ~= 0, :);

% convert z column to Nika's convention: z/l, positive downward
z_display = -valid_results(:,1) * scale;

% subplot for amplitude decay (inner vs outer)
subplot(2,1,1);
plot(z_display, valid_results(:,2), 'r-o', 'LineWidth', 2); hold on;
plot(z_display, valid_results(:,3), 'b-o', 'LineWidth', 2); hold off;
legend('A_{inner}', 'A_{outer}');
xlabel('Depth (z/l)');
ylabel('Amplitude (A)');
title('Decay of Wake Amplitude over Depth');
grid on;

% subplot for wake expansion (spread)
subplot(2,1,2);
plot(z_display, valid_results(:,4), 'g-o', 'LineWidth', 2);
xlabel('Depth (z/l)');
ylabel('Spread (\sigma)');
title('Expansion of Wake Spread over Depth');
grid on;

% plot RMSE trend across depth
figure(3); clf;
plot(z_display, valid_results(:,8), 'k-o', 'LineWidth', 2);
xlabel('Depth (z/l)');
ylabel('RMSE');
title('Fit Error (RMSE) vs Depth');
grid on;
% overall RMSE across all depths
mean_amp_all = mean((valid_results(:,2) + valid_results(:,3)) / 2);
fprintf('Mean RMSE (all depths):       %.4f  |  Normalized: %.1f%%\n', ...
    mean(valid_results(:,8)), 100 * mean(valid_results(:,8)) / mean_amp_all);

% restrict summary stats to z/l >= 0.5 (physically valid region)
% z/l < 0.5 is near-rotor chaos where the 4-peak model is not expected to hold
valid_deep = valid_results(z_display >= 0.5, :);
mean_amp = mean((valid_deep(:,2) + valid_deep(:,3)) / 2);
fprintf('Mean RMSE (z/l >= 0.5 only): %.4f  |  Normalized: %.1f%%\n', ...
    mean(valid_deep(:,8)), 100 * mean(valid_deep(:,8)) / mean_amp);

% 3. diagnostic: overlay raw PIV vs fitted curve at 3 representative depths
% pick one high-error slice (~z/l=0.4), one mid (~z/l=0.7), one low-error (~z/l=1.2)
diag_z_l = [0.4, 0.7, 1.2];
diag_labels = {'z/l = 0.4 (high error)', 'z/l = 0.7 (mid error)', 'z/l = 1.2 (low error)'};

figure(4); clf;
for k = 1:3
    % convert back to Bruno's z/R convention to slice the data
    target_z_R = -(diag_z_l(k) / scale);
    [~, idx] = min(abs(valid_results(:,1) - target_z_R));
    actual_z_R = valid_results(idx, 1);

    % re-slice the raw PIV data at this depth (with same baseline subtraction as the fit)
    slice_idx = abs(z_piv - actual_z_R) < 0.05;
    x_diag = x_piv(slice_idx);
    u_diag = u_piv(slice_idx);
    u_diag = u_diag - median(u_diag(x_diag < -3 | x_diag > 50));

    % reconstruct fitted curve from stored parameters
    p = valid_results(idx, 2:7);
    x_smooth = linspace(min(x_diag), max(x_diag), 300);
    u_fit = near_field_model(p, x_smooth);

    subplot(1, 3, k);
    scatter(x_diag, u_diag, 10, 'k', 'filled'); hold on;
    plot(x_smooth, u_fit, 'r-', 'LineWidth', 2); hold off;
    xlabel('x (normalized)');
    ylabel('u (normalized)');
    title(diag_labels{k});
    legend('PIV data', 'Model fit');
    grid on;
end
sgtitle('Raw PIV vs Model Fit at Diagnostic Depths');
