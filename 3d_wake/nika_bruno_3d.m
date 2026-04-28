% nika_bruno_3d.m
%
% 3D isosurface renders of Bruno's near-field and Nika's far-field wake models,
% styled after three_d_near_field.m.
%
% Bruno 3D: each of the 4 props (Crazyflie x-config) produces an annular ring
%   at radius R(z) from its center, with depth-varying amplitude and spread
%   interpolated from the per-depth z-sweep fits.
%
% Nika 3D: 2 concentric rings symmetric about the drone center, parameters
%   interpolated from her table. Already radially symmetric — no revolve needed.

data_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'static');

R_mm = 22.5;
l_mm = 32.5;
scale = R_mm / l_mm;

load(fullfile(data_dir, 'x_piv.mat'));
load(fullfile(data_dir, 'z_piv.mat'));
load(fullfile(data_dir, 'u_piv.mat'));

% -------------------------------------------------------------------------
% 1. Bruno z-sweep (same fit as nika_bruno_wake_model.m)
% -------------------------------------------------------------------------
unique_z     = uniquetol(z_piv, 1e-4);
near_field_z = unique_z(unique_z < 0 & unique_z >= -3.0);
num_depths   = length(near_field_z);

near_field_model = @(p, x) ...
    p(1) * (exp(-((x - (p(4) + p(6))).^2) / (2*p(3)^2)) + ...
            exp(-((x - (p(5) - p(6))).^2) / (2*p(3)^2))) + ...
    p(2) * (exp(-((x - (p(4) - p(6))).^2) / (2*p(3)^2)) + ...
            exp(-((x - (p(5) + p(6))).^2) / (2*p(3)^2)));

options       = optimoptions('lsqcurvefit', 'Display', 'off');
initial_guess = [0.3, 0.3, 0.08, -1.35, 1.35, 0.02];
lb = [0.0, 0.0, 0.02, -3.0, 0.5, 0.02];
ub = [1.0, 1.0, 0.47, -0.5, 3.0, 1.5];
z_sweep_results = zeros(num_depths, 8);

disp('Running Bruno z-sweep...');
for i = 1:num_depths
    current_z = near_field_z(i);
    sidx  = abs(z_piv - current_z) < 0.05;
    x_s   = x_piv(sidx);
    u_s   = u_piv(sidx);
    u_s   = u_s - median(u_s(x_s < -3 | x_s > 50));

    if length(x_s) > 20
        lb_s = lb;
        if -current_z * scale < 0.5, lb_s(2) = 0.15; end

        candidates = {initial_guess, ...
                      [0.5, 0.5, 0.05, -1.35, 1.35, 0.2], ...
                      [0.3, 0.3, 0.08, -1.35, 1.35, 0.8]};
        best_rmse = inf;  fp = initial_guess;
        for c = 1:length(candidates)
            try
                pt = lsqcurvefit(near_field_model, candidates{c}, x_s, u_s, lb_s, ub, options);
                r  = sqrt(mean((u_s - near_field_model(pt, x_s)).^2));
                if r < best_rmse, best_rmse = r; fp = pt; end
            catch; end
        end
        z_sweep_results(i,:) = [current_z, fp, best_rmse];
        initial_guess = fp;
    end
end
disp('Z-sweep complete.');

valid   = z_sweep_results(z_sweep_results(:,1) ~= 0, :);
z_l_fit = -valid(:,1) * scale;   % z/l, positive downward

% Interpolate per-depth params for arbitrary z/l queries
Ai_b  = @(z) max(interp1(z_l_fit, valid(:,2), z, 'linear', 'extrap'), 0);
Ao_b  = @(z) max(interp1(z_l_fit, valid(:,3), z, 'linear', 'extrap'), 0);
sig_b = @(z) max(interp1(z_l_fit, valid(:,4), z, 'linear', 'extrap'), 0.01);
R_b   = @(z) max(interp1(z_l_fit, valid(:,6), z, 'linear', 'extrap'), 0.01);

