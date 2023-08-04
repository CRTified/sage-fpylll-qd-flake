{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
        apps = {
          sage = {
            type = "app";
            program = "${pkgs.sage}/bin/sage";
          };
          notebook = {
            type = "app";
            program = toString (pkgs.writeScript "sage-notebook" ''
              ${pkgs.sage}/bin/sage --notebook
            '');
          };
        };
      });
}
