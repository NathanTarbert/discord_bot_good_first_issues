import { Client, IntentsBitField } from 'discord.js';
import { Octokit } from "octokit";
import dotenv from 'dotenv';

dotenv.config();

const DISCORD_TOKEN = process.env.DISCORD_TOKEN;
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const GITHUB_REPO_OWNER = "winglang";
const GITHUB_REPO_NAME = "wing";

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

const fetchIssues = async () => {
    try {
        const { data: issues } = await octokit.rest.issues.listForRepo({
            owner: GITHUB_REPO_OWNER,
            repo: GITHUB_REPO_NAME,
            labels: 'good first issue',
            state: 'open',
            sort: 'created',
            direction: 'desc',
            per_page: 1
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
        const today = new Date().toISOString().slice(0, 10);
        const issueDate = new Date(issues[0].created_at).toISOString().slice(0, 10);

        if (issueDate === today && (!lastCheckedIssueId || issues[0].id !== lastCheckedIssueId)) {
            const channel = client.channels.cache.get(process.env.DISCORD_CHANNEL_ID);
            if (channel) {
                await channel.send(`Good news, a new 'good first issue' was created today:\n**${issues[0].title}** (#${issues[0].number})\n${issues[0].html_url}`);
                console.log(`Message sent for issue #${issues[0].number}`);
                lastCheckedIssueId = issues[0].id;
            } else {
                console.error('Channel not found. Please check the DISCORD_CHANNEL_ID in your .env file.');
            }
        } else {
            console.log('No new "good first issue" created today.');
        }
    } else {
        console.log('No "good first issue" found.');
    }
};

client.once('ready', () => {
    console.log(`Logged in as ${client.user.tag}!`);
    checkNewGoodFirstIssues().finally(() => client.destroy()); // Destroy client after sending messages
});

client.login(DISCORD_TOKEN).catch(console.error);
