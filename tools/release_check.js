// Release gate: the version string in MarkedStick.mod, the git tag on HEAD and
// the release zip in build/ must all say the same number.
//
// Why this exists: DMF prints the .mod's `version` field in the mod list. If
// the tag says v0.1.0 and that field says anything else, every player who
// installs the release sees the wrong number and concludes they downloaded the
// wrong file. The three have to move together, so they are checked rather than
// trusted to memory.
//
// Run:  node tools/release_check.js
//
// Exit code 0 means the three agree. Anything else is printed as FAIL.
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const ROOT = path.join(__dirname, "..");
const MOD_DIR = path.join(ROOT, "MarkedStick");
const BUILD_DIR = path.join(ROOT, "build");

const lines = [];
let fails = 0;

function check(ok, msg, detail) {
	lines.push((ok ? "PASS  " : "FAIL  ") + msg + (detail ? "  [" + detail + "]" : ""));
	if (!ok) fails++;
}

function warn(ok, msg) {
	if (!ok) lines.push("WARN  " + msg);
}

// ---------------------------------------------------------------------------
// 1. the field DMF reads
// ---------------------------------------------------------------------------
const modText = fs.readFileSync(path.join(MOD_DIR, "MarkedStick.mod"), "utf8");
const match = modText.match(/version\s*=\s*"([^"]+)"/);

if (!match) {
	console.log("FAIL  MarkedStick.mod has no version field at all");
	process.exit(1);
}

const version = match[1];
check(/^\d+\.\d+\.\d+$/.test(version), "the .mod version is a plain x.y.z string", version);

// ---------------------------------------------------------------------------
// 2. the tag on HEAD
// ---------------------------------------------------------------------------
let tag = null;

try {
	tag = execFileSync("git", ["-C", ROOT, "describe", "--tags", "--exact-match", "HEAD"], {
		encoding: "utf8",
		stdio: ["ignore", "pipe", "ignore"],
	}).trim();
} catch (err) {
	tag = null;
}

check(tag !== null, "HEAD carries a tag (an untagged release cannot be re-fetched)", tag || "none");
if (tag) {
	check(tag === "v" + version, "the tag is exactly v" + version, "tag " + tag);
}

// ---------------------------------------------------------------------------
// 3. the release zip
// ---------------------------------------------------------------------------
const zips = fs.existsSync(BUILD_DIR)
	? fs.readdirSync(BUILD_DIR).filter((f) => f.toLowerCase().endsWith(".zip"))
	: [];

check(zips.length === 1, "build/ holds exactly one release zip (history lives in build/dev/)",
	zips.length + " found: " + (zips.join(", ") || "none"));

if (zips.length === 1) {
	const expected = "MarkedStick_v" + version + ".zip";
	check(zips[0] === expected, "the zip is named after the same version", "expected " + expected + ", found " + zips[0]);

	// Staleness: the zip has to be newer than the newest source file, or it was
	// built before the last edit. A tolerance of two seconds keeps a fresh git
	// clone (where every mtime is checkout time) from warning spuriously.
	const zipTime = fs.statSync(path.join(BUILD_DIR, zips[0])).mtimeMs;
	let newest = 0;
	let newestName = "";

	for (const f of fs.readdirSync(MOD_DIR, { recursive: true })) {
		const full = path.join(MOD_DIR, f);
		let st;

		try {
			st = fs.statSync(full);
		} catch (err) {
			continue;
		}

		if (st.isFile() && st.mtimeMs > newest) {
			newest = st.mtimeMs;
			newestName = f;
		}
	}

	warn(zipTime + 2000 >= newest,
		"the zip predates " + newestName + " -- rebuild it (node tools/release_check.js cannot read inside a zip, so this mtime check is the only staleness guard)");
}

console.log(lines.join("\n"));
console.log(fails === 0 ? "\nRELEASE OK -- version, tag and zip all say " + version : "\n" + fails + " FAILED -- do not upload");
process.exit(fails === 0 ? 0 : 1);
