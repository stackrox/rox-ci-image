#!/usr/bin/env node

import fs from "fs/promises";
import path from "path";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";

import * as CONSTANTS from "./constants.js";

const argv = yargs(hideBin(process.argv))
    .usage("Checks for key values in build logs\n\nUsage: $0 [options]")
    .option("env-file", {
        alias: "e",
        description: "an env file to load",
        type: "string",
        demandOption: true,
    })
    .option("build-output-dir", {
        alias: "b",
        description: "where build output lives",
        type: "string",
        demandOption: true,
    })
    .option("skip", {
        description: "these keys will be skipped",
        type: "array",
        default: [],
    })
    .option("skip-re", {
        description: "keys that match this regex will be skipped",
        type: "array",
        default: [],
    })
    .help()
    .alias("help", "h").argv;

const SKIP_KEYS = [
    "ANCHORE_USERNAME",
    "CI",
    "CIRCLECI",
    "GOOGLE_OPENSHIFT_4_CREDENTIALS-client_email",
    "GOPATH",
    "HOME",
    "INFLUXDB_USER",
    "NO_PROXY",
    ...argv["skip"],
];

const SKIP_KEY_MATCHES = [
    new RegExp("^CIRCLE_"),
    new RegExp("^CI_PULL_REQUEST"),
    new RegExp("^(GCLOUD|GKE_SERVICE|GOOGLE|KOPS|OPENSHIFT).*-project_id$"),
    new RegExp("^(GCLOUD|GKE_SERVICE|GOOGLE|KOPS|OPENSHIFT).*-type$"),
    ...argv["skip-re"].map((skip) => new RegExp(skip)),
];

const SKIP_VALUES = ["", '""', "true", "false", "null"];

const SKIP_VALUE_MATCHES = [new RegExp("^\\d$")];

main(argv["env-file"], argv["build-output-dir"])
    .then((matchCount) => {
        process.exit(matchCount === 0 ? 0 : 1);
    })
    .catch((e) => {
        console.trace(e);
        process.exit(1);
    });

async function main(envFile, outputDir) {
    const envData = await fs.readFile(envFile, { encoding: "utf8" });

    const envsToCheck = getEnvsToCheck(envData);

    const files = await fs.readdir(outputDir, { encoding: "utf8" });

    let envMatchCount = 0;
    for (const file of files) {
        const contents = await fs.readFile(path.join(outputDir, file), {
            encoding: "utf8",
        });
        for (const env of envsToCheck) {
            envMatchCount += checkForEnvInFileContents(env, file, contents);
        }
    }
    return envMatchCount;
}

function checkForEnvInFileContents(env, file, contents) {
    // console.log(`Checking ${env.key} in ${file}`);
    let envMatchCount = 0;
    let envValueIndex = contents.indexOf(env.value, 0);
    while (envValueIndex !== -1) {
        let stepMarkerIndex = contents.indexOf(CONSTANTS.STEP_MARKER, 0);
        let priorStepMarkerIndex = -1;
        while (stepMarkerIndex !== -1 && stepMarkerIndex < envValueIndex) {
            priorStepMarkerIndex = stepMarkerIndex;
            stepMarkerIndex = contents.indexOf(
                CONSTANTS.STEP_MARKER,
                stepMarkerIndex + 1
            );
        }
        console.log(`Key "${env.key}"'s value was found in ${file}`);
        envMatchCount++;
        if (priorStepMarkerIndex !== -1) {
            let stepMarkerContents = contents.substr(
                priorStepMarkerIndex,
                1024
            );
            stepMarkerContents = stepMarkerContents.split(/\n/)[0];
            console.log("\t" + stepMarkerContents);
        }

        envValueIndex = contents.indexOf(env.value, envValueIndex + 1);
    }
    return envMatchCount;
}

function getEnvsToCheck(envData) {
    return envData
        .split(/\n/)
        .filter((line) => !!line)
        .map((line) => {
            const bits = line.split(/=/);
            return {
                key: bits[0],
                value: bits.slice(1).join("="),
            };
        })
        .filter((env) => SKIP_VALUES.every((skip) => skip !== env.value))
        .filter((env) =>
            SKIP_VALUE_MATCHES.every((skip) => !skip.test(env.value))
        )
        .map((env) => {
            try {
                // Also check the values of any nested JSON values individually.
                const obj = JSON.parse(env.value);
                const flattened = flattenObject(obj, env.key);
                const more = [
                    env, // Include the env.value in its original form.
                    ...Object.keys(flattened).map((item) => {
                        return { key: item, value: flattened[item] };
                    }),
                ];
                return more;
            } catch (e) {
                return env;
            }
        })
        .flat() // flatten out the arrays of nested JSON values to check
        .filter((env) => SKIP_KEYS.every((skip) => skip != env.key))
        .filter((env) => SKIP_KEY_MATCHES.every((skip) => !skip.test(env.key)));
}

function flattenObject(obj, path) {
    let flattened = {};

    Object.keys(obj).forEach((key) => {
        if (typeof obj[key] === "object" && obj[key] !== null) {
            flattened = {
                ...flattened,
                ...flattenObject(obj[key], path + "-" + key),
            };
        } else {
            flattened[path + "-" + key] = obj[key];
        }
    });

    return flattened;
}
