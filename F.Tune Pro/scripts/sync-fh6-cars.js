#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = path.resolve(__dirname, '..');
const SOURCE_URL = 'https://forza.net/fh6cars';
const OUTPUT_PATH = path.join(
  PROJECT_ROOT,
  'flutter_parallel',
  'assets',
  'data',
  'FH6_cars.json',
);

const CLASS_PRESETS = {
  D: {
    pi: 480,
    topSpeedKmh: 185,
    tireType: 'Street',
    differential: 'Street Differential',
  },
  C: {
    pi: 580,
    topSpeedKmh: 210,
    tireType: 'Street',
    differential: 'Street Differential',
  },
  B: {
    pi: 680,
    topSpeedKmh: 235,
    tireType: 'Sport',
    differential: 'Sport Differential',
  },
  A: {
    pi: 780,
    topSpeedKmh: 270,
    tireType: 'Sport',
    differential: 'Sport Differential',
  },
  S1: {
    pi: 860,
    topSpeedKmh: 315,
    tireType: 'Semi-Slick',
    differential: 'Race Differential',
  },
  S2: {
    pi: 940,
    topSpeedKmh: 360,
    tireType: 'Slick',
    differential: 'Race Differential',
  },
  R: {
    pi: 970,
    topSpeedKmh: 385,
    tireType: 'Slick',
    differential: 'Race Differential',
  },
  X: {
    pi: 999,
    topSpeedKmh: 400,
    tireType: 'Slick',
    differential: 'Race Differential',
  },
};

function decodeHtml(value) {
  return String(value || '')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'")
    .replace(/&#8217;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function normalizeClass(value) {
  return String(value || '').trim().toUpperCase();
}

function deriveModel(make, carName) {
  const withoutYear = String(carName || '').replace(/^\d{4}\s+/, '').trim();
  const exactPrefix = new RegExp(`^${escapeRegExp(make)}\\s+`, 'i');
  const stripped = withoutYear.replace(exactPrefix, '').trim();
  return stripped || withoutYear || 'Unknown';
}

function parseHtmlRows(html) {
  const rows = [];
  const tableMatch = html.match(/<table[^>]*>([\s\S]*?)<\/table>/i);
  if (!tableMatch) return rows;

  const rowMatches = tableMatch[1].match(/<tr[^>]*>[\s\S]*?<\/tr>/gi) || [];
  for (const rowHtml of rowMatches) {
    const cells = Array.from(rowHtml.matchAll(/<t[hd][^>]*>([\s\S]*?)<\/t[hd]>/gi))
      .map((match) => decodeHtml(match[1]));
    if (cells.length < 4) continue;
    if (cells[0].toLowerCase() === 'make') continue;
    rows.push({
      make: cells[0],
      carName: cells[1],
      carClass: cells[2],
      addOns: cells[3],
    });
  }

  return rows;
}

function parsePayloadRows(payloadText) {
  const payload = JSON.parse(payloadText);
  const tableText = payload.find(
    (entry) =>
      typeof entry === 'string' &&
      /\|\s*Make\s*\|\s*Car Name\s*\|\s*Car Class\s*\|\s*Add-Ons\s*\|/i.test(entry),
  );
  if (!tableText) {
    return [];
  }

  const lines = tableText
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.startsWith('|'));

  const rows = [];
  for (const line of lines) {
    if (/^\|\s*Make\s*\|/i.test(line) || /^\|\s*-+/i.test(line)) {
      continue;
    }
    const cells = line
      .replace(/^\|/, '')
      .replace(/\|$/, '')
      .split('|')
      .map((cell) => cell.trim());
    if (cells.length < 4) continue;
    rows.push({
      make: cells[0],
      carName: cells[1],
      carClass: cells[2],
      addOns: cells[3],
    });
  }
  return rows;
}

async function loadSourceRows() {
  const response = await fetch(SOURCE_URL, {
    headers: {
      'User-Agent': 'Mozilla/5.0',
    },
    cache: 'no-store',
  });
  if (!response.ok) {
    throw new Error(`Cannot fetch FH6 source page (${response.status}).`);
  }

  const html = await response.text();
  const htmlRows = parseHtmlRows(html);
  if (htmlRows.length > 0) {
    return htmlRows;
  }

  const payloadPath = html.match(
    /id="__NUXT_DATA__"[^>]*data-src="([^"]+)"/i,
  )?.[1];
  if (!payloadPath) {
    throw new Error('Cannot locate FH6 table data in HTML or payload metadata.');
  }

  const payloadUrl = new URL(payloadPath, SOURCE_URL).href;
  const payloadResponse = await fetch(payloadUrl, {
    headers: {
      'User-Agent': 'Mozilla/5.0',
    },
    cache: 'no-store',
  });
  if (!payloadResponse.ok) {
    throw new Error(`Cannot fetch FH6 payload (${payloadResponse.status}).`);
  }

  return parsePayloadRows(await payloadResponse.text());
}

function buildCarSpec(row) {
  const normalizedClass = normalizeClass(row.carClass);
  const preset = CLASS_PRESETS[normalizedClass] || CLASS_PRESETS.A;

  return {
    brand: row.make,
    model: deriveModel(row.make, row.carName),
    pi: preset.pi,
    topSpeedKmh: preset.topSpeedKmh,
    differential: preset.differential,
    tireType: preset.tireType,
    driveType: 'RWD',
  };
}

async function main() {
  const sourceRows = await loadSourceRows();
  if (!sourceRows.length) {
    throw new Error('No FH6 car rows were parsed from the official source.');
  }

  const cars = sourceRows
    .map(buildCarSpec)
    .sort((left, right) => {
      const brandCompare = left.brand.localeCompare(right.brand);
      if (brandCompare !== 0) return brandCompare;
      return left.model.localeCompare(right.model);
    });

  fs.mkdirSync(path.dirname(OUTPUT_PATH), { recursive: true });
  fs.writeFileSync(OUTPUT_PATH, `${JSON.stringify(cars, null, 2)}\n`, 'utf8');

  const classCounts = sourceRows.reduce((acc, row) => {
    const key = normalizeClass(row.carClass) || 'UNKNOWN';
    acc[key] = (acc[key] || 0) + 1;
    return acc;
  }, {});

  console.log('FH6 car sync completed.');
  console.log(`Source: ${SOURCE_URL}`);
  console.log(`Rows parsed: ${sourceRows.length}`);
  console.log(`Output: ${OUTPUT_PATH}`);
  console.log(`Class distribution: ${JSON.stringify(classCounts)}`);
  console.log(
    'Derived fields: pi/topSpeedKmh/tireType/differential are mapped from FH6 Car Class because the official page only exposes Make, Car Name, Car Class, and Add-Ons.',
  );
}

main().catch((error) => {
  console.error('sync:fh6-cars failed.');
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
