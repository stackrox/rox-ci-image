#!/usr/bin/env node

import { getCircleCI } from "./common.js";
import * as CONSTANTS from "./constants.js";

if (process.argv.length < 3) {
    console.error(
        `usage: poll-for-workflow-completion.js <timeout in seconds>`
    );
    process.exit(1);
}

if (!process.env["CIRCLECI_TOKEN"]) {
    console.error(`A CircleCI auth token is required in: CIRCLECI_TOKEN`);
    process.exit(1);
}

// These envs should be provided by Circle CI

if (!process.env["CIRCLE_WORKFLOW_ID"]) {
    console.error(`A CircleCI workflow ID is required in: CIRCLE_WORKFLOW_ID`);
    process.exit(1);
}

if (!process.env["CIRCLE_PROJECT_REPONAME"]) {
    console.error(
        `A CircleCI env denoting the project is required: CIRCLE_PROJECT_REPONAME`
    );
    process.exit(1);
}
const CIRCLE_PROJECT_REPONAME = process.env["CIRCLE_PROJECT_REPONAME"];

main(process.env["CIRCLE_WORKFLOW_ID"], ...process.argv.slice(2)).catch((e) => {
    console.trace(e);
    process.exit(1);
});

async function main(workflowId, timeoutSeconds) {
    const workflow = await getCircleCI(
        `${CONSTANTS.V2_API_BASE}/workflow/${workflowId}`
    );

    const timeoutMS = parseInt(timeoutSeconds) * 1000;
    const startTimeMS = Date.now();
    while (startTimeMS + timeoutMS > Date.now()) {
        const workflowJobs = await getCircleCI(
            `${CONSTANTS.V2_API_BASE}/workflow/${workflowId}/job`
        );

        if (workflowJobs.next_page_token) {
            console.trace("Unsupported");
            process.exit(1);
        }

        if (checkThatAllJobsAreComplete(workflowJobs.items, workflow)) {
            console.log("All other jobs in the workflow are complete");
            process.exit(0);
        }
        console.log("Will wait 60 seconds and check again");
        await sleep(60000);
    }
    console.log("Reached timeout");
    process.exit(1);
}

function checkThatAllJobsAreComplete(jobs, workflow) {
    let isComplete = true;
    for (const job of jobs) {
        if (
            process.env["CIRCLE_BUILD_NUM"] &&
            process.env["CIRCLE_BUILD_NUM"] === "" + job.job_number
        ) {
            // ignore the build/job that is checking for completion
            continue;
        }
        if (!job.status) {
            console.log(`a job without a status: ${getJobURL(workflow, job)}`);
            process.exit(1);
        }
        if (job.status === "running") {
            console.log(
                `Still running ${job.name}: ${getJobURL(workflow, job)}`
            );
            isComplete = false;
        }
    }
    return isComplete;
}

function getJobURL(workflow, job) {
    return `https://app.circleci.com/pipelines/github/stackrox/${CIRCLE_PROJECT_REPONAME}/${workflow.pipeline_number}/workflows/${workflow.id}/jobs/${job.job_number}`;
}

function sleep(ms) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms);
    });
}
