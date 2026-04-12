data_dir = 'static/';

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
% columns will be: [Z_depth, Amplitude, Sigma, X_left, X_right, Radius]
z_sweep_results = zeros(num_depths, 6);

% define 4-peak Gaussian sum model
near_field_model = @(p, x) p(1) * ( ...
    exp(-((x - (p(3) - p(5))).^2) / (2*p(2)^2)) + ... 
    exp(-((x - (p(3) + p(5))).^2) / (2*p(2)^2)) + ... 
    exp(-((x - (p(4) - p(5))).^2) / (2*p(2)^2)) + ... 
    exp(-((x - (p(4) + p(5))).^2) / (2*p(2)^2))   ... 
);

% turning 'Display' off so it doesn't spam the console
options = optimoptions('lsqcurvefit', 'Display', 'off');

% initial guesses and bounds
initial_guess = [0.3, 0.2, -1.35, 1.35, 1.0]; 
lb = [0.0, 0.05, -3.0,  0.5, 0.5]; 
ub = [1.0, 1.0,  -0.5,  3.0, 2.0];

disp('Starting Z-Sweep...');

% prepare 3D figure to watch the waterfall of curves form
figure(1); hold on;
xlabel('Normalized Radial Distance (x)');
ylabel('Depth (z/R)');
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
    
    % attempt a fit if there is sufficient data in this slice
    if length(x_slice) > 20
        % run curve fit
        fitted_params = lsqcurvefit(near_field_model, initial_guess, x_slice, u_slice, lb, ub, options);
        % store results
        z_sweep_results(i, :) = [current_z, fitted_params];
        % update the initial guess for the next deeper slice
        initial_guess = fitted_params;
        % plot fitted curve as a line in the 3D waterfall plot
        x_smooth = linspace(min(x_slice), max(x_slice), 200);
        u_fitted = near_field_model(fitted_params, x_smooth);
        % plot3 requires X, Y, Z vectors. We map our current_z to the Y axis.
        plot3(x_smooth, repmat(current_z, 1, 200), u_fitted, 'b-', 'LineWidth', 1.5);
    end
end
hold off;
disp('Z-Sweep Complete!');

% 2. plot the extracted parameter trends to see the physics in action
figure(2);

% subplot for amplitude decay
subplot(2,1,1);
% filter out rows where the fit skipped (amplitude = 0)
valid_results = z_sweep_results(z_sweep_results(:,1) ~= 0, :);
plot(valid_results(:,1), valid_results(:,2), 'r-o', 'LineWidth', 2);
xlabel('Depth (z/R)'); 
ylabel('Amplitude (A)');
title('Decay of Wake Amplitude over Depth');
grid on;

% subplot for wake expansion (spread)
subplot(2,1,2);
plot(valid_results(:,1), valid_results(:,3), 'g-o', 'LineWidth', 2);
xlabel('Depth (z/R)'); 
ylabel('Spread (\sigma)');
title('Expansion of Wake Spread over Depth');
grid on;

disp('Fitting continuous functions to A(z) and Sigma(z)...');

% Extract the valid arrays from the sweep
z_vals = valid_results(:, 1);
A_vals = valid_results(:, 2);
sigma_vals = valid_results(:, 3);

% --- 1. FIT THE AMPLITUDE TREND A(z) ---
% We use a Gaussian function to model the amplitude peak and decay
A_model = @(p, z) p(1) * exp(-((z - p(2)).^2) / (2*p(3)^2));
% Initial guess: Peak height ~0.3, Center ~ -0.7, Width ~ 0.5
A_guess = [0.3, -0.7, 0.5]; 
A_params = lsqcurvefit(A_model, A_guess, z_vals, A_vals, [], [], options);

% Create an anonymous function we can call at any Z depth
A_func = @(z) A_model(A_params, z);

% --- 2. FIT THE SPREAD TREND Sigma(z) ---
% A 2nd-degree polynomial (parabola) perfectly captures the dip and rise
sigma_params = polyfit(z_vals, sigma_vals, 2);
sigma_func = @(z) polyval(sigma_params, z);

disp('Generating 3D Volumetric Field...');

% --- 3. BUILD THE 3D REVOLVE ---
% Define the spatial grid for our 3D space
% X and Y cover the horizontal area, Z covers the depth
[X, Y, Z] = meshgrid(linspace(-4, 4, 100), linspace(-4, 4, 100), linspace(-3, 0, 100));

% Evaluate our dynamic A and Sigma across the entire 3D grid based on depth
A_grid = A_func(Z);
Sigma_grid = sigma_func(Z);

% Define rotor centers and radius (using parameters from your 2D model)
R = 1.0; 
x_left = -1.35; 
x_right = 1.35;
y_center = 0; % Assuming symmetric alignment along the Y axis

% Calculate Euclidean radial distances from the center of each rotor
r_left = sqrt((X - x_left).^2 + (Y - y_center).^2);
r_right = sqrt((X - x_right).^2 + (Y - y_center).^2);

% Apply the 4-peak model radially to create the 3D downwash field
% This generates the annular (ring) shapes under the left and right rotors
U_3D = A_grid .* ( ...
    exp(-((r_left - R).^2) ./ (2 * Sigma_grid.^2)) + ... 
    exp(-((r_left + R).^2) ./ (2 * Sigma_grid.^2)) + ... 
    exp(-((r_right - R).^2) ./ (2 * Sigma_grid.^2)) + ...
    exp(-((r_right + R).^2) ./ (2 * Sigma_grid.^2))      ...
);

% --- 4. VISUALIZE THE 3D WAKE ---
figure(3); hold on;

% Use isosurfaces to render 3D boundaries where the wind speed hits specific thresholds
% Inner core (fastest air)
p1 = patch(isosurface(X, Y, Z, U_3D, 0.2)); 
p1.FaceColor = 'red';
p1.EdgeColor = 'none';
p1.FaceAlpha = 0.8;

% Outer wake (slower air)
p2 = patch(isosurface(X, Y, Z, U_3D, 0.08)); 
p2.FaceColor = 'blue';
p2.EdgeColor = 'none';
p2.FaceAlpha = 0.3;

% Lighting and camera angles for 3D depth perception
camlight; 
lighting gouraud;
view(3);
xlabel('Lateral X (Normalized)'); 
ylabel('Lateral Y (Normalized)'); 
zlabel('Depth z/R');
title('3D Near-Field Quadrotor Wake Simulation');
grid on;
hold off;

disp('3D Render Complete!');