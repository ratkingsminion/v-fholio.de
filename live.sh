#!/bin/bash
trap 'rm v-fholio' INT
trap 'rm v-fholio.exe' INT
clear
v -d veb_livereload watch run .