RSS paper: Influence of Static and Dynamic Downwash Interactions on Multi-Quadrotor Systems
Created by: Anoop Kiran
Creation date: April 18, 2025
Last update: April 29, 2025

Objective: The following folder contains static data for Forces and Moments of an interacting pair of quadrotors, and Velocity field below a single quadrotor over several length scales. 

Nomenclature: 
Force (thrust, z direction) & Moment (pitch, y direction) data (Figs. 5 & 6 in paper) averaged over three trials
l: arm length in mm (32.5 mm) 
x_l: x coordinate values normalized by characteristic length scale, l
z_l: z coordinate values normalized by characteristic length scale, l
lower_F_W: Average Force measurements experienced by the lower quadrotor, normalized by the weight, W
lower_Fstd_W: Standard deviation over three trials for force experienced by the lower quadrotor, normalized by the weight, W
lower_M_Wl: Average Moment measurements experienced by the lower quadrotor normalized by the weight*characteristic length scale, W*l
lower_Mstd_Wl: Standard deviation over three trials for moment experienced by the lower quadrotor, normalized by the weight*characteristic length scale, W*l
upper_F_W: Average Force measurements experienced by the upper quadrotor, normalized by the weight, W
upper_Fstd_W: Standard deviation over three trials for force experienced by the upper quadrotor, normalized by the weight, W
upper_M_Wl: Average Moment measurements experienced by the upper quadrotor, normalized by the weight*characteristic length scale, W*l
upper_Mstd_Wl: Standard deviation over three trials for moment experienced by the upper quadrotor, normalized by the weight*characteristic length scale, W*l
Note: the x and z value range are same across both upper and lower Crazyflies 

x_piv: x coordinate values normalized by characteristic length scale, l
z_piv: z coordinate values normalized by characteristic length scale, l
u_piv: Average axial velocity values normalized by the induced velocity, U_i
v_piv: Average lateral velocity values normalized by the induced velocity, U_i

%%% Data for Force & Moment experienced by interacting quadrotors: upper and lower (Magnitude & standard dev.) %%%
The force in z axis is plotted on a contour map with horizontal separation between quadrotors (\delta x) on x axis
and vertical separation (\delta z) between quadrotors on the y axis, while the color range of the contour map 
indicates the change in thrust range across varying separations. The script, plot_data.m script plots the force and 
its standard deviation experienced by the lower quadrotor. However, the corresponding moments, and its standard deviations
experienced by both the upper quadrotor and lower quadrotor can be plotted based on similar approach provided by the 
sample script

%%% Data for axial (u) and lateral (v) velocity below a single quadrotor %%%
Averaged axial velocity (u) and lateral velocity (v)  are plotted under the velocity section of this script. Similar 
to the sample script for forces and moments above; the x-axis of the plots indicate the normalized x coordinate range, 
while the y-axis of the plots indicate the normalized z coordinate range. The contour of these plots indicate the 
value of velocities.a