% -------------------------------------------------------------------------
% 2. Nika parameter table — interpolated
% -------------------------------------------------------------------------
nika_tbl = [
    1.0,  1.0167, 0.8762, 0.2081, 0.6615, 1.3386;
    1.2,  0.9539, 0.8380, 0.2280, 0.6427, 1.3287;
    1.5,  0.8669, 0.7837, 0.2577, 0.6145, 1.3138;
    2.0,  0.7392, 0.7010, 0.3074, 0.5676, 1.2891;
    2.5,  0.6303, 0.6270, 0.3570, 0.5206, 1.2643;
    3.0,  0.5375, 0.5608, 0.4067, 0.4737, 1.2396;
    3.5,  0.4583, 0.5016, 0.4564, 0.4267, 1.2148;
];
nz = nika_tbl(:,1);
Ai_n  = @(z) interp1(nz, nika_tbl(:,2), z, 'linear', 'extrap');
Ao_n  = @(z) interp1(nz, nika_tbl(:,3), z, 'linear', 'extrap');
sig_n = @(z) interp1(nz, nika_tbl(:,4), z, 'linear', 'extrap');
Ri_n  = @(z) interp1(nz, nika_tbl(:,5), z, 'linear', 'extrap');
Ro_n  = @(z) interp1(nz, nika_tbl(:,6), z, 'linear', 'extrap');

% -------------------------------------------------------------------------
% 3. 3D grids — separate domains for each model
% -------------------------------------------------------------------------
res = 90;   % grid resolution per axis; increase for smoother surfaces

% Bruno: near-field, z/l = 0 to 2.1
[Xb, Yb, Zb] = meshgrid(linspace(-3, 3, res), linspace(-3, 3, res), linspace(0.05, 2.1, res));

% Nika: far-field, z/l = 1.0 to 3.5
[Xn, Yn, Zn] = meshgrid(linspace(-3, 3, res), linspace(-3, 3, res), linspace(1.0, 3.5, res));

% -------------------------------------------------------------------------
% 4. Build Bruno's 3D field
%    Crazyflie x-config: 4 props at arm tips on the 45/135/225/315 deg arms.
%    Each prop produces an annular ring at radius R_b(z) from its center,
%    with averaged amplitude (Ai+Ao)/2 (inner/outer asymmetry is 2D; in 3D
%    the ring is treated as uniform around its circumference).
% -------------------------------------------------------------------------
prop_cx = cosd([45, 135, 225, 315]);  % prop centers in l units (arm length = 1l)
prop_cy = sind([45, 135, 225, 315]);

disp('Building Bruno 3D field...');
U_bruno = zeros(size(Xb));
for k = 1:4
    r_k   = sqrt((Xb - prop_cx(k)).^2 + (Yb - prop_cy(k)).^2);
    A_avg = (Ai_b(Zb) + Ao_b(Zb)) / 2;
    U_bruno = U_bruno + A_avg .* exp(-((r_k - R_b(Zb)).^2) ./ (2 * sig_b(Zb).^2));
end

% -------------------------------------------------------------------------
% 5. Build Nika's 3D field (already radially symmetric about drone center)
% -------------------------------------------------------------------------
disp('Building Nika 3D field...');
r_c    = sqrt(Xn.^2 + Yn.^2);
U_nika = Ai_n(Zn) .* exp(-((r_c - Ri_n(Zn)).^2) ./ (2 * sig_n(Zn).^2)) + ...
         Ao_n(Zn) .* exp(-((r_c - Ro_n(Zn)).^2) ./ (2 * sig_n(Zn).^2));

% -------------------------------------------------------------------------
% 6. Isosurface renders
% -------------------------------------------------------------------------
peak_b = max(U_bruno(:));
peak_n = max(U_nika(:));

% --- Figure 1: Bruno near-field ---
figure(1); clf; hold on;

p1 = patch(isosurface(Xb, Yb, Zb, U_bruno, 0.55 * peak_b));
p1.FaceColor = 'red';   p1.EdgeColor = 'none';  p1.FaceAlpha = 0.85;

p2 = patch(isosurface(Xb, Yb, Zb, U_bruno, 0.25 * peak_b));
p2.FaceColor = 'blue';  p2.EdgeColor = 'none';  p2.FaceAlpha = 0.25;

camlight;  lighting gouraud;
xlabel('x (l)');  ylabel('y (l)');  zlabel('Depth z/l (down)');
title('Bruno Near-Field Wake — 3D Isosurface');
legend([p1, p2], {'55% peak', '25% peak'}, 'Location', 'northeast');
view(35, 25);  grid on;  axis equal;
hold off;

