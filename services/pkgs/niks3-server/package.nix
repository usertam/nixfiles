{ niks3-server }:

niks3-server.overrideAttrs {
  postPatch = ''
    cp ${./index.html} server/landing_page.html
  '';
}
