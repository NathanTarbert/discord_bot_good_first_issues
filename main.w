bring cloud;
bring util;
bring http;
bring math;

let discordToken = new cloud.Secret(name: "discordToken") as "discord token";
let githubToken = new cloud.Secret(name: "gihub-token") as "github token";

let GITHUB_REPO_OWNER = "winglang";
let GITHUB_REPO_NAME = "wing";
let discordChannel = "1244081517379063908";

let lastCheckedIssueId = new cloud.Counter(initial: 0);

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

struct GithubQueryResponse {
  issues: Array<GithubIssue>;
}


// TODO: find way to cast just using struct system
let convertToGithubQueryResponse = inflight (issues: Json): GithubQueryResponse => {
  let responseIssues: MutArray<GithubIssue> = MutArray<GithubIssue>[];
  for entry in Json.values(issues) {
    responseIssues.push(GithubIssue.fromJson(entry));
  }

  return {
    issues: responseIssues.copy()
  };
};

let fetchIssues = inflight (): GithubQueryResponse? => {
    try {
      // TODO: Need to make this just issues created in last 24hrs (open question- if an issue was created x days ago but only recieved good first issue today should it be included)
      let response = http.get("https://api.github.com/repos/{GITHUB_REPO_OWNER}/{GITHUB_REPO_NAME}/issues?labels=good%20first%20issue&state=open&sort=created&direction=desc&per_page=10", {
        headers: {
          Authorization: "token {githubToken.value()}"
        }
      });

      if (response.status == 200) {
        return convertToGithubQueryResponse(Json.parse(response.body));
      } else {
        log("Error fetching GitHub issues: {response.status}");
        return nil;
      }
    } catch error {
        log("Error fetching GitHub issues: {error}");
        return nil;
    }
};

let findIssuesNoOlderThan = inflight (days: num, issues: Array<GithubIssue>): Array<GithubIssue> => {
  let filteredIssues: MutArray<GithubIssue> = MutArray<GithubIssue>[];
  for issue in issues {
    let createdDate = datetime.fromIso(issue.created_at);
    let currentTime = datetime.utcNow();

    let difference = currentTime.timestampMs - createdDate.timestampMs;
    
    let twentyForHours = 24 * 60 * 60 * 1000;
    let daysOld = math.floor(difference / twentyForHours);
    if daysOld <= days {
      filteredIssues.push(issue);
    }
  }
  return filteredIssues.copy();
};

let postIssues = inflight () => {
  let issues = fetchIssues();
  
  let newFirstIssues = findIssuesNoOlderThan(1, issues?.issues!);

  let discordMessage: MutArray<str> = MutArray<str>[];

  for issue in newFirstIssues {
    discordMessage.push(issue.html_url);
  }

  let response = http.post("{discordBaseAPI}/channels/{discordChannel}/messages", {
    headers: {
      Authorization: "Bot {discordToken.value()}",
      "Content-Type": "application/json"
    },
    body: Json.stringify({
      content: "*Todays New First Issues*\n============================\n{discordMessage.join("\n")}"
    })
  });

  log("Response:");
  log(Json.stringify(response));
};


let s = new cloud.Schedule(rate: duration.fromMinutes(1));
s.onTick(postIssues);