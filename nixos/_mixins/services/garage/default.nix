{
  hostname,
  lib,
  ...
}:
let
  installOn = [ "workhorse" ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  sops.secrets.garage-secrets = {
    #group="garage";
    #mode ="0644";
    #owner = "garage";
    sops="../../../../secrets/garage.yaml ";
  };
  services.garage = {
    enable= true;
    settings = ''
      db_engine = "sqlite"

      replication_factor = 1

      rpc_bind_addr = "[::]:3901"
      rpc_public_addr = "127.0.0.1:3901"
      rpc_secret = "${(builtins.fromTOML builtins.readFile "/run/secrets/garage.yaml").rpc_secret})"

      [s3_api]
      s3_region = "garage"
      api_bind_addr = "[::]:3900"
      root_domain = ".s3.garage.localhost"

      [s3_web]
      bind_addr = "[::]:3902"
      root_domain = ".web.garage.localhost"
      index = "index.html"

      [k2v_api]
      api_bind_addr = "[::]:3904"

      [admin]
      api_bind_addr = "[::]:3903"
      admin_token = "${(builtins.fromTOML builtins.readFile "/run/secrets/garage.yaml").admin_token})"
      metrics_token = "${(builtins.fromTOML builtins.readFile "/run/secrets/garage.yaml").metrics_token})"
    '';
  };
}
