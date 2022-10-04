---
title: "Git Worktrees: The Best Kept Git Secret?"
date: 2022-10-03T21:29:28-04:00
draft: true
type: "posts"
description: Why is this not more popular?
tags: ["git", "workflow"]
---

# What's the Problem?

Git branches are just a fact of life if you work on projects above a certain size: there's just no other (good) way to scale and coordinate effort from multiple programmers on one codebase. Unfortunately, mandatory doesn't mean *always* mean pleasant, and I'm sure most of you have danced the Branch Shuffle enough times that you know exactly what I'm talking about.

What if I told you there was a better way?

# Enter, Git Worktrees

Git worktrees allow you to have as many branches as you want checked out at the same time. Each branch can be staged, pushed, pulled, and reverted indepentantly. Checking out a new branch is a single command and doesn't disturb your existing branches, so there's no need to hurridly commit your in-progress work or stash your working set with a non-descriptive name when you recieve that Priority 1++++ bug report in the middle of lunch.

# Okay, But How Does It Work?

I was deeply surprised at how easy it was to set up. Here's my recommendation:

```bash
mkdir MyProject && cd MyProject
git clone --bare https://url.com/path/to/MyProject .bare
echo "gitdir: ./.bare"> .git

git worktree add master
git worktree add other_branch
```


A normal clone operation will produce a folder that looks like this:

```
MyProject
├── .git
│   └── <git config folder contents>
├── other_file.txt
└── readme.md
```

The above procedure will produce this instead:

```
MyProject
├── .bare
│   └── <git config folder contents>
├── master
│   ├── other_file.txt
│   └── readme.md
├── other_branch
│   ├── other_file.txt
│   ├── new_file.txt
│   └── readme.md
└── .git // file, not folder
```

As promised, each branch is checked out into it's own folder. The `.git` file is necessary because without it and the extra argument to clone into `./.bare` , the git config folder will just be dumped into the project root. I don't know why this is the default operating mode of worktrees but I find it revolting. 

The contents of `.git` simply tell the git executable that the actual git config folder is in `./.bare` instead of the usual `./.git`.

# Now what?

Personally I open the individual branch folders with VSCode and proceed as usual, but if you like workspace files you could set up a multi-root workspace to open all the branches at once or whatever you want.

# References

Actual documentation:

https://git-scm.com/docs/git-worktree

Inspired by ThePrimagen's YouTube video "Git's Best and Most Unknown Feature":

https://www.youtube.com/watch?v=2uEqYw-N8uE

Refined with ideas from Morgan Cugerone:

https://morgan.cugerone.com/blog/how-to-use-git-worktree-and-in-a-clean-way/

https://morgan.cugerone.com/blog/workarounds-to-git-worktree-using-bare-repository-and-cannot-fetch-remote-branches/
