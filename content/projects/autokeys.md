---
title: "Autokeys"
date: 2021-02-13T14:38:10-05:00
draft: true
type: "project"
tags: ["scripts", "ssh", "sshd"]
---

While setting up a development environment on my [newest computer](posts/mbp.md), I realized that my ssh key management situation has become untenable. I now have three development machines: a desktop, a Surface Pro 5, and a mid-2012 Macbook Pro. All three are running Windows 10 Pro, and I have at least one WSL installation on each machine. That's a minimum of six keys.

Each of those keys needs to be usable on at least a dozen target machines: a VPS, a couple industrial automation machines, a home server, a mess of raspberry pis, and more I can't remember.

Using `ssh-copy-id` already wasn't good enough, because password authentication is disabled on all of my target machines. The existing workflow was something like this:
    
1. set up machine
2. enable sshd
3. ssh into the machine using my password
4. download my list of public keys from github
5. move list to `~/.ssh/authorized_keys`
6. disable password in `/etc/ssh/sshd_config`
7. restart sshd
8. test that private login works correctly
   
This has been fine for adding a new target, but adding a new dev machine is slightly more of a pain. I already added the W10+WSL keys from the MBP to my GitHub account, but now what? The easiest thing would be using my desktop or Surface to to log in to each of the existing targets. It probably would have taken half an hour if I'd just buckled down and done that from the start, but... We don't do that here:

![](https://imgs.xkcd.com/comics/automation.png)

My first draft solution was writing a small script to automatically update `authorized_keys`:


```bash
wget https://github.com/<GitHubUsername>.keys
mv <GitHubUsername>.keys ~/.ssh/authorized_keys
```

This would be easier, but still requires manual intervention. The next thought was to set up a cron job on each target so they'd automatically fetch my keys every hour or so. This was easy enough to set up




<!-- 
{{< gist DaelonSuzuka 9713547459e8734de97750f12475b7a6 >}} -->
