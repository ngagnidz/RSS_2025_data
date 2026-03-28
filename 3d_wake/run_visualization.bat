@echo off
echo Starting MATLAB Quadrotor Wake Visualization...
cd /d "%~dp0"
matlab -r "plot_3d_wake_quadrotor"
