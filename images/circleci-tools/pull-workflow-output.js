#!/usr/bin/env node

import fetch from "node-fetch";
import fs from "fs/promises";
import path from "path";
import os from "os";

import { getCircleCI } from "./common.js";
import * as CONSTANTS from "./constants.js";

if (process.argv.length < 3) {
    console.error(
        `usage: pull-workflow-output.js <circle CI workflow id> [<output dir>]`
    );
    process.exit(1);
}

if (!process.env["CIRCLECI_TOKEN"]) {
    console.error(`A CircleCI auth token is required in: CIRCLECI_TOKEN`);
    process.exit(1);
}

main(...process.argv.slice(2)).catch((e) => {
    console.trace(e);
    process.exit(1);
});

async function main(workflowId, outputDir) {
    outputDir = await handleOutputDir(outputDir);

    console.log(`Getting workflow job data for ${workflowId}`);

    const workflowJobs = await getCircleCI(
        `${CONSTANTS.V2_API_BASE}/workflow/${workflowId}/job`
    );
    console.log(`This workflow has ${workflowJobs.items.length} jobs`);

    if (workflowJobs.next_page_token) {
        console.trace("Unsupported");
        process.exit(1);
    }

    await processJobs(workflowJobs.items, outputDir);

    console.log(`Output written to ${outputDir}`);
}

async function handleOutputDir(outputDir) {
    if (!outputDir) {
        outputDir = await fs
            .mkdtemp(path.join(os.tmpdir(), "circle-ci-"))
            .catch((err) => {
                console.error(`Cannot make temp dir for output: ${err}`);
                process.exit(1);
            });
    } else {
        await fs.stat(outputDir).catch((err) => {
            if (err.code === "ENOENT") {
                fs.mkdir(outputDir).catch((err) => {
                    console.error(`Cannot make dir for output: ${err}`);
                    process.exit(1);
                });
            } else {
                console.trace(err);
                process.exit(1);
            }
        });
    }
    return outputDir;
}

async function processJobs(jobs, outputDir) {
    jobs = jobs.filter((job) => {
        if (!job.job_number) {
            console.warn(`${job.name} is missing a job_number, will skip`);
            return false;
        }
        return true;
    });

    await Promise.all(
        jobs.map(async (job) => {
            const detail = await getCircleCI(
                `${CONSTANTS.V1_1_API_BASE}/project/gh/stackrox/rox/${job.job_number}`
            );
            console.log(`Job ${job.name} has ${detail.steps.length} steps`);
            detail.name = job.name;
            await processJob(detail, outputDir);
        })
    );
}

async function processJob(job, outputDir) {
    let output = "";
    for (let i = 0; i < job.steps.length; i++) {
        const step = job.steps[i];

        if (step.actions.length != 1) {
            console.trace("Unsupported");
            process.exit(1);
        }
        const action = step.actions[0];
        if (!action.has_output) {
            continue;
        }
        if (!action.output_url) {
            console.trace("Unsupported");
            process.exit(1);
        }
        output += `${CONSTANTS.STEP_MARKER}: ${action.name} <<<<\n`;
        output += action.start_time + "\n\n";
        output += await getOutput(action.output_url);
        if (i != job.steps.length - 1) {
            output += "\n\n";
        }
    }
    const outfile = path.join(outputDir, job.name + "-out.txt");
    await fs.writeFile(outfile, output).catch((e) => {
        console.error(`Could not write output file: ${e}`);
        process.exit(1);
    });
    console.log(`Wrote output for ${job.name} to ${outfile}`);
}

async function getOutput(URL) {
    // console.log(`Fetching: ${URL}`);
    const res = await fetch(URL);
    if (res.status != 200) {
        console.error(
            "Unexpected response from output site: " + res.statusText
        );
        process.exit(1);
    }
    const messages = await res.json();
    messages.forEach((msg) => {
        // Sanity check the response
        if (msg.type != "out" && msg.type != "err") {
            console.error("Unexpected msg.type from output site: " + msg.type);
            process.exit(1);
        }
        if (!msg.message) {
            console.error("empty message", msg);
            process.exit(1);
        }
    });
    return messages.map((msg) => msg.message).join("\n");
}
