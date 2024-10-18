#!/bin/bash
trap 'rm linktree' INT
clear
v -d veb_livereload watch run .
#rm linktree