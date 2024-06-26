bring cloud;
bring util;
bring http;
bring math;

let discordToken = new cloud.Secret(name: "discordToken") as "discord token";
let githubToken = new cloud.Secret(name: "github-token") as "github token";
let bucket = new cloud.Bucket();

let GITHUB_REPO_OWNER = "winglang";
let GITHUB_REPO_NAME = "wing";
let discordChannel = "1238185652688912394";

let discordBaseAPI = "https://discord.com/api/v10";

struct Label {
  id: num;
  name: str;
  description: str;
}

struct GithubIssue {
  url: str;
  title: str;
  html_url: str;
  created_at: str;
  labels: Array<Label>;
}

let fetchIssues = inflight (): Array<GithubIssue>? => {
    try {
      let response = http.get("https://api.github.com/repos/{GITHUB_REPO_OWNER}/{GITHUB_REPO_NAME}/issues?labels=good%20first%20issue&state=open&sort=created&direction=desc&per_page=10", {
        headers: {
          Authorization: "token {githubToken.value()}"
        }
      });

      let issues = MutArray<GithubIssue>[];
      for entry in Json.values(Json.parse(response.body)) {
        issues.push(GithubIssue.fromJson(entry));
      }

      if (response.status == 200) {
        return issues.copy();
      } else {
        log("Error fetching GitHub issues: {response.status}");
        return nil;
      }
    } catch error {
        log("Error fetching GitHub issues: {error}");
        return nil;
    }
};

let getStoredIssues = inflight (): MutArray<GithubIssue> => {
  try {
    let oldIssuesData = bucket.get("previousIssues.json");
    log("oldIssues: {oldIssuesData}");
    
  } catch error {
    log("No previous issues found or error fetching from bucket: {error}");
    return MutArray<GithubIssue>[];
  }
};

let filterIssues = inflight (days: num, issues: Array<GithubIssue>): Array<GithubIssue> => {
  let filteredIssues: MutArray<GithubIssue> = MutArray<GithubIssue>[];
  for issue in issues {
    let createdDate = datetime.fromIso(issue.created_at);
    let currentTime = datetime.utcNow();
    let difference = currentTime.timestampMs - createdDate.timestampMs;
    let oneDayInMilliseconds = 24 * 60 * 60 * 1000;
    let daysOld = math.floor(difference / oneDayInMilliseconds);
    if daysOld <= days {
      filteredIssues.push(issue);
    }
  }
  return filteredIssues.copy();
};

let postIssues = inflight () => {
  if let issues = fetchIssues() {
    let newFirstIssues = filterIssues(1, issues);
    let discordMessage: MutArray<str> = MutArray<str>[];
    for issue in newFirstIssues {
      discordMessage.push(issue.title, issue.html_url);
      log("issues url: {issue.html_url}");
      log("issues title {issue.title}"); 
      bucket.put("new_issue_file", issue.html_url);
      let fileData = bucket.get("new_issue_file");
      log("fileData: {fileData}");
    }
    let response = http.post("{discordBaseAPI}/channels/{discordChannel}/messages", {
      headers: {
        Authorization: "Bot {discordToken.value()}",
        "Content-Type": "application/json"
      },
      body: Json.stringify({
        content: "*A New Good First Issue Has Been Published*\n🚀========================🚀\n{discordMessage.join("\n")}"
      })
    });
  }
};

let s = new cloud.Schedule(rate: duration.fromMinutes(1440));
s.onTick(postIssues);
