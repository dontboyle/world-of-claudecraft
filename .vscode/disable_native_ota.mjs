// Fork-local LAN builds: stop the Capacitor OTA updater from pulling the production web
// bundle (which talks to worldofclaudecraft.com) into an app built for a LAN server.
// Patches only the generated, git-ignored copy `cap sync` writes; capacitor.config.ts
// stays exactly as upstream ships it. Run after `cap sync android`.
import { readFileSync, writeFileSync } from 'node:fs';

const file = 'android/app/src/main/assets/capacitor.config.json';
const config = JSON.parse(readFileSync(file, 'utf8'));
config.plugins ??= {};
config.plugins.CapacitorUpdater = { ...config.plugins.CapacitorUpdater, autoUpdate: false };
writeFileSync(file, `${JSON.stringify(config, null, 2)}\n`);
console.log(`${file}: CapacitorUpdater.autoUpdate=false`);
