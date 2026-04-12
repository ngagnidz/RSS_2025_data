"""
Near-Field Wake Profile Visualizer
===================================
Replicates and fixes the MATLAB script with an interactive matplotlib GUI.
Sliders let you adjust target_depth, tolerance, and all 5 Gaussian model
parameters in real time.

Requirements (Apple Silicon / macOS):
    pip install numpy scipy matplotlib

Run:
    python wake_profile.py

NOTE: The script generates synthetic PIV data that matches the structure of
your x_piv / z_piv / u_piv .mat files.  To load your REAL data, see the
section labelled  >>>  LOAD YOUR DATA HERE  <<<  below.
"""

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.widgets import Slider, Button
from scipy.io import loadmat
from scipy.optimize import least_squares

# ─────────────────────────────────────────────────────────────────────────────
#  >>>  LOAD YOUR DATA HERE  <<<
#
#  Option A – synthetic data (default, so you can run immediately)
#  Option B – your real .mat files (uncomment and point to your folder)
# ─────────────────────────────────────────────────────────────────────────────

USE_REAL_DATA = False          # flip to True once you have your .mat files

if USE_REAL_DATA:
    data_dir = "static/"       # change this path as needed
    x_piv = loadmat(data_dir + "x_piv.mat")["x_piv"].ravel()
    z_piv = loadmat(data_dir + "z_piv.mat")["z_piv"].ravel()
    u_piv = loadmat(data_dir + "u_piv.mat")["u_piv"].ravel()
else:
    # ── Synthetic data that mimics the structure of your PIV arrays ──────────
    rng = np.random.default_rng(42)
    N = 600
    x_piv = rng.uniform(-2.5, 2.5, N)
    z_piv = rng.uniform(-2.5, 0.0, N)

    def _true_model(x):
        A, sig, xl, xr, R = -2.0, 0.18, -1.35, 1.35, 1.0
        return A * (
            np.exp(-((x - (xl - R)) ** 2) / (2 * sig**2))
            + np.exp(-((x - (xl + R)) ** 2) / (2 * sig**2))
            + np.exp(-((x - (xr - R)) ** 2) / (2 * sig**2))
            + np.exp(-((x - (xr + R)) ** 2) / (2 * sig**2))
        )

    u_piv = _true_model(x_piv) + rng.normal(0, 0.12, N)

# ─────────────────────────────────────────────────────────────────────────────
#  Gaussian model  (same formula as your MATLAB near_field_model)
#  p = [Amplitude, Sigma, X_left, X_right, Radius]
# ─────────────────────────────────────────────────────────────────────────────

def gauss_model(p, x):
    A, sig, xl, xr, R = p
    return A * (
        np.exp(-((x - (xl - R)) ** 2) / (2 * sig**2))
        + np.exp(-((x - (xl + R)) ** 2) / (2 * sig**2))
        + np.exp(-((x - (xr - R)) ** 2) / (2 * sig**2))
        + np.exp(-((x - (xr + R)) ** 2) / (2 * sig**2))
    )

# ─────────────────────────────────────────────────────────────────────────────
#  Initial slider values  (matching your MATLAB initial_guess)
# ─────────────────────────────────────────────────────────────────────────────

INIT = dict(
    target_depth = -0.80,
    tolerance    =  0.05,
    amplitude    = -2.00,
    sigma        =  0.20,
    x_left       = -1.35,
    x_right      =  1.35,
    radius       =  1.00,
)

# Bounds used for curve fitting  [lb, ub]
BOUNDS = (
    [-5.0, 0.05, -3.0,  0.5, 0.5],
    [ 0.0, 1.00, -0.5,  3.0, 2.0],
)

# ─────────────────────────────────────────────────────────────────────────────
#  Figure layout
# ─────────────────────────────────────────────────────────────────────────────

plt.style.use("dark_background")

fig = plt.figure(figsize=(14, 9), facecolor="#0d0f14")
fig.canvas.manager.set_window_title("Near-Field Wake Profile — Interactive")

