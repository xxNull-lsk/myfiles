@echo off
chcp 65001
set VERSION=%1
set GIT_BRANCH=%2
set GIT_COMMIT=%3


cd %~dp0
git reset --hard HEAD
git checkout %GIT_BRANCH%
git pull
git reset --hard %GIT_COMMIT%

call bld.bat %VERSION%

