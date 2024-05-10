import { Client, IntentsBitField } from 'discord.js';
import { Octokit } from "octokit";
import dotenv from 'dotenv';

dotenv.config();

const DISCORD_TOKEN = process.env.DISCORD_TOKEN;
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const GITHUB_REPO_OWNER = "winglang";
const GITHUB_REPO_NAME = "wing";
const CHECK_INTERVAL = 60 * 1000; // Check every 60 seconds

const client = new Client({
    intents: [
        IntentsBitField.Flags.Guilds, 
        IntentsBitField.Flags.GuildMembers,
        IntentsBitField.Flags.GuildMessages,
        IntentsBitField.Flags.MessageContent, 

    ],
});

const octokit = new Octokit({ auth: GITHUB_TOKEN });

let lastCheckedIssueId = null;
let initialized = false;

const fetchIssues = async () => {
    try {
        const { data: issues } = await octokit.rest.issues.listForRepo({
            owner: GITHUB_REPO_OWNER,
            repo: GITHUB_REPO_NAME,
            labels: 'good first issue',
            state: 'open',
            sort: 'created',
            direction: 'desc',
            per_page: 20
        });

        return issues;
    } catch (error) {
        console.error('Error fetching GitHub issues:', error);
        return [];
    }
};

const checkNewGoodFirstIssues = async () => {
    const issues = await fetchIssues();

    if (issues.length > 0) {
        const newIssues = [];

        if (!initialized) {
            // On first run, send messages for the last 20 issues
            issues.forEach(issue => {
                newIssues.push(issue);
                if (!lastCheckedIssueId || issue.id > lastCheckedIssueId) {
                    lastCheckedIssueId = issue.id;
                }
            });
            initialized = true;
        } else {
            // On subsequent runs, only send messages for new issues
            for (const issue of issues) {
                if (issue.id > lastCheckedIssueId) {
                    newIssues.push(issue);
                    lastCheckedIssueId = issue.id;
                } else {
                    break;
                }
            }
        }

        const channel = client.channels.cache.get(process.env.DISCORD_CHANNEL_ID);
        if (channel) {
            for (const issue of newIssues.reverse()) {
                await channel.send(`Good news, a new 'good first issue' was created:\n**${issue.title}** (#${issue.number})\n${issue.html_url}`);
                console.log(`Message sent for issue #${issue.number}`);
            }
        } else {
            console.error('Channel not found. Please check the DISCORD_CHANNEL_ID in your .env file.');
        }
    } else {
        console.log('No "good first issue" found.');
    }
};

client.once('ready', () => {
    console.log(`Logged in as ${client.user.tag}!`);
    checkNewGoodFirstIssues();
    setInterval(checkNewGoodFirstIssues, CHECK_INTERVAL);
});

client.login(DISCORD_TOKEN).catch(console.error);