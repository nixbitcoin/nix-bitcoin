{ pkgs, buildGoModule, fetchurl, lib }:

buildGoModule rec {
  pname = "faraday";
  version = "0.2.0-alpha";

  src = fetchurl {
    url = "https://github.com/lightninglabs/faraday/archive/v${version}.tar.gz";
    # Use ./get-sha256.sh to fetch latest (verified) sha256
    sha256 = "58cdb977909e2188837ee0d00ec47a520baeb3bb09719ea6e1fe23efb9283d06";
  };

  subPackages = [ "cmd/faraday" "cmd/frcli" ];

  vendorSha256 = "1vmspdlh018p453rbif5yc2fqjipnz012rlbilwcrkjric24qbsk";

  meta = with lib; {
    description = " Faraday: Lightning Channel Management & Optimization Tool";
    homepage = "https://github.com/lightninglabs/faraday";
    license = lib.licenses.mit;
  };
}
