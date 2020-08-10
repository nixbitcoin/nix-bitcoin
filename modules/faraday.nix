{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.faraday;
  inherit (config) nix-bitcoin-services;
  secretsDir = config.nix-bitcoin.secretsDir;
in {

  options.services.faraday = {
    enable = mkEnableOption "faraday";
    package = mkOption {
      type = types.package;
      default = pkgs.nix-bitcoin.faraday;
      defaultText = "pkgs.nix-bitcoin.faraday";
      description = "The package providing faraday binaries.";
    };
    rpclisten = mkOption {
      type = types.str;
      default = "localhost:8465";
      description = "Address to listen on for gRPC clients.";
    };
    extraArgs = mkOption {
      type = types.separatedString " ";
      default = "";
      description = "Extra command line arguments passed to faraday.";
    };
    cli = mkOption {
      default = pkgs.writeScriptBin "frcli"
      # Switch user because lnd makes datadir contents readable by user only
      ''
        exec sudo -u lnd ${cfg.package}/bin/frcli --rpcserver ${cfg.rpclisten} "$@"
      '';
      description = "Binary to connect with the lnd instance.";
    };
    enforceTor =  nix-bitcoin-services.enforceTor;
  };

  config = mkIf cfg.enable {
    assertions = [
      { assertion = config.services.lnd.enable;
        message = "faraday requires lnd.";
      }
    ];

    environment.systemPackages = [ cfg.package (hiPrio cfg.cli) ];

    systemd.services.faraday = {
      description = "Run faraday";
      wantedBy = [ "multi-user.target" ];
      requires = [ "lnd.service" ];
      after = [ "lnd.service" ];
      serviceConfig = nix-bitcoin-services.defaultHardening // {
        ExecStart = ''
          ${cfg.package}/bin/faraday \
          --rpclisten=${cfg.rpclisten} \
          --rpcserver=${config.services.lnd.listen}:10009 \
          --macaroondir=${config.services.lnd.dataDir}/chain/bitcoin/mainnet \
          --tlscertpath=${secretsDir}/lnd-cert \
          ${cfg.extraArgs}
        '';
        User = "lnd";
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = "${config.services.lnd.dataDir}";
      } // (if cfg.enforceTor
          then nix-bitcoin-services.allowTor
          else nix-bitcoin-services.allowAnyIP);
    };
  };
}
