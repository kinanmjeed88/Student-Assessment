import fs from "node:fs";
import path from "node:path";

const projectRoot = process.cwd();
const configPath = path.join(projectRoot, "config", "android-signing.json");
const appGradlePath = path.join(projectRoot, "android", "app", "build.gradle");
const signingPropertiesPath = path.join(projectRoot, "android", "signing.properties");

if (!fs.existsSync(configPath) || !fs.existsSync(appGradlePath)) {
  throw new Error("Android signing configuration requires config/android-signing.json and android/app/build.gradle.");
}

const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
const keystorePassword = process.env.ANDROID_KEYSTORE_PASSWORD;
const keyPassword = process.env.ANDROID_KEY_PASSWORD;

if (!keystorePassword || !keyPassword) {
  throw new Error("Missing protected Android signing passwords.");
}

const signingProperties = [
  `storeFile=app/${config.keystoreFile}`,
  `storePassword=${keystorePassword}`,
  `keyAlias=${config.keyAlias}`,
  `keyPassword=${keyPassword}`,
].join("\n");
fs.writeFileSync(signingPropertiesPath, `${signingProperties}\n`, { mode: 0o600 });

let appGradle = fs.readFileSync(appGradlePath, "utf8");
const startMarker = "// STUDENT_RECORD_RELEASE_SIGNING_START";
const endMarker = "// STUDENT_RECORD_RELEASE_SIGNING_END";

if (!appGradle.includes(startMarker)) {
  const signingLoader = `${startMarker}
def releaseSigningProperties = new Properties()
def releaseSigningPropertiesFile = rootProject.file("signing.properties")
if (!releaseSigningPropertiesFile.exists()) {
    throw new GradleException("Missing Android release signing configuration.")
}
releaseSigningPropertiesFile.withInputStream { releaseSigningProperties.load(it) }
${endMarker}

`;
  appGradle = appGradle.replace("android {", `${signingLoader}android {`);
  appGradle = appGradle.replace(
    "    signingConfigs {\n",
    "    signingConfigs {\n        release {\n            storeFile rootProject.file(releaseSigningProperties['storeFile'])\n            storePassword releaseSigningProperties['storePassword']\n            keyAlias releaseSigningProperties['keyAlias']\n            keyPassword releaseSigningProperties['keyPassword']\n        }\n",
  );
  appGradle = appGradle.replace(
    "            signingConfig signingConfigs.debug\n            def enableShrinkResources",
    "            signingConfig signingConfigs.release\n            def enableShrinkResources",
  );
  fs.writeFileSync(appGradlePath, appGradle);
}

console.log("Configured Android release signing with protected environment values.");
