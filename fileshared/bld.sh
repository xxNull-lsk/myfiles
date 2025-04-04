#!/bin/bash
rm -rf dist/*
npm install
npm run build
rm -rf ../server/front/shared
mkdir -p ../server/front/shared
cp -r dist/* ../server/front/shared/