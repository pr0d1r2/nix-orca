# Test script of nix/tests/module-nixos.nix (nix/modules T1). The NixOS test
# driver defines `machine`; the derivation prepends `version`.
# ruff: noqa: F821

machine.wait_for_unit("multi-user.target")

got = machine.succeed("su - alice -c 'orca-ide --version'").strip()
assert got == version, f"orca-ide --version printed {got!r}, want {version!r}"

machine.succeed("test -e /run/current-system/sw/share/applications/orca-ide.desktop")
machine.succeed("test -e /run/current-system/sw/share/icons/hicolor/256x256/apps/orca-ide.png")
