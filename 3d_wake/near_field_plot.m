% Once the blue line successfully traces over the red M-shaped peaks, 
% the plot has mathematically defined a 1D line across the rotors at 
% a single depth. To evolve this into a 3D volumetric model.

data_dir = 'static/';
% load velocity field vars
load(fullfile(data_dir, 'x_piv.mat'));
load(fullfile(data_dir, 'z_piv.mat'));
load(fullfile(data_dir, 'u_piv.mat'));

% slice logic -> get indices near depth
target_depth = -0.8; 
tolerance = 0.05; 
slice_idx = abs(z_piv - target_depth) < tolerance;

x_slice = x_piv(slice_idx);
u_slice = u_piv(slice_idx);

% 4-peak Gaussian sum model
% p(1) = Amplitude (A)
% p(2) = Spread/Width (σ)
% p(3) = Distance to left rotor center (x_left)
% p(4) = Distance to right rotor center (x_right)
% p(5) = Rotor radius (R)
near_field_model = @(p, x) p(1) * ( ...
    exp(-((x - (p(3) - p(5))).^2) / (2*p(2)^2)) + ... 
    exp(-((x - (p(3) + p(5))).^2) / (2*p(2)^2)) + ... 
    exp(-((x - (p(4) - p(5))).^2) / (2*p(2)^2)) + ... 
    exp(-((x - (p(4) + p(5))).^2) / (2*p(2)^2))   ... 
);

% init guesses -> [Amp, Sig, X_L, X_R, Rad]
initial_guess = [0.0, 0, 0, 0, 0.0];
% Lower bound: Amplitude must be at least 0
lb = [0.0, 0.05, -3.0,  0.5, 0.5]; 
% Upper bound: Cap amplitude at 1.0 (since max data is ~0.35)
ub = [1.0, 1.0,  -0.5,  3.0, 2.0];

figure; hold on;

if ~isempty(x_slice)
    % run opti -> find best fit params
    options = optimoptions('lsqcurvefit', 'Display', 'iter');
    fitted_params = lsqcurvefit(near_field_model, initial_guess, x_slice, u_slice, lb, ub, options);

    % gen smooth x -> calc fitted line
    x_smooth = linspace(min(x_slice), max(x_slice), 200);
    u_fitted = near_field_model(fitted_params, x_smooth);

    % plot raw pts -> add fit line
    scatter(x_slice, u_slice, 'r.', 'DisplayName', 'Raw Data (u\_piv)');
    plot(x_smooth, u_fitted, 'b-', 'LineWidth', 2, 'DisplayName', 'Fitted Model');
    
    disp('Optimized Parameters:');
    disp(fitted_params);
else
    % no data found -> empty plot
    plot([], [], 'DisplayName', 'No data in slice');
end

% format plot -> colors & labels
ax = gca;
ax.XColor = 'b';
ax.YColor = 'b';
title(['Near-Field Wake Profile at z/R = ', num2str(target_depth)]);
xlabel('Normalized Radial Distance (x)');
ylabel('Normalized Downwash Velocity (u)');
legend('Location', 'best');
grid on; hold off;