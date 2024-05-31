bring cloud;
bring util;
bring http;

let DISCORD_TOKEN = util.env("DISCORD_TOKEN");
let GITHUB_TOKEN = util.env("GITHUB_TOKEN");
let GITHUB_REPO_OWNER = util.env("GITHUB_REPO_OWNER");
let GITHUB_REPO_NAME = util.env("ITHUB_REPO_NAME");

let lastCheckedIssueId = new cloud.Counter(initial: 0);

let fetchIssues = inflight () => {
    try {
        let response = http.get("https://api.github.com/repos/{GITHUB_REPO_OWNER}/{GITHUB_REPO_NAME}/issues?labels=good%20first%20issue&state=open&sort=created&direction=desc&per_page=1", {
            headers: {
                Authorization: "token {GITHUB_TOKEN}"
            }
        });

        if (response.status == 200) {
            return Json.parse(response.body);
        } else {
            log("Error fetching GitHub issues: {response.status}");
            return Json[];
        }
    } catch error {
        log("Error fetching GitHub issues: {error}");
        return Json[];
    }
};

let checkNewGoodFirstIssues = inflight () => {
    let issues = fetchIssues();

    if (issues.length > 0) {
        let today = datetime.systemNow().toIso().slice(0, 10);
        let issueDate = datetime.fromIso(issues[0].get("created_at").asStr()).toIso().slice(0, 10);

        if (issueDate == today && (!lastCheckedIssueId.peek() || issues[0].get("id").asNum() != lastCheckedIssueId.peek())) {
            let channelID = util.env("DISCORD_CHANNEL_ID");
            let response = http.post("https://discord.com/api/v10/channels/{channelID}/messages", {
                headers: {
                    Authorization: "Bot {DISCORD_TOKEN}",
                    "Content-Type": "application/json"
                },
                body: Json.stringify({
                    content: "Good news, a new 'good first issue' was created today:\n**{issues[0].get("title").asStr()}** (# {issues[0].get("number").asNum()})\n{issues[0].get("html_url").asStr()}"
                })
            });

            if (response.status == 200) {
                log("Message sent for issue # {issues[0].get("number").asNum()}");
                lastCheckedIssueId.inc();
                lastCheckedIssueId.set(issues[0].get("id").asNum());
            } else {
                log("Error sending message to Discord channel: {response.status}");
            }
        } else {
            log('No new "good first issue" created today.');
        }
    } else {
        log('No "good first issue" found.');
    }
};

let schedule = new cloud.Schedule(rate: 1h);
schedule.onTick(checkNewGoodFirstIssues);
