#!/bin/bash
rm -rf dist/*
npm install
npm run build
rm -rf ../server/front/install
mkdir -p ../server/front/install
cp -r dist/* ../server/front/install/