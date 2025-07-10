{ username, ... }:
{
  users.users.sangmin = {
    description = "sangmin";
    # mkpasswd -m sha-512
    hashedPassword = "$6$HTLwjYwDBY95JAP8$DKuNIs1vNUUoKGgX1gnKRBfdPKESN97hWG1X0ty.E8vbGz/J68vpsSuNrh3WbWDM7O4ZQubKEPYTjKDmjjmCs.";
    openssh.authorizedKeys.keys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMp9MTt8Kv8Ba/3NCckiUxW86X7AhDOCmtAtZO3DpO6zAAAAEHNzaDpZb3VyVGV4dEhlcmU= saggins@Sangmins-MacBook-Air.local"
       "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICAYJdNDpcddHw39/CSr/MEaHdHcOOyWuGRHZWCXOqil saggins@Sangmins-MacBook-Air.local"
       "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDCeiu5x60l/OtD2C5cQASJJQPGblGcRJNVlhw9NjZhG sangmin@blackchungus"
      
    ];
  };
  systemd.tmpfiles.rules = [ "d /mnt/snapshot/${username} 0755 ${username} users" ];
}
