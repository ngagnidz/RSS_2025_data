% Check what v_piv represents
static_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'static');
load(fullfile(static_dir, 'x_piv.mat'));
load(fullfile(static_dir, 'v_piv.mat'));

fprintf('v_piv range: [%.3f, %.3f]\n', min(v_piv(:)), max(v_piv(:)));
fprintf('v_piv unique values: %d\n', length(unique(v_piv(:))));

% If v_piv varies similarly to x_piv, it's a coordinate
% If it's mostly small values around 0, it's velocity
fprintf('\nSample v_piv values (first 10):\n');
for i = 1:min(10, numel(v_piv))
    fprintf('  x=%.3f, v=%.3f\n', x_piv(i), v_piv(i));
end

% Check if it varies per column
fprintf('\nColumn variation check:\n');
fprintf('  Column 1 v_piv range: [%.3f, %.3f]\n', min(v_piv(:,1)), max(v_piv(:,1)));
fprintf('  Column 270 v_piv range: [%.3f, %.3f]\n', min(v_piv(:,270)), max(v_piv(:,270)));

% Check mean along dimensions
fprintf('\nMean v_piv along rows: %.3f (std: %.3f)\n', mean(mean(v_piv,2)), std(mean(v_piv,2)));
fprintf('Mean v_piv along cols: %.3f (std: %.3f)\n', mean(mean(v_piv,1)), std(mean(v_piv,1)));
