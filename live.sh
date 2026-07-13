#!/bin/bash
trap 'rm v-fholio' INT
trap 'rm v-fholio.exe' INT
clear
v -g -d veb_livereload watch --add data/content.json,data/projects.json --only-watch=*.html,*.css,*.js,*.md,*.tr,*.json,*.v,*.png,*.jp*g,*.gif run .
# v -g -prod -d veb_livereload watch --add data/content.json,data/projects.json --only-watch=*.html,*.css,*.js,*.md,*.tr,*.json,*.v,*.png,*.jp*g,*.gif run .