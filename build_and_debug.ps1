#
# Author: @November_Dev
#
$godotPath = "C:\Projects\Godot.exe"
$output = "C:\Projects\GD_BUILDS\02_MULTIPLAYER.exe"

# --no-window is bugged
cmd.exe /c $godotPath --no-window --export-debug default_export $output

Start-Process "cmd.exe" -ArgumentList "/c $output --server" -PassThru

for ($i = 0; $i -lt $args[0]; $i++) {
    Start-Process "cmd.exe" -ArgumentList "/c $output --userindex $i" -PassThru
}