{ username, ... }:
{
  users.users.sangmin = {
    description = "sangmin";
    # mkpasswd -m sha-512
    hashedPassword = "$6$HTLwjYwDBY95JAP8$DKuNIs1vNUUoKGgX1gnKRBfdPKESN97hWG1X0ty.E8vbGz/J68vpsSuNrh3WbWDM7O4ZQubKEPYTjKDmjjmCs.";
  };
  systemd.tmpfiles.rules = [ "d /mnt/snapshot/${username} 0755 ${username} users" ];
}
