{ lib, ... }:
let
  secretName = "arntanguy-sandbox-github_token";
in
{
  config = {
    services.nixGhaRunner = {
      enable = lib.mkDefault true;
      organization = lib.mkDefault "arntanguy-sandbox";
      tokenSecret = lib.mkDefault secretName;
    };

    sops.secrets.${secretName} = {
      key = "data/arntanguy-sandbox/github_token";
      mode = "0400";
      owner = "root";
    };
  };
}
