#!/usr/bin/env bash
# Build only h1_fullbody_controller in an isolated Python environment.
#
# Prerequisites: Ubuntu 24.04 with the ROS 2 apt repository configured, and
# this workspace checked out with the H1 package under src/.
#
# Usage:
#   ./setup_h1_controller_venv.sh --install-system-deps
#
# Optional overrides:
#   VENV_DIR=/path/to/venv ./setup_h1_controller_venv.sh
#   TORCH_INDEX_URL=https://download.pytorch.org/whl/cpu ./setup_h1_controller_venv.sh

set -eo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NAME="h1_fullbody_controller"
PACKAGE_DIR="$WORKSPACE_DIR/src/humanoid_locomotion_policy_example/$PACKAGE_NAME"
ROS_SETUP="/opt/ros/jazzy/setup.bash"
VENV_DIR="${VENV_DIR:-$WORKSPACE_DIR/.venv-h1-native}"
TORCH_VERSION="${TORCH_VERSION:-2.14.0}"
TORCH_INDEX_URL="${TORCH_INDEX_URL:-https://download.pytorch.org/whl/cu130}"
INSTALL_SYSTEM_DEPS=0

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-system-deps)
      INSTALL_SYSTEM_DEPS=1
      ;;
    -h|--help)
      sed -n '1,16p' "$0"
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
  shift
done

if [[ "$INSTALL_SYSTEM_DEPS" -eq 1 ]]; then
  command -v apt-get >/dev/null || fail "--install-system-deps requires apt-get on Ubuntu."
  command -v sudo >/dev/null || fail "--install-system-deps requires sudo."
  sudo apt-get update
  sudo apt-get install -y \
    build-essential \
    python3-venv \
    python3-pip \
    python3-rosdep \
    python3-colcon-common-extensions \
    ros-jazzy-desktop \
    ros-jazzy-vision-msgs \
    ros-jazzy-ackermann-msgs
fi

[[ -f "$ROS_SETUP" ]] || fail "ROS 2 Jazzy is required at $ROS_SETUP."
[[ -f "$PACKAGE_DIR/package.xml" ]] || fail "Cannot find $PACKAGE_NAME at $PACKAGE_DIR."
command -v python3 >/dev/null || fail "python3 is required."
command -v colcon >/dev/null || fail "colcon is required. Install ROS 2 Jazzy desktop or ros-jazzy-colcon-common-extensions."

cd "$WORKSPACE_DIR"

# Source before enabling nounset: the ROS setup scripts reference optional vars.
source "$ROS_SETUP"
export PYTHONNOUSERSITE=1

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  python3 -m venv --system-site-packages "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

# setuptools >=80 breaks this ament_python package's symlink-install path.
python -m pip install --upgrade 'pip<26' 'setuptools==79.0.1' wheel
python -m pip install "torch==$TORCH_VERSION" --index-url "$TORCH_INDEX_URL"

# This intentionally selects exactly one package; no other workspace packages build.
python -m colcon build \
  --packages-select "$PACKAGE_NAME" \
  --symlink-install \
  --event-handlers console_direct+

source "$WORKSPACE_DIR/install/setup.bash"

POLICY_PATH="$WORKSPACE_DIR/install/$PACKAGE_NAME/share/$PACKAGE_NAME/policy/h1_policy.pt"
EXECUTABLE_PATH="$WORKSPACE_DIR/install/$PACKAGE_NAME/lib/$PACKAGE_NAME/$PACKAGE_NAME"

[[ -f "$POLICY_PATH" ]] || fail "Build did not install the policy at $POLICY_PATH."
[[ -x "$EXECUTABLE_PATH" ]] || fail "Build did not install the executable at $EXECUTABLE_PATH."

# Build proof: import ROS and Torch, then construct the node with its installed policy.
POLICY_PATH="$POLICY_PATH" python - <<'PY'
import os
from pathlib import Path

import rclpy
import torch
from h1_fullbody_controller.h1_fullbody_controller import H1FullbodyController

policy = Path(os.environ["POLICY_PATH"])
rclpy.init(args=["--ros-args", "-p", f"policy_path:={policy}"])
node = H1FullbodyController()
node.destroy_node()
rclpy.shutdown()

print(f"PyTorch: {torch.__version__}")
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"CUDA version: {torch.version.cuda}")
print(f"Policy loaded: {policy}")
PY

printf '\nBuild complete. To launch later:\n'
printf '  cd %q\n' "$WORKSPACE_DIR"
printf '  source /opt/ros/jazzy/setup.bash\n'
printf '  source %q/bin/activate\n' "$VENV_DIR"
printf '  source install/setup.bash\n'
printf '  ros2 launch h1_fullbody_controller h1_fullbody_controller.launch.xml\n'
printf 'Executable shebang: '
head -n 1 "$EXECUTABLE_PATH"
