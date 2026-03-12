RSS paper: Influence of Static and Dynamic Downwash Interactions on Multi-Quadrotor Systems
Created by: Anoop Kiran
Creation date: July 14, 2025


Objective: This folder contains dynamic interaction data for Forces and Moments of an interacting pair of quadrotors

Each folder here contains the dynamic_data.mat and static_data.mat data from the 4 cases that we tested. They are automatically loaded and plotted when the plot_script.m is run. The dynamic_data.mat file contains 4 columns categorized as case, distance (normalized separation, delta z/l), thrust (normalized thrust, Fz/W) or moment (normalized moment, My/Wl), and velocity (normalized velocity delta zdot/U_i). Note that W, l, U_i are constants defined in the paper. The case column is named: CF{hover_thrust}_SD{delta z_min}_F{frequency}_A{amplitude} based on the combination of these parameters that are being varied for the dynamic interaction ranges considered.   

1)twodtest-offset-force: Fz measurements in horizontal offset configuration (delta x/l=2)
2)twodtest-offset-moment: My measurements in horizontal offset configuration (delta x/l=2)
3)twodtest-stacked-force: Fz measurements in vertically aligned stacked configuration (delta x/l=0)
4)twodtest-stacked-moment: My measurements in in vertically aligned stacked configuration (delta x/l=0)