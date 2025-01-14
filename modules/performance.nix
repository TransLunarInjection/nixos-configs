{ config, ... }:
{
  config = {
    boot.kernel.sysctl = {
      "vm.swappiness" = 10;
      # TODO: the higher default of 10% of RAM would be better here,
      # but it makes removable storage dangerous as it's a system wide setting
      # and there's no way to make the limit smaller for removable storeage
      # I also haven't found an easy way to make removeable storage mount with sync option
      "vm.dirty_bytes" = 1024 * 1024 * 512;
      "vm.dirty_background_bytes" = 1024 * 1024 * 32;
    };
  };
}
