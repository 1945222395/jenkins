#! /bin/bash
export http_proxy=10.129.54.27:3128
git-branch () {
git remote rm origin
git remote add origin https://github.com/lyc2395/mysql.git
git config credential.helper store
git checkout prd-deploy
git checkout -b prd-deploy
}

git checkout  prd-deploy
git status
git commit -m "$(date +%F_%H:%M:%S) commit"
git add .
git push -f -u origin prd-deploy
