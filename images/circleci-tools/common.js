import fetch from "node-fetch";

export async function getCircleCI(URL) {
    // console.log(`Fetching: ${URL}`);
    const res = await fetch(URL, {
        headers: {
            "Circle-Token": process.env["CIRCLECI_TOKEN"],
        },
    });
    if (res.status != 200) {
        console.error("Unexpected response from CircleCI: " + res.statusText);
        process.exit(1);
    }
    const res_1 = res;
    return await res_1.json();
}
