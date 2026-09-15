# Pixi-ROS Workspace

This ROS jazzy workspace is configured to use [Pixi](https://pixi.sh) for dependency management.

## Getting Started

> **Warning: Windows path length limitation**
> Windows limits many file operations to paths of 260 characters. Clone this workspace into a short path, such as `C:\IsaacSim-ros_workspaces\jazzy_ws`. If `pixi run sim` or the build reports missing files, build errors, or `The filename or extension is too long`, move the repository to a shorter path.

### 1. Fetch git submodules

Several workspace packages are tracked as git submodules, including Greenwave Monitor
under `src/greenwave_monitor` and MoveIt-related packages under `src/moveit/`. After
cloning, you must initialize them or the workspace will fail to build with missing-package
errors:

```bash
git submodule update --init --recursive
```

If you cloned with `git clone --recurse-submodules`, this step is already done.

### 2. Install dependencies

If `pixi install` reports an unsupported lock-file version, update Pixi first:

```bash
pixi self-update
```

Then install the workspace dependencies:

```bash
pixi install
```

### 3. Build the workspace

```bash
pixi run build
```

### 4. Activate the environment

```bash
pixi shell
```

This starts a new shell with the ROS environment activated. You can also prefix any command
with `pixi run <command>` without entering the shell.

> **Note:** After the first `pixi run build`, pixi will automatically source
> `install/setup.(bash/bat)` on environment activation. This means all your built packages
> are available without any manual sourcing.

## Start the H1 full-body controller (native ROS + venv)

`h1_fullbody_controller` is intentionally documented separately from the Pixi workflow
above. It loads a TorchScript H1 locomotion policy and is built in a local virtual
environment so that PyTorch does not modify the system ROS Python installation.

### 1. Set up and build only the H1 controller

From this `jazzy_ws` directory, run:

```bash
./setup_h1_controller_venv.sh --install-system-deps
```

This command prompts for `sudo` and installs the ROS Jazzy packages used by the Isaac Sim
ROS installation guide. It then creates `.venv-h1-native`, installs PyTorch, builds only
`h1_fullbody_controller`, and verifies that `policy/h1_policy.pt` can be loaded.

For a CPU-only machine, use the CPU PyTorch wheel instead:

```bash
TORCH_INDEX_URL=https://download.pytorch.org/whl/cpu \
  ./setup_h1_controller_venv.sh --install-system-deps
```

### 2. Start Isaac Sim and confirm its ROS 2 data first

Start the prepared H1 Isaac Sim stage in a separate terminal. The stage must publish one
advancing `/clock` stream plus `/imu` and `/joint_states` for the H1 articulation. Use the
same ROS domain in Isaac Sim and the controller; this example uses domain `0`.

In a second terminal, verify the simulator before starting the controller:

```bash
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=0

ros2 topic info /clock
ros2 topic echo --once /clock
ros2 topic echo --once /imu
ros2 topic echo --once /joint_states
```

Do not continue if `/clock` is missing, frozen, or if either sensor topic has no messages.
The controller only computes actions after it receives timestamp-matched IMU and joint-state
messages.

### 3. Start the controller

Open another terminal and run:

```bash
cd /path/to/IsaacSim-ros_workspaces/jazzy_ws
source /opt/ros/jazzy/setup.bash
source .venv-h1-native/bin/activate
source install/setup.bash
export ROS_DOMAIN_ID=0

ros2 launch h1_fullbody_controller h1_fullbody_controller.launch.xml
```

Use the launch command rather than `ros2 run`: the launch file provides the installed,
absolute path to the policy file.

### 4. Verify commands before teleoperation

With the simulator playing and the controller running, verify the command output in a new
terminal:

```bash
source /opt/ros/jazzy/setup.bash
source .venv-h1-native/bin/activate
source install/setup.bash
export ROS_DOMAIN_ID=0

ros2 topic info /joint_command
ros2 topic echo --once /joint_command
ros2 topic hz /joint_command
```

Expect one `/joint_command` publisher and messages with advancing, nonzero timestamps.
Keep `/cmd_vel` at zero until those checks pass and the robot is safely standing. Only then,
if your simulator safety setup is ready, start teleoperation in another terminal:

```bash
ros2 run teleop_twist_keyboard teleop_twist_keyboard
```

Press `k` to stop. This controller is for the Isaac Sim H1 stage; do not connect its output
directly to physical-robot motion hardware without an independently reviewed safety and
hardware-control integration.


### 5. Start the Isaac Sim

There is a `zenoh` and `sim` task you can run.

**Terminal 1:**

Start the zenoh server
```
pixi run zenoh
```

**Terminal 2:**
Start the simulator
```
pixi run sim
```
Now add the ROS2 clock publisher from the sim and start the sim to test the ros bridge:
- Click through: **Tools->Robotics->ROS 2 OmniGraphs->Clock->OK**
- Press the Play button of the simulator

**Terminal 3:**
Check wheter the topic became visible for the ROS cli:
```
pixi run ros2 topic list
/clock
/parameter_events
/rosout
```

## Adding dependencies

When you add dependencies to your `package.xml` files, re-run `pixi ros init` to update `pixi.toml`:

```bash
pixi ros init --distro jazzy
```

To add a conda package directly:

```bash
pixi add <package-name>
```

To add a PyPI package:

```bash
pixi add --pypi <package-name>
```

## Unavailable packages

If `pixi.toml` contains commented-out lines marked `# NOT FOUND`, those packages could not be
resolved from the default channels. Options:

1. **Use a custom channel** — re-run init with `--channel` if the package lives elsewhere:
   ```bash
   pixi ros init --distro jazzy --channel https://prefix.dev/my-channel
   ```
2. **Add the channel manually** — `pixi project channel add <channel-url>`
3. **Check the package name** — verify spelling in your `package.xml`
4. **Install via PyPI** — `pixi add --pypi <package-name>`
5. **Contribute to RoboStack** — if the package is missing from the default ROS channel:
   - [ros-humble](https://github.com/RoboStack/ros-humble)
   - [ros-jazzy](https://github.com/RoboStack/ros-jazzy)
   - [ros-kilted](https://github.com/RoboStack/ros-kilted)

## Common issues

### Build fails

1. Make sure all dependencies are installed: `pixi install`
2. Clean and rebuild: `pixi run clean && pixi run build`

### `ros2` commands not found

Run commands through pixi: `pixi run <command>` or enter the shell with `pixi shell`.

### Active ROS environment conflict

If `pixi ros init` warns about an "Active ROS environment detected", you have a ROS installation
sourced in your shell. Remove or comment out any lines like the following from `~/.bashrc` or
`~/.zshrc` and restart your shell:

```bash
# source /opt/ros/jazzy/setup.bash
# source ~/ros_ws/install/setup.bash
```

Pixi manages the ROS environment automatically — no manual sourcing needed.

## Learn more

- [Pixi documentation](https://pixi.sh)
- [RoboStack](https://robostack.github.io/)
- [ROS jazzy documentation](https://docs.ros.org/en/jazzy/)
- [pixi-ros](https://github.com/prefix-dev/pixi-ros)
- [Isaac Sim ROS 2 Installation](https://docs.isaacsim.omniverse.nvidia.com/latest/installation/install_ros.html)
