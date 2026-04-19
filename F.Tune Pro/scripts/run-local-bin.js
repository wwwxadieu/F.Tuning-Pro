#!/usr/bin/env node

const { spawn } = require('node:child_process');
const path = require('node:path');

const [, , binName, ...binArgs] = process.argv;

if (!binName) {
  console.error('Usage: node scripts/run-local-bin.js <bin> [...args]');
  process.exit(1);
}

const env = { ...process.env };
delete env.ELECTRON_RUN_AS_NODE;

const knownBins = {
  electron: path.join(__dirname, '..', 'node_modules', 'electron', 'cli.js'),
  electronmon: path.join(
    __dirname,
    '..',
    'node_modules',
    'electronmon',
    'bin',
    'cli.js',
  ),
};

const binPath = knownBins[binName];

if (!binPath) {
  console.error(`Unsupported local bin: ${binName}`);
  process.exit(1);
}

const child = spawn(process.execPath, [binPath, ...binArgs], {
  stdio: 'inherit',
  env,
});

child.on('exit', (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exit(code ?? 0);
});

child.on('error', (error) => {
  console.error(`Failed to launch ${binName}:`, error.message);
  process.exit(1);
});
