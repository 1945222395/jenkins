#! /bin/bash
git-branch () {
git init .
git remote rm origin
git remote add origin https://github.com/lyc2395/jenkins.git
git config credential.helper store
git checkout  old-version-deploy-scripts
git checkout -b  old-version-deploy-scripts
}
git-branch
git checkout  old-version-deploy-scripts
git checkout -b  old-version-deploy-scripts
git commit -m "$(date +%F_%H:%M:%S) commit"
git status
git add .
git push -f -u origin old-version-deploy-scripts