# Main area: left = controls column, right = plots column
outer = gridspec.GridSpec(1, 2, figure=fig, width_ratios=[1, 2.6],
                          left=0.03, right=0.97, top=0.95, bottom=0.04,
                          wspace=0.06)

# Plots column: stacked vertically
plot_gs = gridspec.GridSpecFromSubplotSpec(
    2, 1, subplot_spec=outer[1], hspace=0.38, height_ratios=[2.2, 1]
)

ax_main  = fig.add_subplot(plot_gs[0])   # wake profile
ax_slice = fig.add_subplot(plot_gs[1])   # z distribution

# Controls column: we will place sliders manually inside this area
ctrl_ax = fig.add_subplot(outer[0])
ctrl_ax.set_visible(False)               # invisible host — sliders float above

# ─────────────────────────────────────────────────────────────────────────────
#  Style helpers
# ─────────────────────────────────────────────────────────────────────────────

ACCENT  = "#4fa3e8"
RED     = "#e8604a"
DIM     = "#8a8fa8"
PANEL   = "#161820"
GRID_C  = "#2a2d3a"

for ax in (ax_main, ax_slice):
    ax.set_facecolor(PANEL)
    ax.tick_params(colors=DIM, labelsize=8)
    ax.spines[:].set_color(GRID_C)
    for spine in ax.spines.values():
        spine.set_linewidth(0.6)
    ax.grid(True, color=GRID_C, linewidth=0.5, linestyle="--", alpha=0.7)

# ─────────────────────────────────────────────────────────────────────────────
#  Slider factory
# ─────────────────────────────────────────────────────────────────────────────

slider_specs = [
    # (label,           key,           vmin,  vmax,  step,   fmt)
    ("Target depth",    "target_depth", -2.5,   0.0, 0.05, "{:.2f}"),
    ("Tolerance ±",     "tolerance",    0.01,   0.5, 0.01, "{:.2f}"),
    ("Amplitude (A)",   "amplitude",   -5.0,  -0.1, 0.05, "{:.2f}"),
    ("Sigma (σ)",       "sigma",        0.05,   1.0, 0.01, "{:.2f}"),
    ("Left center xL",  "x_left",      -3.0,  -0.1, 0.05, "{:.2f}"),
    ("Right center xR", "x_right",      0.1,   3.0, 0.05, "{:.2f}"),
    ("Rotor radius R",  "radius",       0.5,   2.0, 0.05, "{:.2f}"),
]

# Position sliders inside the left column
# fig.add_axes uses [left, bottom, width, height] in figure coordinates
ctrl_left   = 0.04
ctrl_width  = 0.24
slider_h    = 0.028
top_start   = 0.88
gap         = 0.087

sliders = {}
slider_axes = []

for i, (label, key, vmin, vmax, step, fmt) in enumerate(slider_specs):
    bottom = top_start - i * gap
    # label above the track
    fig.text(ctrl_left, bottom + slider_h + 0.004, label,
             color=DIM, fontsize=8.5, va="bottom")
    sax = fig.add_axes([ctrl_left, bottom, ctrl_width, slider_h],
                       facecolor="#1e2130")
    sl  = Slider(sax, "", vmin, vmax,
                 valinit=INIT[key], valstep=step,
                 color=ACCENT, track_color="#2a2d3a")
    sl.valtext.set_color(ACCENT)
    sl.valtext.set_fontsize(8)
    sl.label.set_visible(False)
    sliders[key] = sl
    slider_axes.append(sax)

# "Auto-fit" toggle button
btn_ax = fig.add_axes([ctrl_left, top_start - 7 * gap - 0.01,
                       ctrl_width * 0.55, 0.038], facecolor="#1e2130")
btn_fit = Button(btn_ax, "Auto-fit OFF",
                 color="#1e2130", hovercolor="#2d3044")
btn_fit.label.set_color(DIM)
btn_fit.label.set_fontsize(8.5)

