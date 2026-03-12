%Helper script to plot data
%Created by: Anoop Kiran, Brown University (anoop_kiran@brown.edu)
%Created on: April 27, 2025
close all; clear all; clc

%% Preprocessing
%load all mat files, ensure that all the mat files are in current directory
cd(fileparts(mfilename('fullpath'))); %ensure MATLAB is in the script's directory
s = what; %seek current directory
matfiles = s.mat %lists all the mat files in current directory
for a=1:numel(matfiles)
load(char(matfiles(a)))
end

%% Forces, Moments, and respective standard deviations
%force and standard deviations for lower quadrotor
figure()
contourf(x_l, z_l, lower_F_W, 500, 'EdgeColor', 'none');
hold on;
% Reverse the Y-axis direction
set(gca, 'YDir', 'reverse');
c = colorbar();
ylabel(c,'$\bar{F_{z}}/W$', 'Interpreter', 'latex', 'FontSize',20,'Rotation',270)
c.Limits = [0.65 1.0000];
xlim([0, 8]);
ylim([4, 30]);
xticks(0:2:8);
yticks([4 10 15 20 25 30]);
xlabel('Horizontal separation, ${\Delta x}/l$','Interpreter', 'latex', 'FontSize', 20);
ylabel('Vertical separation, ${\Delta z}/l$', 'Interpreter', 'latex', 'FontSize', 20)
set(gca,'YDir','reverse');

figure()
contourf(x_l, z_l, lower_Fstd_W, 500, 'EdgeColor', 'none');
set(gca,'YDir','reverse');
d = colorbar();
ylabel(d,'$F_{z}^\prime/W$', 'Interpreter', 'latex', 'FontSize',20,'Rotation',270)
d.Limits = [0.009, 0.021];
d.Ticks = linspace(0.009, 0.021, 7);
xlim([0, 8]); ylim([4, 30]);
xticks(0:2:8);
yticks([4 10 15 20 25 30]);
xlabel('Horizontal separation, ${\Delta x}/l$','Interpreter', 'latex', 'FontSize', 20);
ylabel('Vertical separation, ${\Delta z}/l$', 'Interpreter', 'latex','FontSize', 20)


%% Velocity
% axial velocity plot script
figure()
contourf(x_piv, z_piv, u_piv, 600, 'linestyle', 'none');
set(gca, 'YDir', 'reverse');  % Reverse the y-axis direction (negative z values above drone)
cb = colorbar;
clim([0, 1]) % colorbar limits between 0 and 1
xlabel('$x/l$', 'Interpreter', 'latex', 'FontSize', 20)
ylabel('$z/l$', 'Interpreter', 'latex', 'FontSize', 20)
ylabel(cb, '$\bar{u}/U_{i}$', 'FontSize', 20, 'Rotation', 270, 'Interpreter', 'latex');

% lateral velocity plot script
figure()
contourf(x_piv, z_piv, v_piv, 600, 'linestyle', 'none');
set(gca, 'YDir', 'reverse');  % Reverse the y-axis direction (negative z values above drone)
cb = colorbar;
clim([-0.20, 0.20])
xlabel('$x/l$', 'Interpreter', 'latex', 'FontSize', 20)
ylabel('$z/l$', 'Interpreter', 'latex', 'FontSize', 20)
ylabel(cb, '$\bar{v}/U_{i}$', 'FontSize', 14, 'Rotation', 270, 'Interpreter', 'latex');