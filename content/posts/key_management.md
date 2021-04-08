---
title: "Towards An O(1) Solution For Key Management"
date: 2021-03-08T20:43:03-05:00
draft: false
---

I'm trying to optimize the following scenario:
I have 2 development machines. Each one has a keypair.
There are 10 remote hosts that I want to SSH into from any of the dev machines. Password authentication is disabled. I do not have physical access to all of the remote hosts.
I have created a 3rd dev machine, and I need to be able to SSH into any of hosts.

## Solution #1:
- get on one of the original dev machines
- SSH into the a remote host
- enable password auth
- go back to the new dev machine
- run `ssh-copy-id <remote host>`
- go back to original dev machine
- disable password auth
- repeat for every remote host
  
This is terrible. It's a ton of manual work, I'm intentionally creating a big security hole, and I'm probably gonna forget to resecure some of my remote machines.

## Solution #2:
- make sure the new machine's public key is uploaded to my GitHub account
- get on one of the original dev machines
- SSH into the a remote host
- run `ssh-import-id gh:<username>`
- repeat for every remote host

Better. This is O(2n), where the 1st solution was O(10), and I can't forget to resecure the remote hosts.

Unfortunately this still requires going to back to one of the original machines, and it still requires two manual actions per remote host. If I forget to update one of the hosts, take my new dev machine out of the house, and then need to get into that particular host, I'm SOL.

## Solution #3:
- make sure all the remote hosts are listed in an ansible inventory file
- make sure the new machine's public key is uploaded to my GitHub account
- get on one of the original dev machines
- run `ansible all -i hosts -a "ssh-import-id gh:<username>"`

Even more better. Now I'm down to a constant time solution, assuming I have access to an original dev machine.

This is how I'm currently managing this problem, except I put the ansible command in a shell script called `keypush.sh`. I expect this will scale quite well for my immediate needs. 