# Stats text box
stats_ax = fig.add_axes([ctrl_left, 0.04, ctrl_width, 0.16],
                        facecolor="#0d0f14")
stats_ax.set_xticks([]); stats_ax.set_yticks([])
stats_ax.spines[:].set_color(GRID_C)
stats_txt = stats_ax.text(
    0.05, 0.92, "", transform=stats_ax.transAxes,
    color=DIM, fontsize=8, va="top", family="monospace",
    linespacing=1.7
)

# Header text
fig.text(ctrl_left, 0.955, "Wake Profile Controls",
         color="#d0d4e8", fontsize=10, fontweight="bold")
fig.text(ctrl_left, 0.934, "Adjust sliders — plot updates live",
         color=DIM, fontsize=7.5)

# ─────────────────────────────────────────────────────────────────────────────
#  Plot artists (created once, updated every slider move)
# ─────────────────────────────────────────────────────────────────────────────

# Main plot
scatter_in,  = ax_main.plot([], [], "o", color=RED,   ms=4,
                             alpha=0.75, label="Raw data (u_piv)", zorder=3)
line_fit,    = ax_main.plot([], [], "-", color=ACCENT, lw=2,
                             label="Gaussian model", zorder=4)
vline_L1 = ax_main.axvline(0, color="#e8a04a", lw=0.8, ls="--", alpha=0.6)
vline_L2 = ax_main.axvline(0, color="#e8a04a", lw=0.8, ls="--", alpha=0.6)
vline_R1 = ax_main.axvline(0, color="#a0e84a", lw=0.8, ls="--", alpha=0.6)
vline_R2 = ax_main.axvline(0, color="#a0e84a", lw=0.8, ls="--", alpha=0.6)

ax_main.set_xlabel("Normalized radial distance (x)", color=DIM, fontsize=9)
ax_main.set_ylabel("Normalized downwash velocity (u)", color=DIM, fontsize=9)
ax_main.legend(facecolor=PANEL, edgecolor=GRID_C,
               labelcolor="white", fontsize=8)

title_txt = ax_main.set_title("", color="#d0d4e8", fontsize=10, pad=6)

# Slice depth plot
sc_out2, = ax_slice.plot([], [], "o", color=DIM,  ms=2, alpha=0.2,
                          label="Outside slice", zorder=2)
sc_in2,  = ax_slice.plot([], [], "o", color=RED,  ms=3.5, alpha=0.8,
                          label="In slice", zorder=3)
from matplotlib.patches import Rectangle as MplRect
hspan = MplRect((0, 0), 1, 0, transform=ax_slice.get_yaxis_transform(),
                color=ACCENT, alpha=0.10, zorder=1)
ax_slice.add_patch(hspan)

ax_slice.set_xlabel("x", color=DIM, fontsize=9)
ax_slice.set_ylabel("z", color=DIM, fontsize=9)
ax_slice.set_title("z_piv distribution  —  red = selected slice",
                    color=DIM, fontsize=8.5, pad=4)
ax_slice.legend(facecolor=PANEL, edgecolor=GRID_C,
                labelcolor="white", fontsize=7.5)

# ─────────────────────────────────────────────────────────────────────────────
#  State
# ─────────────────────────────────────────────────────────────────────────────

state = {"autofit": False}


def toggle_fit(event):
    state["autofit"] = not state["autofit"]
    lbl = "Auto-fit ON " if state["autofit"] else "Auto-fit OFF"
    btn_fit.label.set_text(lbl)
    btn_fit.label.set_color(ACCENT if state["autofit"] else DIM)
    redraw(None)


btn_fit.on_clicked(toggle_fit)

# ─────────────────────────────────────────────────────────────────────────────
#  Core update function
# ─────────────────────────────────────────────────────────────────────────────

