#!/bin/zsh
set -e

echo "Starting MATLAB Quadrotor Wake Visualization..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

MATLAB_BIN="/Applications/MATLAB_R2025b.app/bin/matlab"
if [[ ! -x "$MATLAB_BIN" ]]; then
  MATLAB_APP=$(ls -d /Applications/MATLAB_R20*.app 2>/dev/null | sort | tail -n 1)
  if [[ -n "$MATLAB_APP" && -x "$MATLAB_APP/bin/matlab" ]]; then
    MATLAB_BIN="$MATLAB_APP/bin/matlab"
  else
    echo "MATLAB executable not found in /Applications."
    echo "Open MATLAB once, or update this script with your MATLAB path."
    exit 1
  fi
fi

"$MATLAB_BIN" -batch "plot_3d_wake_quadrotor"
