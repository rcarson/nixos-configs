# crafty — homelab server: Minecraft, Home Assistant VM, monitoring.
# Shared settings live in ../../modules/common.nix.

{ config, pkgs, ... }:

{
  networking.hostName = "crafty";

  # Kernel.
  boot.kernel.sysctl = { "vm.swappiness" = 10; };

  networking.networkmanager.unmanaged = [ "interface-name:vlan40" "interface-name:br-vlan40" ];

  # VLAN40 interface for Home Assistant VM
  networking.vlans.vlan40 = {
    id = 40;
    interface = "enp0s31f6";
  };

  # Bridge on VLAN40 — VM's virtual NIC attaches here
  networking.bridges.br-vlan40 = {
    interfaces = [ "vlan40" ];
  };

  # Adds on top of modules/common.nix's base "rc" user (kvm needed for the HAOS VM below).
  users.users."rc".extraGroups = [ "kvm" ];

  # Host-specific packages on top of modules/common.nix's base list.
  environment.systemPackages = with pkgs; [
    curl
    github-copilot-cli
    python3
    rclone
    qemu_kvm
    OVMF
  ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  services.prometheus.exporters.node = {
    enable = true;
    port   = 9100;
    enabledCollectors = [ "systemd" ];
  };

  sops.defaultSopsFile = ./secrets.yaml;
  sops.secrets."minecraft_env" = { };

  # RCON_PASSWORD comes from sops.secrets."minecraft_env" (see ./secrets.yaml);
  # nix-minecraft substitutes @RCON_PASSWORD@ in serverProperties at service
  # start, so the real password never lands in the Nix store.
  services.minecraft-servers = {
    enable         = true;
    eula           = true;
    openFirewall   = true;
    environmentFile = config.sops.secrets."minecraft_env".path;

    servers.vanilla = {
      enable  = true;
      jvmOpts = "-Xmx4G -Xms2G";

      operators = {
        "fourdirections" = {
          uuid = "d4c190e8-3893-4667-a31b-56cd3fb9b780";
          level = 4;
        };
        "wifuy" = {
          uuid = "8928d944-4ad0-4fca-8c83-b59e9c15d826";
          level = 4;
        };
      };
      serverProperties  = {
        server-port     = 25565;
        difficulty      = "easy";
        gamemode        = "survival";
        max-players     = 10;
        white-list      = false;
        enable-rcon     = true;
        "rcon.password" = "@RCON_PASSWORD@";
      };

      package = pkgs.minecraftServers.vanilla;
    };
  };

  # Logged in via Copilot for now, so no API key/secret needed.
  services.hermes-agent = {
    enable = true;
    #settings.model.default = "anthropic/claude-sonnet-4";
    #environmentFiles = [ config.sops.secrets."hermes_env".path ];
    addToSystemPackages = true;
  };

  networking.firewall.allowedTCPPorts = [ 9100 25565 ];

  systemd.services.haos-vm = {
    description = "Home Assistant OS VM";
    after = [ "network-online.target" "br-vlan40-netdev.service" ];
    wants = [ "network-online.target" ];
    requires = [ "br-vlan40-netdev.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${pkgs.writeShellScript "haos-vm-pre" ''
        ${pkgs.iproute2}/bin/ip link del tap-haos 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip tuntap add dev tap-haos mode tap
        ${pkgs.iproute2}/bin/ip link set tap-haos master br-vlan40
        ${pkgs.iproute2}/bin/ip link set tap-haos up
      ''}";
      ExecStart = ''
        ${pkgs.qemu_kvm}/bin/qemu-system-x86_64 \
          -name homeassistant \
          -machine q35,accel=kvm \
          -cpu host \
          -smp 2 \
          -m 4096 \
          -drive if=pflash,format=raw,readonly=on,file=${pkgs.OVMF.fd}/FV/OVMF_CODE.fd \
          -drive if=pflash,format=raw,file=/var/lib/haos/OVMF_VARS.fd \
          -drive file=/var/lib/haos/haos.qcow2,if=virtio,format=qcow2 \
          -netdev tap,id=net0,ifname=tap-haos,script=no,downscript=no,vnet_hdr=off \
          -device virtio-net-pci,netdev=net0,mac=BC:24:11:76:14:D6 \
          -display none \
          -serial null
      '';
      ExecStopPost = "${pkgs.writeShellScript "haos-vm-post" ''
        ${pkgs.iproute2}/bin/ip link del tap-haos 2>/dev/null || true
      ''}";
      Restart = "on-failure";
    };
  };
}
