## Structure of Root
# Deprecated
This has old matlab files that 
->matlab file that plotted the wake in a very abstracted manner using cyilinders with varying axial ranges
->matlab file to simulate air particles
# Formulas Used
Contains a picture of the formula that is used for the near field
# Related Images
Contains images from https://doi.org/10.1007/s00348-024-03880-3
# Results
Contains images from different phases

## Phases
# Phase 1
near_field_plot.m uses the data from /static (velocities) to plot wake + uses the guassian model (/formulas-used) to compare
# Phase 2
near_field_z_loop_plot.m used the data from /static to plot wake amplitude and wake spread over the spread
+
another model that shows the normalized x axis, normalized velocity + depth
vvvvvvvvv
iterates over the z axis for this information
# Phase 3
plots the wake over 3d dimensions
# Notes
this is data for 2 rotors 
0         0

   center
------------
0         0
------------

## Variables Being Used
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
The vertical axis points upward, against gravity. The origin (z = 0) is set at the geometric center of the four rotor planes. Therefore: Positive values (e.g., +1.0) are above the rotors (the inflow region). Negative values (e.g., -1.0) are below the rotors (the wake/downwash region). Correcting the specific values: A value of -1.0 : This is below the rotors. Specifically, it's a depth of one rotor radius beneath the rotor planes. At this height, the individual rotor wakes are starting to develop. A value of -0.1: This is just below the rotors. Because it's a smaller negative number, it's much closer to the physical blades than -1.0. This region is often difficult to measure because the rotors obstruct the cameras, creating "particle voids".

# More on z=0.8
So 0.8 is right under the rotors and it captures early data from the rotors? with it sort of look like an upside down M for each rotor from the side view (depening on how you look at it) and four rings from the top view

Exactly. You’ve visualized the fluid dynamics here perfectly. At z/R = -0.8, you are catching the "infancy" of the wake before the different rotor flows have a chance to blend together.

at -0.8 z/R, wake is just right under the rotor. the view of the air would be like four seperate rings from the top view and like two upside down M's from the side view

## Roadmap to 3D (before code)
1. The Z-Sweep (Depth Mapping)
Currently, the script (near_field_plot.m) only looks at z/R = -0.8. It needs to wrap lsqcurvefit logic in a for loop that iterates through every available depth slice in the static data. Store the optimized p array (Amplitude, Spread, etc.) for every z level

2. Parameter Interpolation
Once there are optimized parameters for every depth, plot them against z. There will be clear trends (for example, as z gets deeper, Amplitude A(z) will decrease and Spread sigma(z) will increase). These will need to be curve-fitted create continuous functions that dictate how the wake behaves at any arbitrary depth

3. Revolve into Cylindrical Space
The current equation assumes x is a straight line. To make it a 3D volume (a cone/cylinder), it will need to be replaced with the linear 1D distance (x - x_center) in the Gaussian functions with the 2D Euclidean distance from the rotor center: r = sqrt{(x - x_center)^2 + (y - y_center)^2}

4. Full Superposition
Apply the revolved 3D Gaussian formulas to all four rotors at their respective (x, y) coordinates. Sum together, blend them with the far-field jet scaling as they descend -> will have a full continuous 3D scalar field of the quadcopter wake

## Roadmap to 3D (after code)
# Baby Version
Imagine you have a toy drone flying above you. When it spins its blades, it pushes air downward. That downward wind is called downwash. Now imagine you could take a photograph of that wind at different heights below the drone — like taking slices of a layered cake.
What the code does, step by step:

1.It loads a map of the wind. Someone already measured where the air is moving and how fast, at lots of different spots. The code loads those measurements (x = left-right position, z = how far below the drone, u = wind speed).
2.It picks only the slices close to the drone (not too far away, where the wind gets all mushed together).
3.It traces a fingerprint shape onto each slice. The drone has two rotors, and each rotor has an inner edge and an outer edge, so the wind makes 4 peaks — like 4 bumps in a hill. The code draws a curvy line (a model) that best matches those 4 bumps.
->Example: Imagine looking at a slice of wind at z = -1.0 (1 rotor-length below the drone). The wind is calm in the middle, strong at 4 spots (the rotor edges), and calm again outside. The model tries to draw exactly that shape.
4.It does this at every height — sweeping from just under the drone all the way down.
5.It makes two pictures:
->A 3D "waterfall" showing all the fitted curves stacked up
->Graphs showing how the wind weakens and spreads out as you go deeper

