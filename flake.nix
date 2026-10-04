{
  description = "gifdesk — GIF/WebP flotantes (mpv); GUIs KDE y GNOME + extensión de posicionamiento para Mutter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
    in
    {
      packages = forAll (pkgs: rec {
        gifdesk = pkgs.callPackage ./nix/gifdesk.nix { };
        default = gifdesk;
      });

      homeManagerModules = rec {
        gifdesk = import ./nix/home-module.nix;
        default = gifdesk;
      };

      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          inputsFrom = [ self.packages.${pkgs.system}.gifdesk ];
          packages = with pkgs; [
            (python3.withPackages (ps: [ ps.pygobject3 ]))
            desktop-file-utils
          ];
        };
      });
    };
}
