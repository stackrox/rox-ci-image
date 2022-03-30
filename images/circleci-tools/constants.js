export const STEP_MARKER = ">>>> STEP";
export const V1_1_API_BASE = "https://circleci.com/api/v1.1";
export const V2_API_BASE = "https://circleci.com/api/v2";

export const SKIP_KEYS = [
    "rvm_prefix",
    "ANCHORE_USERNAME",
    "CI",
    "CIRCLECI",
    "DBUS_SESSION_BUS_ADDRESS",
    "DISPLAY",
    "GIT_ASKPASS",
    "GOPATH",
    "HOME",
    "IMAGE",
    "INFLUXDB_USER",
    "LANG",
    "LOGNAME",
    "MOTD_SHOWN",
    "NO_PROXY",
    "PWD",
    "SHELL",
    "SKIP_KEYS",
    "SKIP_KEYS_RE",
    "SUDO_USER",
    "TAG",
    "USER",
];

export const SKIP_KEY_MATCHES = [
    new RegExp("^CIRCLE_"),
    new RegExp("^CIRCLECI_"),
    new RegExp("^CI_PULL_REQUEST"),
    new RegExp("^(GCLOUD|GKE_SERVICE|GOOGLE|KOPS|OPENSHIFT).*-client_email$"),
    new RegExp("^(GCLOUD|GKE_SERVICE|GOOGLE|KOPS|OPENSHIFT).*-project_id$"),
    new RegExp("^(GCLOUD|GKE_SERVICE|GOOGLE|KOPS|OPENSHIFT).*-type$"),
    new RegExp("^XDG_SESSION_"),
];

export const SKIP_VALUES = ["", '""', "true", "false", "null", "yes", "no"];

export const SKIP_VALUE_MATCHES = [new RegExp("^\\d$")];

export const B64_RE = new RegExp(
    "^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{2}==)?$"
);
