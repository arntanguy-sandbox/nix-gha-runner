{ lib, ... }:
let
  secretName = "isri-aist-github_token";
in
{
  config = {
    services.nixGhaRunner = {
      enable = lib.mkDefault true;
      organization = lib.mkDefault "isri-aist";
      tokenSecret = lib.mkDefault secretName;
    };

    sops.secrets.${secretName} = {
      key = "data/isri-aist/github_token";
      mode = "0400";
      owner = "root";
    };
  };
}
