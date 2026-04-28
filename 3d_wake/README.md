# Quadcopter Wake Dynamics Analysis

This repository contains data and MATLAB scripts for analyzing the near-field and far-field downwash (downward wind) of a multi-rotor system. The data is based on a 2-rotor setup.

## Repository Structure

* **/Deprecated:** Old MATLAB files -> abstract cylinder wake plotting and air particle sims.
* **/Formulas Used:** Reference images for near-field equations.
* **/Related Images:** Visuals from DOI: 10.1007/s00348-024-03880-3.
* **/Results:** Output plots from the analysis phases.

## Variables & Setup

**System Layout:** 2 rotors symmetrically placed around a center origin.
`[ Rotor 1 ] --- Center (0,0) --- [ Rotor 2 ]`

**Primary PIV (Particle Image Velocimetry) Variables:**
* `x_piv`: Lateral position
* `z_piv`: Vertical position (depth)
* `u_piv`: Axial vel (downward)
* `v_piv`: Lateral vel

### The Z-Axis (Depth)
The origin (z = 0) is the geometric center of the rotor planes. 
* **+z:** Inflow region (above rotors).
* **-z:** Wake/downwash region (below rotors).
* **z = -0.1:** Just below the blades -> hard to measure due to "particle voids" from rotor obstruction.
* **z = -0.8:** Captures wake "infancy" before rotor flows blend -> looks like 4 separate rings (top view) or two upside-down M's (side view).

## Analysis Phases

### Phase 1: Static Near-Field
* **Script:** `near_field_plot.m`
* **Action:** Uses static vel data to plot the wake at a specific depth (e.g., z = -0.8) -> compares it against a 4-peak Gaussian model. 
* **Model:** Each rotor has an inner/outer tip, creating 2 velocity peaks per rotor (4 total).

### Phase 2: Z-Sweep & Spread
* **Script:** `near_field_z_loop_plot.m`
* **Action:** Iterates over the z-axis -> extracts wake amplitude and spread across depth -> plots normalized x-axis and vel.

### Phase 3: 3D Visualization (Roadmap)
Transitioning from 2D slices to a continuous 3D volume requires the following steps:

1.  **The Z-Sweep (Depth Mapping):** Wrap `lsqcurvefit` in a loop across all available static depth slices. Use `uniquetol` to clean z-levels and filter for the near-field (z < 0 to z >= -3.0). Warm-start the solver by passing the previous depth's parameters as the initial guess for the next.
2.  **Parameter Interpolation:** Plot optimized parameters against z. Fit curves to these trends to create continuous functions for Amplitude A(z) and Spread $\sigma$(z) at any depth.
3.  **Revolve into Cylindrical Space:** Convert the 1D linear distance in the Gaussian functions to a 2D Euclidean distance from the rotor center: $r = \sqrt{(x - x_{center})^2 + (y - y_{center})^2}$.
4.  **Full Superposition:** Apply the 3D Gaussian formulas to all rotors at their (x, y) coordinates. Sum them up -> blend with far-field jet scaling as they descend to get the full 3D scalar field.

## Core Fluid Dynamics Concepts

### Wake Amplitude (A)
The max downward speed of the air at the center of the jet.
* **z/R = 0 to -0.4:** Air is just accelerating -> low amplitude.
* **z/R ≈ -0.7 (The Peak):** Air is forced into a tighter column (vena contracta) -> speeds up to max vel.
* **z/R < -1.5 (Deep Down):** Fast-moving core rubs against still air -> turbulent exchange increases mass flow but decreases mean vel.

### Wake Spread ($\sigma$)
The width/thickness of the wake ring.
* **z/R ≈ 0:** Spread is approx 0.55 -> matches the physical width of the spinning blade.
* **z/R ≈ -0.6 (The Dip):** Spread shrinks to its min (~0.28) -> aligns with the amplitude peak as the wake contracts and thins out.
* **z/R < -1.6 (Deep Down):** Spread shoots up -> turbulent mixing causes the wake to expand outward. The individual rotor rings wash out and merge into a single circular wake structure (transitioning from near-field -> far-field).

https://docs.scipy.org/doc/scipy/reference/generated/scipy.interpolate.RectBivariateSpline.html