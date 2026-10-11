{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm,
  nodejs-slim,
  makeBinaryWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "opndrive";
  version = "3.1.1";

  src = fetchFromGitHub {
    owner = "Opndrive";
    repo = "opndrive";
    tag = "v${finalAttrs.version}";
    hash = "sha256-3kdCKzH1mOPICiEiX3vzypCI7faMD1m5769zfBxtuTU=";
  };

  # Same subset as upstream Dockerfile, skips the docs site.
  pnpmWorkspaces = [ "frontend..." "@opndrive/s3-api..." ];

  # pnpm no longer reads settings from package.json; carry the patches over to
  # pnpm-workspace.yaml, or they mismatch the lockfile. JSON is valid YAML.
  prePnpmInstall = ''
    echo "patchedDependencies: $(node -p 'JSON.stringify(require("./package.json").pnpm.patchedDependencies)')" >> pnpm-workspace.yaml
  '';

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src pnpmWorkspaces prePnpmInstall;
    fetcherVersion = 4;
    hash = "sha256-qhMoVVH9MvhZS9jCOoW7ruGkMsJcrHamGciyC01N56E=";
  };

  nativeBuildInputs = [
    nodejs-slim
    pnpm
    pnpmConfigHook
    makeBinaryWrapper
  ];

  env = {
    NEXT_TELEMETRY_DISABLED = "1";
    # Unset means enabled, which wants a WordPress backend.
    NEXT_PUBLIC_ENABLE_BLOG = "false";
  };

  postPatch = ''
    # Emit a self-contained server, instead of shipping the whole node_modules.
    substituteInPlace frontend/next.config.ts \
      --replace-fail "const nextConfig: NextConfig = {" \
        "const nextConfig: NextConfig = { output: 'standalone', generateBuildId: () => process.env.NEXT_BUILD_ID ?? null,"

    # NEXT_PUBLIC_* is inlined at build time; read the site URL from SITE_URL
    # at runtime instead, and render the routes using it per request.
    substituteInPlace frontend/src/config/links.ts frontend/src/lib/seo/config.ts \
      --replace-fail process.env.NEXT_PUBLIC_SITE_URL process.env.SITE_URL
    for route in robots sitemap; do
      echo "export const dynamic = 'force-dynamic';" >> frontend/src/app/$route.ts
    done
  '';

  # Make the output reproducible.
  preBuild = ''
    # Next.js fills its webpack entries as async page handlers finish, and that
    # order leaks into the manifests. It is a race so nothing can depend on it;
    # sort the entries instead.
    substituteInPlace node_modules/.pnpm/next@*/node_modules/next/dist/build/entries.js \
      --replace-fail "    // Optimization: If there's only one instrumentation hook in edge compiler" \
        "    for (const entries of [client, server, edgeServer]) for (const name of Object.keys(entries).sort()) { const entry = entries[name]; delete entries[name]; entries[name] = entry; }
        // Optimization: If there's only one instrumentation hook in edge compiler"

    # Next.js draws a random build id and keys on every build; derive them from
    # $out instead. Nothing in the store is secret anyway, and opndrive uses
    # neither draft mode nor server actions.
    derive() {
      node -e 'process.stdout.write(require("crypto").createHash("sha256").update(process.argv[1]).digest(process.argv[2]))' "$out:$1" "$2"
    }
    export NEXT_BUILD_ID=$(derive build-id hex | head -c 21)
    export NEXT_SERVER_ACTIONS_ENCRYPTION_KEY=$(derive server-actions base64)
    mkdir -p frontend/.next/cache
    cat > frontend/.next/cache/.previewinfo <<EOF
    {"previewModeId":"$(derive preview-id hex | head -c 32)","previewModeSigningKey":"$(derive preview-signing hex)","previewModeEncryptionKey":"$(derive preview-encryption hex)","expireAt":8640000000000000}
    EOF
  '';

  buildPhase = ''
    runHook preBuild
    pnpm --filter @opndrive/s3-api build
    pnpm --filter frontend build
    runHook postBuild
  '';

  # Standalone output is rooted at the workspace, with the app under frontend/.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/share
    cp -r frontend/.next/standalone $out/share/opndrive
    cp -r frontend/public $out/share/opndrive/frontend/public
    cp -r frontend/.next/static $out/share/opndrive/frontend/.next/static

    # Next.js writes its image cache under .next/cache; point it out of the store.
    ln -s /var/cache/opndrive $out/share/opndrive/frontend/.next/cache

    # Next.js can only listen on a TCP port. Under systemd socket activation,
    # have its server take the inherited socket instead.
    cat > $out/share/opndrive/listen-fds.cjs <<'EOF'
    if (process.env.LISTEN_PID === String(process.pid) && process.env.LISTEN_FDS === "1") {
      const net = require("node:net");
      const listen = net.Server.prototype.listen;
      net.Server.prototype.listen = function (...args) {
        net.Server.prototype.listen = listen;
        return listen.call(this, { fd: 3 }, ...args.filter((arg) => typeof arg === "function"));
      };
    }
    EOF

    makeWrapper ${lib.getExe nodejs-slim} $out/bin/opndrive \
      --add-flags "--require $out/share/opndrive/listen-fds.cjs" \
      --add-flags $out/share/opndrive/frontend/server.js

    runHook postInstall
  '';

  meta = {
    description = "Open-source web interface for S3-compatible storage";
    homepage = "https://opndrive.app";
    license = lib.licenses.agpl3Only;
    mainProgram = "opndrive";
    platforms = lib.platforms.linux;
  };
})
