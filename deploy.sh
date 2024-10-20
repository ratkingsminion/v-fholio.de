#!/bin/bash

SOURCEFOLDER="./publish/"

clear

v -d deploy run .

cp -r ./static/. $SOURCEFOLDER

echo "Created $SOURCEFOLDER content"