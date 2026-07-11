# roach — Lenovo ThinkPad X1 Carbon Gen 9, COSMIC desktop.
# Shared settings live in ../../modules/common.nix.

{ config, pkgs, ... }:

{
  networking.hostName = "roach";

  users.users."ac" = {
    isNormalUser = true;
    description = "Amanda Carson";
    extraGroups = [ "networkmanager" ];
    packages = with pkgs; [];
  };

  # Host-specific packages on top of modules/common.nix's base list.
  environment.systemPackages = with pkgs; [
    firefox
    discord
  ];

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    glib
  ];

  # Skip installing the default COSMIC apps we don't use.
  environment.cosmic.excludePackages = with pkgs; [
    cosmic-edit
  ];

  security.rtkit.enable = true; # Realtime scheduling for audio/pipewire clients.

  # List services that you want to enable:
  services.desktopManager.cosmic.enable = true; # COSMIC desktop environment.
  services.displayManager.cosmic-greeter.enable = true; # COSMIC's login screen.
  services.system76-scheduler.enable = true; # Process scheduling tweaks (System76's CFS scheduler tuning).

  # X1 Carbon Gen 9 services
  services.power-profiles-daemon.enable = true; # Lets the desktop switch power/performance profiles.
  services.fwupd.enable = true; # Firmware updates (fwupdmgr) for BIOS/EC/peripherals.

  # Logged in via Copilot for now, so no API key/secret needed.
  services.hermes-agent = {
    enable = true;
    #settings.model.default = "anthropic/claude-sonnet-4";
    #environmentFiles = [ config.sops.secrets."hermes_env".path ];
    addToSystemPackages = true;
  };

  #services.pipewire = {
  #  enable = true;
  #  alsa.enable = true;
  #  alsa.support32Bit = true;
  #  pulse.enable = true;
  #};

  # Tailscale: use nftables (instead of the default iptables) as the firewall
  # backend, trust traffic on the tailscale0 interface, and open Tailscale's
  # UDP port so peer-to-peer connections can be established.
  networking.nftables.enable = true;
  networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];
  networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];

  # Force tailscaled to manage nftables rules instead of auto-detecting,
  # since auto-detection can pick iptables even when nftables is enabled.
  systemd.services.tailscaled.serviceConfig.Environment = [
    "TS_DEBUG_FIREWALL_MODE=nftables"
  ];

  # Don't block boot waiting for network-online.target; Tailscale/NetworkManager
  # come up asynchronously and this avoids slow boots when links aren't ready.
  systemd.network.wait-online.enable = false;
  boot.initrd.systemd.network.wait-online.enable = false;

  services.resolved = {
    enable = true;
    settings.Resolve.FallbackDNS = [ "1.1.1.1" ]; # Or your preferred upstream DNS
  };

  # Intel GPU hardware video acceleration (VA-API) for the X1 Carbon's iGPU.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
    ];
  };
}
