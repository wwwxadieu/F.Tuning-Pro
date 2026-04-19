#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = path.resolve(__dirname, '..');
const CARS_FILE_PATH = path.join(PROJECT_ROOT, 'FH5_cars.json');
const SOURCE_SHEET_ID = '1yucDOQ2nRaCcC4y4unl72Um7N_pQXuaI6gZqzf0Tl3M';
const SOURCE_URL = `https://docs.google.com/spreadsheets/d/${SOURCE_SHEET_ID}/gviz/tq?tqx=out:json`;

function normalizeText(value) {
    return String(value || '')
        .normalize('NFD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/['’`".]/g, '')
        .replace(/&/g, ' and ')
        .replace(/[^a-zA-Z0-9]+/g, ' ')
        .trim()
        .toLowerCase();
}

function buildKey(brand, model) {
    return `${normalizeText(brand)}|||${normalizeText(model)}`;
}

function buildFullKey(brand, model) {
    return normalizeText(`${brand} ${model}`);
}

function toNumber(value) {
    if (value === null || value === undefined || value === '') {
        return null;
    }

    const numeric = Number(value);
    return Number.isFinite(numeric) ? numeric : null;
}

function mphToKmh(valueMph) {
    if (!Number.isFinite(valueMph)) {
        return null;
    }

    return Number((valueMph * 1.60934).toFixed(1));
}

function normalizeDriveType(value) {
    const normalized = String(value || '').trim().toUpperCase();
    if (normalized === 'FWD' || normalized === 'RWD' || normalized === 'AWD') {
        return normalized;
    }
    return null;
}

function buildAliasMap() {
    return new Map([
        [buildKey('Eagle', 'Speedster'), buildKey('Eagle (U.K.)', 'Speedster')],
        [buildKey('Ford', '#66 Ford Racing GTLM Le Mans'), buildKey('Ford', '#66 Ford Racing GT Le Mans')],
        [buildKey('Ford', 'Mustang SVT Cobra R'), buildKey('Ford', 'SVT Cobra R')],
        [buildKey('Pagani', 'Huayra BC'), buildKey('Pagani', 'Huayra BC Coupe')],
        [buildKey('Pagani', 'Huayra Coupe'), buildKey('Pagani', 'Huayra')]
    ]);
}

function parseGoogleSheetResponse(rawText) {
    const jsonText = rawText.match(/setResponse\((.*)\);?/s)?.[1];
    if (!jsonText) {
        throw new Error('Failed to parse Google Sheet response payload.');
    }

    return JSON.parse(jsonText);
}

function buildSpecMaps(sheetRows) {
    const byBrandModel = new Map();
    const byFullName = new Map();

    sheetRows.forEach((row) => {
        const cells = row.c || [];
        const brand = cells[5]?.v;
        const model = cells[6]?.v;
        if (!brand || !model) {
            return;
        }

        const payload = {
            pi: toNumber(cells[17]?.v),
            topSpeedKmh: mphToKmh(toNumber(cells[54]?.v)),
            driveType: normalizeDriveType(cells[34]?.v)
        };

        const directKey = buildKey(brand, model);
        const fullKey = buildFullKey(brand, model);

        if (!byBrandModel.has(directKey)) {
            byBrandModel.set(directKey, payload);
        }

        if (!byFullName.has(fullKey)) {
            byFullName.set(fullKey, payload);
        }
    });

    return { byBrandModel, byFullName };
}

async function loadSourceSpecMaps() {
    const response = await fetch(SOURCE_URL, { cache: 'no-store' });
    if (!response.ok) {
        throw new Error(`Cannot fetch source sheet (${response.status}).`);
    }

    const raw = await response.text();
    const parsed = parseGoogleSheetResponse(raw);
    const sheetRows = parsed?.table?.rows || [];
    return buildSpecMaps(sheetRows);
}

function syncCarsWithSpecs(cars, maps, aliases) {
    const { byBrandModel, byFullName } = maps;

    let matched = 0;
    let matchedByAlias = 0;
    let updatedPi = 0;
    let updatedTopSpeed = 0;
    let updatedDriveType = 0;
    let unchanged = 0;

    const nextCars = cars.map((car) => {
        const directKey = buildKey(car.brand, car.model);
        const fullKey = buildFullKey(car.brand, car.model);

        let spec = byBrandModel.get(directKey) || byFullName.get(fullKey);
        if (!spec) {
            const aliasKey = aliases.get(directKey);
            if (aliasKey) {
                spec = byBrandModel.get(aliasKey);
                if (spec) {
                    matchedByAlias += 1;
                }
            }
        }

        if (!spec) {
            unchanged += 1;
            return {
                ...car,
                pi: Object.prototype.hasOwnProperty.call(car, 'pi') ? car.pi : null,
                topSpeedKmh: Object.prototype.hasOwnProperty.call(car, 'topSpeedKmh') ? car.topSpeedKmh : null,
                driveType: Object.prototype.hasOwnProperty.call(car, 'driveType') ? normalizeDriveType(car.driveType) : null
            };
        }

        matched += 1;
        const nextCar = { ...car };

        const nextPi = spec.pi ?? (Object.prototype.hasOwnProperty.call(car, 'pi') ? car.pi : null);
        const nextTopSpeed = spec.topSpeedKmh ?? (Object.prototype.hasOwnProperty.call(car, 'topSpeedKmh') ? car.topSpeedKmh : null);
        const nextDriveType = spec.driveType ?? (Object.prototype.hasOwnProperty.call(car, 'driveType') ? normalizeDriveType(car.driveType) : null);

        if (nextCar.pi !== nextPi) {
            updatedPi += 1;
        }
        if (nextCar.topSpeedKmh !== nextTopSpeed) {
            updatedTopSpeed += 1;
        }
        if (normalizeDriveType(nextCar.driveType) !== nextDriveType) {
            updatedDriveType += 1;
        }

        nextCar.pi = nextPi;
        nextCar.topSpeedKmh = nextTopSpeed;
        nextCar.driveType = nextDriveType;
        return nextCar;
    });

    const missingPi = nextCars.filter((car) => car.pi === null || car.pi === undefined).length;
    const missingTopSpeed = nextCars.filter((car) => car.topSpeedKmh === null || car.topSpeedKmh === undefined).length;
    const missingDriveType = nextCars.filter((car) => !normalizeDriveType(car.driveType)).length;

    return {
        nextCars,
        stats: {
            total: nextCars.length,
            matched,
            matchedByAlias,
            unchanged,
            updatedPi,
            updatedTopSpeed,
            updatedDriveType,
            missingPi,
            missingTopSpeed,
            missingDriveType
        }
    };
}

async function main() {
    if (!fs.existsSync(CARS_FILE_PATH)) {
        throw new Error(`Missing file: ${CARS_FILE_PATH}`);
    }

    const cars = JSON.parse(fs.readFileSync(CARS_FILE_PATH, 'utf8'));
    if (!Array.isArray(cars)) {
        throw new Error('FH5_cars.json must contain an array.');
    }

    const maps = await loadSourceSpecMaps();
    const aliases = buildAliasMap();
    const { nextCars, stats } = syncCarsWithSpecs(cars, maps, aliases);

    fs.writeFileSync(CARS_FILE_PATH, `${JSON.stringify(nextCars, null, 2)}\n`, 'utf8');

    console.log('FH5 specs sync completed.');
    console.log(`Source: ${SOURCE_URL}`);
    console.log(`Total cars: ${stats.total}`);
    console.log(`Matched: ${stats.matched} (via alias: ${stats.matchedByAlias})`);
    console.log(`Updated PI rows: ${stats.updatedPi}`);
    console.log(`Updated Top Speed rows: ${stats.updatedTopSpeed}`);
    console.log(`Updated Drive Type rows: ${stats.updatedDriveType}`);
    console.log(`Missing PI after sync: ${stats.missingPi}`);
    console.log(`Missing topSpeedKmh after sync: ${stats.missingTopSpeed}`);
    console.log(`Missing driveType after sync: ${stats.missingDriveType}`);
    console.log(`Unchanged rows: ${stats.unchanged}`);
}

main().catch((error) => {
    console.error('sync:fh5-specs failed.');
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
});
