{ ... }:
let
  # One of: cool quiet balanced performance. These select the BIOS's own fan
  # curves (same as "Thermal Management" in BIOS setup), so the EC keeps
  # driving both fans from the real CPU/GPU temps.
  #
  # Software fan control doesn't work on this Precision 7720: dell_smm accepts
  # manual mode but the BIOS keeps overriding pwm writes, and switching back
  # to auto returns EINVAL.
  profile = "quiet";
in
{
  boot.kernelModules = [ "dell_pc" ];

  systemd.services.platform-profile = {
    description = "Set the ACPI platform profile (BIOS thermal mode)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    unitConfig.ConditionPathExists = "/sys/firmware/acpi/platform_profile";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "/bin/sh -c 'echo ${profile} > /sys/firmware/acpi/platform_profile'";
    };
  };

  # The firmware can reset the profile across suspend.
  powerManagement.resumeCommands = ''
    systemctl restart platform-profile.service
  '';
}
