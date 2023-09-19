{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs.outPath {
          # Set local system
          localSystem = { inherit system; };

          overlays = [
            (final: prev: {
              # Replace SEAdata with the big version, to get a faster SEA for ECC
              pari-seadata-small = prev.pari-seadata-small.overrideAttrs (old: {
                src = prev.fetchurl {
                  url = "http://pari.math.u-bordeaux.fr/pub/pari/packages/seadata-big.tar";
                  hash = "sha256-fE2yYkgIpbvSugD4tkSkOfBQhTLv1oCiR2EP3VgipfI=";
                };
              });
            })
            (final: prev: {
              # QD Package
              libqd = final.callPackage ({ lib, stdenv, fetchurl }:
                stdenv.mkDerivation rec {
                  pname = "qd";
                  version = "2.3.23";
                  src = fetchurl {
                    url =
                      "https://www.davidhbailey.com/dhbsoftware/qd-${version}.tar.gz";
                    hash =
                      "sha256-s+r0HOQT7AjzSO5z5ga9P/kgPkEcN3w8BGf4ms9p7iY=";
                  };

                  meta = with lib; {
                    description =
                      "A double-double and quad-double package for Fortran and C++";
                    homepage = "https://www.davidhbailey.com/dhbsoftware/";
                    license = {
                      deprecated = false;
                      free = true;
                      fullName =
                        "Lawrence Berkeley National Labs BSD variant license";
                      redistributable = true;
                      shortName = "BSD-3-Clause-LBNL";
                      spdxId = "BSD-3-Clause-LBNL";
                      url = "https://spdx.org/licenses/BSD-3-Clause-LBNL.html";
                    };
                    platforms = platforms.unix;
                  };
                }) { };

              fplll = prev.fplll.overrideAttrs
                (old: { buildInputs = old.buildInputs ++ [ final.libqd ]; });

              python3 = prev.python3 // {
                pkgs = prev.python3.pkgs.overrideScope
                  (python-self: python-super: {
                    fpylll = python-super.fpylll.overridePythonAttrs (old: {
                      HAVE_QD = true;
                      buildInputs = old.buildInputs ++ [ final.libqd ];
                    });
                  });
              };
              python3Packages = final.python3.pkgs;

            })

            # We don't need to run the sage tests here
            (final: prev: {
              sage = prev.sage.override { requireSageTests = false; };
            })
          ];
        };
      in {
        packages = {
          inherit (pkgs) sage python3 libqd fplll;
          py3-with-fpylll = (pkgs.python3.withPackages (ps: [ ps.fpylll ]));
        };
        apps = let sageApp = {
            type = "app";
            program = "${pkgs.sage}/bin/sage";
          }; in {
          default = sageApp;
          sage = sageApp;
          notebook = {
            type = "app";
            program = toString (pkgs.writeScript "sage-notebook" ''
              ${pkgs.sage}/bin/sage --notebook
            '');
          };
        };
      });
}
