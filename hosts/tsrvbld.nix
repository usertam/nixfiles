{ config, lib, pkgs, modulesPath, ... }:

{
  # We need vagrant to spawn TrustedServer mocks.
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "vagrant" ];
  environment.systemPackages = [ pkgs.vagrant pkgs.sshpass ];

  # Enable virtualbox, docker, and KVM.
  virtualisation = {
    docker.enable = true;
    virtualbox.host.enable = true;
  };
  environment.etc."vbox/networks.conf".text = "* 0.0.0.0/0 ::/0";
  boot.kernelModules = [ "kvm-intel" ];

  # Enable x11 server and keymap.
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
    };
  };

  # Enable display an desktop managers.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Enable audio.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable auto login.
  services.displayManager.autoLogin = {
    enable = true;
    user = "root";
  };

  # Enable touchpad support.
  services.libinput.enable = true;

  # Don't sleep.
  services.logind.lidSwitch = "lock";
}
