# nix/sources.json for a new upstream version (scripts/bump.sh): every
# pinned fact replaced, darwin.teamIdentifier kept (nix/darwin V5).
.version = $version
| .tag = $tag
| .commit = $src.commit
| .src.hash = $src.hash
| .pnpmDeps.hash = $deps
| .mobilePnpmDeps.hash = $mobile
| .linux."x86_64-linux".deb = $amd64
| .linux."x86_64-linux".orcadTemplate.hash = $amd64_template
| .linux."aarch64-linux".deb = $arm64
| .linux."aarch64-linux".orcadTemplate.hash = $arm64_template
| .darwin."aarch64-darwin".zip = $mac_arm64
| .darwin."x86_64-darwin".zip = $mac_x64
