{
  hostname,
  lib,
  config,
  ...
}:
let
  installOn = [ "workhorse" ];
in
lib.mkIf (lib.elem "${hostname}" installOn) {
  services.garage = {
    enable= true;
    settings = ''
      db_engine = "sqlite"

      replication_factor = 1

      rpc_bind_addr = "[::]:3901"
      rpc_public_addr = "127.0.0.1:3901"
      rpc_secret = "${(builtins.fromTOML config.sops.secrets.garage ).rpc_secret})"

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
      admin_token = "${(builtins.fromTOML config.sops.secrets.garage).admin_token})"
      metrics_token = "${(builtins.fromTOML config.sops.secrets.garage).metrics_token})"
    '';
  };
}
