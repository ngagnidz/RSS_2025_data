## Structure of Root
# Deprecated
This has old matlab files that 
->matlab file that plotted the wake in a very abstracted manner using cyilinders with varying axial ranges
->matlab file to simulate air particles

# Variables Being Used
x_piv, z_piv, u_piv (axial velocity), and v_piv (lateral velocity)

## What is a sigmoid curve? 
a functon that maps any real valued numbers between 0 and 1

## Info on Slicing
% resulting slice_idx will be an array of the same size as z_piv, containing:
% 1 (true) where the z_piv value is between -0.85 and -0.75.
% 0 (false) for all other values.
% for the tolerance being 0.05 and the target depth being -0.8
slice_idx = abs(z_piv - target_depth) < tolerance;

## Information on Z (looking at z=-1,1,-0.1,etc)
The vertical axis points upward, against gravity. The origin (z = 0) is set at the geometric center of the four rotor planes. Therefore: Positive values (e.g., +1.0) are above the rotors (the inflow region). Negative values (e.g., -1.0) are below the rotors (the wake/downwash region). Correcting the specific values: A value of -1.0 : This is below the rotors. Specifically, it is a depth of one rotor radius beneath the rotor planes. At this height, the individual rotor wakes are starting to develop. A value of -0.1: This is just below the rotors. Because it is a smaller negative number, it is much closer to the physical blades than -1.0. This region is often difficult to measure because the rotors obstruct the cameras, creating "particle voids".

# More on z=0.8
So 0.8 is right under the rotors and it captures early data from the rotors? with it sort of look like an upside down M for each rotor from the side view (depening on how you look at it) and four rings from the top view

Exactly. You’ve visualized the fluid dynamics here perfectly. At z/R = -0.8, you are catching the "infancy" of the wake before the different rotor flows have a chance to blend together.

at -0.8 z/R, wake is just right under the rotor. the view of the air would be like four seperate rings from the top view and like two upside down M's from the side view

## Roadmap to 3D

1. The Z-Sweep (Depth Mapping)
Currently, the script (near_field_plot.m) only looks at z/R = -0.8. It needs to wrap lsqcurvefit logic in a for loop that iterates through every available depth slice in the static data. Store the optimized p array (Amplitude, Spread, etc.) for every z level

2. Parameter Interpolation
Once there are optimized parameters for every depth, plot them against z. There will be clear trends (for example, as z gets deeper, Amplitude A(z) will decrease and Spread sigma(z) will increase). These will need to be curve-fitted create continuous functions that dictate how the wake behaves at any arbitrary depth

3. Revolve into Cylindrical Space
The current equation assumes x is a straight line. To make it a 3D volume (a cone/cylinder), it will need to be replaced with the linear 1D distance (x - x_center) in the Gaussian functions with the 2D Euclidean distance from the rotor center: r = sqrt{(x - x_center)^2 + (y - y_center)^2}

4. Full Superposition
Apply the revolved 3D Gaussian formulas to all four rotors at their respective (x, y) coordinates. Sum together, blend them with the far-field jet scaling as they descend -> will have a full continuous 3D scalar field of the quadcopter wake

## What is Euclidean?
Euclidean refers to the foundational, flat-surface geometry or mathematical principles developed by the ancient Greek mathematician Euclid

## What is Jet Scaling?
The engineering process of adapting jet engine technology, performance, or acoustic characteristics from one size to another (e.g., downsizing for UAVs or upsizing for hypersonic craft) while maintaining similarity in performance, flow, and noise, often using dimensionless scaling factors. It is crucial for testing scale models to predict full-scale jet noise and for designing efficient propulsion for smaller drones.