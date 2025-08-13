{
  hostname,
  lib,
  config,
  pkgs,
  ...
}:
let
  installOn = [ "workhorse" ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services.garage = {
    enable= true;
    package= pkgs.garage_2;
    settings = {
      db_engine = "sqlite";
      replication_factor = 1;
      rpc_bind_addr = "[::]:3901";
      rpc_public_addr = "127.0.0.1:3901";

      s3_api= {
        s3_region = "garage";
        api_bind_addr = "[::]:3900";
        root_domain = ".s3.garage.localhost";
      };

      s3_web= {
        bind_addr = "[::]:3902";
        root_domain = ".web.garage.localhost";
        index = "index.html";
      };

      k2v_api = {
        api_bind_addr = "[::]:3904";
      };

      admin= {
        api_bind_addr = "[::]:3903";
      };

    };
    environmentFile = config.sops.secrets.garage-env.path;
  };
  sops = {
    secrets = {
      garage-env  = lib.mkIf config.services.garage.enable {
        group = "garage";
        owner = "garage";
        mode= "0644";
        sopsFile = ../../../../secrets/garage.yaml;
      };
    };
  };
}
