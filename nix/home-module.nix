# Módulo home-manager de gifdesk.
# Uso en tu flake (ej. nixos-config):
#
#   inputs = {
#     gifdesk.url = "github:Gagedito/gifdesk";
#     # o "github:Gagedito/gifdesk/rama" para una version sin publicar,
#     # o "path:./gifdesk" para una copia local
#     home-manager.url = "github:nix-community/home-manager";
#     home-manager.inputs.nixpkgs.follows = "nixpkgs";
#   };
#
#   outputs = { nixpkgs, gifdesk, home-manager, ... }:
#     let
#       system = "x86_64-linux";
#       pkgs = nixpkgs.legacyPackages.${system};
#     in {
#       homeConfigurations."tu-usuario" = home-manager.lib.homeManagerConfiguration {
#         inherit pkgs;                    # sin `system`: home-manager no lo admite
#         modules = [
#           gifdesk.homeManagerModules.gifdesk
#           {
#             home.username = "tu-usuario";
#             home.homeDirectory = "/home/tu-usuario";
#             home.stateVersion = "24.11";
#             programs.gifdesk = {
#               enable = true;
#               package = gifdesk.packages.${system}.gifdesk;
#               gnomeExtension = true;   # enlaza el motor; luego `gnome-extensions enable gifdesk-widgets@gifdesk.local`
#             };
#           }
#         ];
#       };
#     };
{ config, lib, ... }:
let
  cfg = config.programs.gifdesk;
  extUuid = "gifdesk-widgets@gifdesk.local";
in
{
  options.programs.gifdesk = {
    enable = lib.mkEnableOption "gifdesk, GIF/WebP flotantes (visor + GUIs)";

    package = lib.mkOption {
      type = lib.types.package;
      description = "Paquete gifdesk a instalar (normalmente el del flake).";
    };

    gnomeExtension = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enlaza la extensión de posicionamiento exacta para GNOME Wayland.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file.".local/share/gnome-shell/extensions/${extUuid}" =
      lib.mkIf cfg.gnomeExtension {
        source = "${cfg.package}/share/gnome-shell/extensions/${extUuid}";
      };
  };
}
