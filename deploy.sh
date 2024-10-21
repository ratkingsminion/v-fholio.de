#!/bin/bash

SOURCEFOLDER="./publish/"

trap 'rm v-fholio' INT
trap 'rm v-fholio.exe' INT
clear

v -d deploy run .

cp -r ./static/. $SOURCEFOLDER

echo "Created $SOURCEFOLDER content"