def redraw(_event):
    td  = sliders["target_depth"].val
    tol = sliders["tolerance"].val
    A   = sliders["amplitude"].val
    sig = sliders["sigma"].val
    xl  = sliders["x_left"].val
    xr  = sliders["x_right"].val
    R   = sliders["radius"].val
    p   = [A, sig, xl, xr, R]

    # ── slice ────────────────────────────────────────────────────────────────
    mask  = np.abs(z_piv - td) < tol
    x_in  = x_piv[mask];  u_in = u_piv[mask]
    x_out = x_piv[~mask]; z_out = z_piv[~mask]
    n_in  = mask.sum()

    # ── auto-fit (optional) ──────────────────────────────────────────────────
    fit_ok = False
    if state["autofit"] and n_in >= 5:
        try:
            def residuals(pp): return gauss_model(pp, x_in) - u_in
            res = least_squares(residuals, p, bounds=BOUNDS, max_nfev=2000)
            p   = res.x.tolist()
            fit_ok = True
            for key, val in zip(
                ["amplitude", "sigma", "x_left", "x_right", "radius"], p
            ):
                sliders[key].set_val(
                    float(np.clip(val, sliders[key].valmin, sliders[key].valmax))
                )
        except Exception:
            pass

    # ── model curve ──────────────────────────────────────────────────────────
    if n_in > 0:
        xs = np.linspace(x_in.min() - 0.1, x_in.max() + 0.1, 400)
    else:
        xs = np.linspace(-2.5, 2.5, 400)
    ys = gauss_model(p, xs)

    # ── update main plot ─────────────────────────────────────────────────────
    scatter_in.set_data(x_in, u_in)
    line_fit.set_data(xs, ys)

    vline_L1.set_xdata([p[2] - p[4], p[2] - p[4]])
    vline_L2.set_xdata([p[2] + p[4], p[2] + p[4]])
    vline_R1.set_xdata([p[3] - p[4], p[3] - p[4]])
    vline_R2.set_xdata([p[3] + p[4], p[3] + p[4]])

    ax_main.relim(); ax_main.autoscale_view()
    ax_main.set_title(
        f"Near-field wake  z/R = {td:.2f} ± {tol:.2f}   "
        f"({'auto-fitted' if fit_ok else 'manual'} params)",
        color="#d0d4e8", fontsize=10, pad=6
    )

    # ── update slice scatter ─────────────────────────────────────────────────
    sc_out2.set_data(x_out, z_out)
    sc_in2.set_data(x_in, z_piv[mask])

    # update horizontal band showing the depth slice window
    hspan.set_y(td - tol)
    hspan.set_height(2 * tol)
    ax_slice.relim(); ax_slice.autoscale_view()

    # ── stats panel ──────────────────────────────────────────────────────────
    status = "✓ has data" if n_in > 0 else "✗ EMPTY — widen tol or move depth"
    stats_txt.set_text(
        f"Points in slice : {n_in} / {len(x_piv)}\n"
        f"z band          : [{td-tol:.3f}, {td+tol:.3f}]\n"
        f"Status          : {status}\n"
        f"\n"
        f"Model params\n"
        f"  A  = {p[0]:+.3f}\n"
        f"  σ  = {p[1]:.3f}\n"
        f"  xL = {p[2]:+.3f}\n"
        f"  xR = {p[3]:+.3f}\n"
        f"  R  = {p[4]:.3f}\n"
        f"\n"
        f"Peak positions\n"
        f"  {p[2]-p[4]:+.2f}  {p[2]+p[4]:+.2f}  "
        f"{p[3]-p[4]:+.2f}  {p[3]+p[4]:+.2f}"
    )

    fig.canvas.draw_idle()


# Connect all sliders
for sl in sliders.values():
    sl.on_changed(redraw)

# ─────────────────────────────────────────────────────────────────────────────
#  Initial draw & show
# ─────────────────────────────────────────────────────────────────────────────

redraw(None)

# On Apple Silicon the default backend is usually 'macosx', which works great.
# If you see a blank window, try:  pip install PyQt6   then run again.
plt.show()