#! /bin/bash
export http_proxy=10.129.54.27:3128
git-branch () {
git remote rm origin
git remote add origin https://github.com/lyc2395/jenkins.git
git config credential.helper store
git checkout old-version-deploy-scripts
git checkout -b old-version-deploy-scripts
}
git-branch
git checkout  old-version-deploy-scripts
git status
git commit -m "$(date +%F_%H:%M:%S) commit"
git add .
git push -f -u origin old-version-deploy-scripts