# Technical
Data loading & depth selection. PIV data is loaded as 2D grids. uniquetol with tolerance 1e-4 collapses floating-point duplicates into clean discrete z-levels. The near-field filter (z < 0 & z >= -3.0) isolates the rotor-proximate wake where the 4-lobe structure is still distinct — in the far field the lobes merge into a single jet and the model would over-constrain.

The 4-peak Gaussian model. For a drone with two rotors (centered at X_left and X_right), each rotor produces two velocity peaks — one at its inner tip, one at its outer tip, separated by the rotor radius R. So the four peak locations are X_left ± R and X_right ± R. All four share the same amplitude A and width σ, which is a physically motivated simplification (symmetric rotor geometry).

Example: If X_left = -1.35, X_right = 1.35, R = 1.0, the peaks appear at x = -2.35, -0.35, +0.35, +2.35.

lsqcurvefit with warm-starting. The solver minimizes the sum of squared residuals between the model and the measured u-slice. Crucially, after each successful fit, initial_guess = fitted_params — this warm-starts the next depth level using the previous solution. This is a practical trick: adjacent z-slices should have smoothly evolving parameters, so the previous fit is a better starting point than a fixed guess, and it dramatically reduces convergence failures.

Bounds: lb and ub constrain the solution to physically reasonable ranges — amplitude between 0–1 (normalized velocity), sigma between 0.05–1.0 (not a spike or a flat blob), rotor centers within the expected lateral extent, and radius between 0.5–2.0 rotor radii.

The waterfall plot uses plot3 mapping (x, z, u_fitted) — the z-coordinate becomes the Y-axis depth dimension, producing a stacked set of fitted curves you can view in 3D.

Post-sweep analysis filters out rows where the fit was skipped (amplitude = 0 sentinel) and plots amplitude decay and sigma growth vs. depth — these encode the physics of wake diffusion: the jet weakens and spreads as it descends due to turbulent mixing.

## What is Euclidean?
Euclidean refers to the foundational, flat-surface geometry or mathematical principles developed by the ancient Greek mathematician Euclid

## What is Jet Scaling?
The engineering process of adapting jet engine technology, performance, or acoustic characteristics from one size to another (e.g., downsizing for UAVs or upsizing for hypersonic craft) while maintaining similarity in performance, flow, and noise, often using dimensionless scaling factors. it's crucial for testing scale models to predict full-scale jet noise and for designing efficient propulsion for smaller drones.

# Wake Amplitude (A)
What is Wake Amplitude (A)? You guessed that amplitude might be air compression, but it's maximum downward speed of the air at the center of the rotor's downward jet. 
->Near the Surface (z/R = 0 to -0.4 (approx)): Right at the rotor blades, the air is just starting to be accelerated. The speed (amplitude) is relatively low.
->The Peak (z/R = -0.7): As air is sucked through the rotors, it's forced into a tighter column (a phenomenon in fluid dynamics called the vena contracta). Because the column of air gets narrower, the air has to speed up, reaching its absolute maximum downward velocity (peak of ~0.28).
->Deep Down (z/R < -1.5): The air begins to slow down significantly. Why? Because the fast-moving core wake rubs against the still air in the room. This creates "turbulent exchange, increasing the total mass flow while decreasing the mean velocity at a constant net momentum". Basically, the wake loses its downward speed as it drags more surrounding air along with it.

# Wake Spread (sigma)?
What is Wake Spread (sigma)? Spread is the width/thickness of the wake ring. You correctly noted that the air starts spreading "all over the place" lower down, and here is exactly how that plays out:
->Near the Surface (z/R = 0 (approx)): The spread is ~0.55. This makes sense because the air is being pushed down across the physical width of the spinning rotor blade. ->The Dip (z/R = -0.6 (approx)): The spread shrinks to its minimum (~0.28). This aligns perfectly with the Amplitude peak! As the air speeds up, the wake contracts and gets very thin and concentrated.
->Deep Down (z/R < -1.6): The spread shoots up to 1.0. As that turbulent mixing happens, the wake expands outward. In fact, the script hitting exactly 1.0 means it hit the upper bound (ub = 1.0) that was set in MATLAB. At this depth, the individual annular structures of the rotors are washing out and starting to merge into a single circular wake structure -> leaving the "Near-Field" and entering "Far-Field"

## What is Downwash
Imagine you have a toy drone flying above you. When it spins its blades, it pushes air downward. That downward wind is called downwash. 