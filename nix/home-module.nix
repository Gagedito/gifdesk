# Módulo home-manager de gifdesk.
# Uso en tu flake (ej. nixos-config):
#
#   inputs.gifdesk.url = "path:/home/sabrina/Projects/gifdesk";
#   # o "github:tu-usuario/gifdesk"
#
#   home-manager.users.sabrina = {
#     imports = [ inputs.gifdesk.homeManagerModules.gifdesk ];
#     programs.gifdesk = {
#       enable = true;
#       package = inputs.gifdesk.packages.${pkgs.system}.gifdesk;
#       gnomeExtension = true;   # enlaza el motor (luego: `gnome-extensions enable gifdesk-widgets@gifdesk.local`)
#     };
#   };
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