% --- Figure 2: Nika far-field ---
figure(2); clf; hold on;

p3 = patch(isosurface(Xn, Yn, Zn, U_nika, 0.55 * peak_n));
p3.FaceColor = 'red';   p3.EdgeColor = 'none';  p3.FaceAlpha = 0.85;

p4 = patch(isosurface(Xn, Yn, Zn, U_nika, 0.25 * peak_n));
p4.FaceColor = 'blue';  p4.EdgeColor = 'none';  p4.FaceAlpha = 0.25;

camlight;  lighting gouraud;
xlabel('x (l)');  ylabel('y (l)');  zlabel('Depth z/l (down)');
title('Nika Far-Field Wake — 3D Isosurface');
legend([p3, p4], {'55% peak', '25% peak'}, 'Location', 'northeast');
view(35, 25);  grid on;  axis equal;
hold off;

% -------------------------------------------------------------------------
% 7. PIV data — revolve raw measurements into 3D
%    Assumes rotational symmetry: treats |x_piv| as radial distance r from
%    the drone center, then evaluates u(r, z) at every (x,y,z) grid point
%    via r = sqrt(x^2 + y^2).  No model, no fit — just measured data.
% -------------------------------------------------------------------------
disp('Building PIV data 3D field...');

% Collect background-subtracted (r, z/l, u) from every z-slice
n_total = length(z_piv);
r_pts   = zeros(n_total, 1);
z_pts   = zeros(n_total, 1);
u_pts   = zeros(n_total, 1);
fill_idx = 1;

for i = 1:num_depths
    current_z = near_field_z(i);
    sidx = abs(z_piv - current_z) < 0.05;
    xs   = x_piv(sidx);
    us   = u_piv(sidx);
    us   = us - median(us(xs < -3 | xs > 50));
    z_l  = -current_z * scale;          % z/l, positive downward
    n_i  = numel(xs);

    r_pts(fill_idx : fill_idx+n_i-1) = abs(xs(:));
    z_pts(fill_idx : fill_idx+n_i-1) = z_l;
    u_pts(fill_idx : fill_idx+n_i-1) = us(:);
    fill_idx = fill_idx + n_i;
end

% trim unused preallocated rows
r_pts = r_pts(1:fill_idx-1);
z_pts = z_pts(1:fill_idx-1);
u_pts = u_pts(1:fill_idx-1);

% Clamp negatives (background noise) before interpolating
u_pts = max(u_pts, 0);

% Scattered interpolant over the (r, z/l) half-plane
F_piv = scatteredInterpolant(r_pts, z_pts, u_pts, 'natural', 'none');

% Evaluate on the same near-field grid as Bruno
[Xd, Yd, Zd] = meshgrid(linspace(-3, 3, res), linspace(-3, 3, res), linspace(0.05, 2.1, res));
r_d    = sqrt(Xd.^2 + Yd.^2);
U_piv3d = F_piv(r_d(:), Zd(:));
U_piv3d = reshape(U_piv3d, size(Xd));
U_piv3d(isnan(U_piv3d)) = 0;   % outside convex hull → zero
U_piv3d = max(U_piv3d, 0);

% --- Figure 3: raw PIV data revolved ---
peak_d = max(U_piv3d(:));
figure(3); clf; hold on;

p5 = patch(isosurface(Xd, Yd, Zd, U_piv3d, 0.55 * peak_d));
p5.FaceColor = 'red';   p5.EdgeColor = 'none';  p5.FaceAlpha = 0.85;

p6 = patch(isosurface(Xd, Yd, Zd, U_piv3d, 0.25 * peak_d));
p6.FaceColor = 'blue';  p6.EdgeColor = 'none';  p6.FaceAlpha = 0.25;

camlight;  lighting gouraud;
xlabel('x (l)');  ylabel('y (l)');  zlabel('Depth z/l (down)');
title('PIV Data — Revolved 3D Isosurface (rotational symmetry assumed)');
legend([p5, p6], {'55% peak', '25% peak'}, 'Location', 'northeast');
view(35, 25);  grid on;  axis equal;
hold off;

disp('3D render complete.');
