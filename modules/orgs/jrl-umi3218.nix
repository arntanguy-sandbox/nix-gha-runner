{ lib, ... }:
let
  secretName = "jrl-umi3218-github_token";
in
{
  config = {
    services.nixGhaRunner = {
      enable = lib.mkDefault true;
      organization = lib.mkDefault "jrl-umi3218";
      tokenSecret = lib.mkDefault secretName;
    };

    sops.secrets.${secretName} = {
      key = "data/jrl-umi3218/github_token";
      mode = "0400";
      owner = "root";
    };
  };
}
