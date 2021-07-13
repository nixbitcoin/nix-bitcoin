let
  fetch = { rev, sha256 }:
    builtins.fetchTarball {
      url = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
      inherit sha256;
    };
in
{
  # To update, run ../helper/fetch-channel REV
  nixpkgs = fetch {
    rev = "359e6542e1d41eb18df55c82bdb08bf738fae2cf";
    sha256 = "05v28njaas9l26ibc6vy6imvy7grbkli32bmv0n32x6x9cf68gf9";
  };
  nixpkgs-unstable = builtins.fetchTarball {
    url = "https://github.com/nixbitcoin/nixpkgs/archive/e8135bdc7f26125e072186c66ae0c27fe35ffdae.tar.gz";
    sha256 = "05irab32svmfsdlfy1810m6q36fdk2kfh7ipm9ir85csic5rvcjq";
  };
}
