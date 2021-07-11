{ config, options, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.charge-lnd;
  nbLib = config.nix-bitcoin.lib;
  lnd = config.services.lnd;
  electrs = if (options ? services.electrs) && config.services.electrs.enable
            then config.services.electrs
            else null;

  user = "charge-lnd";
  group = user;
  dataDir = "/var/lib/charge-lnd";

  configFile = builtins.toFile "charge-lnd.config" cfg.policies;
  checkedConfig = pkgs.runCommandNoCC "charge-lnd-checked.config" { } ''
    ${config.nix-bitcoin.pkgs.charge-lnd}/bin/charge-lnd --check --config ${configFile}
    cp ${configFile} $out
  '';
in
{
  options.services.charge-lnd = with types; {
    enable = mkEnableOption "charge-lnd, policy-based fee manager";

    extraFlags = mkOption {
      type = listOf str;
      default = [];
      example = [ "--verbose" "--dry-run" ];
      description = "Extra flags to pass to the charge-lnd command.";
    };

    interval = mkOption {
      type = str;
      default = "*-*-* 04:00:00";
      example = "hourly";
      description = ''
        Systemd calendar expression when to adjust fees.

        See <citerefentry><refentrytitle>systemd.time</refentrytitle>
        <manvolnum>7</manvolnum></citerefentry> for possible values.

        Default is once a day.
      '';
    };

    randomDelay = mkOption {
      type = str;
      default = "1h";
      description = ''
        Random delay to add to scheduled time.
      '';
    };

    policies = mkOption {
      type = types.lines;
      default = "";
      example = literalExample ''
        [discourage-routing-out-of-balance]
        chan.max_ratio = 0.1
        chan.min_capacity = 250000
        strategy = static
        base_fee_msat = 10000
        fee_ppm = 500

        [encourage-routing-to-balance]
        chan.min_ratio = 0.9
        chan.min_capacity = 250000
        strategy = static
        base_fee_msat = 1
        fee_ppm = 2

        [default]
        strategy = ignore
      '';
      description = ''
        Policy definitions in INI format.

        See https://github.com/accumulator/charge-lnd/blob/master/README.md#usage
        for possible properties and parameters.

        Policies are evaluated from top to bottom.
        The first matching policy (or `default`) is applied.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.lnd = {
      enable = true;
      macaroons.charge-lnd = {
        user = user;
        permissions = ''{"entity":"info","action":"read"},{"entity":"onchain","action":"read"},{"entity":"offchain","action":"read"},{"entity":"offchain","action":"write"}'';
      };
    };

    systemd.services.charge-lnd = {
      documentation = [ "https://github.com/accumulator/charge-lnd/blob/master/README.md" ];
      after = [ "lnd.service" ];
      requires = [ "lnd.service" ];
      # lnd's data directory (--lnddir) is not accessible to charge-lnd.
      # Instead use directory "lnddir-proxy" as lnddir and link relevant files to it.
      preStart = ''
        macaroonDir=${dataDir}/lnddir-proxy/data/chain/bitcoin/mainnet
        mkdir -p $macaroonDir
        ln -sf /run/lnd/charge-lnd.macaroon $macaroonDir
        ln -sf ${config.nix-bitcoin.secretsDir}/lnd-cert ${dataDir}/lnddir-proxy/tls.cert
      '';
      serviceConfig = nbLib.defaultHardening // {
        ExecStart = ''
          ${config.nix-bitcoin.pkgs.charge-lnd}/bin/charge-lnd \
            --lnddir ${dataDir}/lnddir-proxy \
            --grpc ${lnd.rpcAddress}:${toString lnd.rpcPort} \
            --config ${checkedConfig} \
            ${optionalString (electrs != null) "--electrum-server ${electrs.address}:${toString electrs.port}"} \
            ${escapeShellArgs cfg.extraFlags}
        '';
        Type = "oneshot";
        User = user;
        Group = group;
        StateDirectory = "charge-lnd";
      } // nbLib.allowLocalIPAddresses;
    };

    systemd.timers.charge-lnd = {
      description = "Adjust LND routing fees";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.interval;
        RandomizedDelaySec = cfg.randomDelay;
      };
    };

    users.users.${user} = {
      group = group;
      isSystemUser = true;
    };
    users.groups.${group} = {};
  };
}
