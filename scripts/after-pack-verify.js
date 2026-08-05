const fs = require("fs");
const path = require("path");

// The bundled Next.js standalone server is shipped via `extraResources`, which
// is easy to break silently: electron-builder unconditionally prunes a
// `node_modules` directory sitting at the root of a copy source (see
// app-builder-lib/out/util/filter.js), so a seemingly reasonable config can
// produce an app that packages fine and then dies at launch with
// `Cannot find module 'next'`. Fail the build here instead of shipping that.
const REQUIRED = [
  path.join("standalone", "server.js"),
  path.join("standalone", "package.json"),
  path.join("standalone", ".next", "static"),
  path.join("standalone", "node_modules", "next", "package.json"),
  path.join("standalone", "node_modules", "react", "package.json"),
];

function resourcesDir(context) {
  if (context.electronPlatformName === "darwin") {
    const app = `${context.packager.appInfo.productFilename}.app`;
    return path.join(context.appOutDir, app, "Contents", "Resources");
  }
  return path.join(context.appOutDir, "resources");
}

module.exports = async function afterPack(context) {
  const resources = resourcesDir(context);
  const missing = REQUIRED.filter((rel) => !fs.existsSync(path.join(resources, rel)));

  if (missing.length > 0) {
    throw new Error(
      `Packaged app is missing required files under ${resources}:\n` +
        missing.map((rel) => `  - ${rel}`).join("\n") +
        `\n\nThe app would start and immediately fail with "Server process exited early".` +
        `\nCheck the extraResources config in package.json.`
    );
  }

  console.log(`  • verified bundled server  platform=${context.electronPlatformName} arch=${context.arch}`);
};
