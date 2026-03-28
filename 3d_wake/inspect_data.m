% Quick data inspection
static_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'static');
load(fullfile(static_dir, 'x_piv.mat'));
load(fullfile(static_dir, 'z_piv.mat'));
load(fullfile(static_dir, 'u_piv.mat'));

fprintf('=== PIV Data Structure ===\n');
fprintf('x_piv size: %dx%d\n', size(x_piv,1), size(x_piv,2));
fprintf('z_piv size: %dx%d\n', size(z_piv,1), size(z_piv,2));
fprintf('u_piv size: %dx%d\n', size(u_piv,1), size(u_piv,2));
fprintf('\nValue ranges:\n');
fprintf('  x_piv: [%.3f, %.3f]\n', min(x_piv(:)), max(x_piv(:)));
fprintf('  z_piv: [%.3f, %.3f]\n', min(z_piv(:)), max(z_piv(:)));
fprintf('  u_piv: [%.3f, %.3f]\n', min(u_piv(:)), max(u_piv(:)));
fprintf('\nUnique values:\n');
fprintf('  x_piv: %d unique\n', length(unique(x_piv(:))));
fprintf('  z_piv: %d unique\n', length(unique(z_piv(:))));

% Check if data is symmetric (single plane) or full 2D
fprintf('\nChecking data structure:\n');
if exist(fullfile(static_dir, 'v_piv.mat'), 'file')
    load(fullfile(static_dir, 'v_piv.mat'));
    fprintf('  v_piv exists! Size: %dx%d\n', size(v_piv,1), size(v_piv,2));
end

% Sample a few points
fprintf('\nSample points (first 5):\n');
for i = 1:min(5, numel(x_piv))
    fprintf('  x=%.3f, z=%.3f, u=%.3f\n', x_piv(i), z_piv(i), u_piv(i));
end

% Check if it's a grid or scattered
fprintf('\nIs it gridded? ');
x_unique = unique(x_piv(:));
z_unique = unique(z_piv(:));
if length(x_unique) * length(z_unique) == numel(x_piv)
    fprintf('YES - appears to be a regular grid\n');
else
    fprintf('NO - appears to be scattered data\n');
end
