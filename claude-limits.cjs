// Optional: shows your Claude (Pro/Max) 5-hour and weekly usage as two rings in the island.
// Set this as the Claude Code status line (see README "Claude limits"). Claude Code passes the session JSON on stdin;
// `rate_limits` exists only for Pro/Max subscriptions and after the first API reply of a session.
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");

const FILE = process.env.ISLAND_LIMITS_FILE || path.join(os.homedir(), ".claude", "island-limits.json");

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (c) => (raw += c));
process.stdin.on("end", () => {
	let input = {};
	try { input = JSON.parse(raw); } catch { process.exit(0); }
	const rl = input.rate_limits;
	const win = (w) => (w && typeof w.used_percentage === "number"
		? { pct: w.used_percentage, resetsAt: new Date(w.resets_at * 1000).toISOString() } : null);
	const fiveHour = win(rl?.five_hour), sevenDay = win(rl?.seven_day);
	if (fiveHour || sevenDay) {
		fs.mkdirSync(path.dirname(FILE), { recursive: true });
		fs.writeFileSync(FILE, JSON.stringify({ fiveHour, sevenDay, updatedAt: new Date().toISOString() }, null, 2));
	}
	process.stdout.write(fiveHour ? `5H ${Math.round(fiveHour.pct)}%\n` : "5H --\n");
});
