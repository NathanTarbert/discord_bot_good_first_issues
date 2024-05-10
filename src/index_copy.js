import express from 'express';
import { Octokit } from "octokit";
import dotenv from 'dotenv';

dotenv.config();

const octokit = new Octokit({ auth: process.env.GIT_TOKEN });
  
  const app = express();

  app.use(express.json);

  app.get('/', (req, res) => {
     octokit.request("GET /repos/{owner}/{repo}/issues/{issue_number}/labels", {
        owner: "winglang",
        repo: "wing",
        issue_number: "6451"
      });
  })

  console.log(octokit.rest.issues)

  app.listen(3000, () => {
    console.log('Server is listening');
  })
  


const { Client, IntentsBitField } = require('discord.js');

const client = new Client({
    intents: [
        IntentsBitField.Flags.Guilds, 
        IntentsBitField.Flags.GuildMembers,
        IntentsBitField.Flags.GuildMessages,
        IntentsBitField.Flags.MessageContent, 

    ],
});

client.on('ready', (c) => {
    console.log(`${c.user.tag} is online` )
});

client.on('messageCreate', (message) => {
    if (message.author.bot) {
        return
    }
    if (message.content === 'hello') {
        message.reply('Hey!')
    }
})

client.login(process.env.BOT_TOKEN);