#!/usr/bin/env -S v -raw-vsh-tmp-prefix tmp run

import os
import json

///

const obsolete_projects = [ "mayor-hendrik", "snakkke", "africa-party", "wie-heisstn-der-bin-ich-das" ]
// later: "alternative-artefacts", 

///

fn create_moniker(input string) string {
	mut res := []rune{}
	mut was_space := false
	for x in input.to_lower().runes() {
		if (x >= `a` && x <= `z`) || (x >= `0` && x <= `9`) { res << x }
		else {
			match x {
				`à`, `á`, `ä` { res << `a` }
				`ò`, `ó`, `ö` { res << `o` }
				`ù`, `ú`, `ü` { res << `u` }
				`ß` { res << `s`; res << `s` }
				` ` { if !was_space { res << `-`; was_space = true; } continue }
				else { continue }
			}
		}
		was_space = false
	}
	return res.string().trim("-")
}

@[heap]
struct Project {
mut:
	category string
	important bool
	title string
	moniker string
	short_desc string
	timeframe string
	occasion string
	tools string
	credits []string
	links []string
	videos []string
	tags string
	description string
	obsolete bool
}

//

system("clear")

path := "../../../jekyll-bef/_posts"
mut filenames := []string{}
for file in os.ls(path) or { println(err) } {
	if os.is_dir("${path}/${file}") { continue }
	filenames << file
}
filenames.sort(a > b)

mut projects := []Project{}

for file in filenames {
	moniker := file.substr_ni("2010-01-01-".len, -".markdown".len)
	if moniker in obsolete_projects {
		println("skipped '${moniker}'")
		continue
	}
	file_content := os.read_file("${path}/${file}") or { "" }
	mut project := Project{
		moniker: moniker
	}
	mut below := false
	for idx, line in file_content.replace("\r", "").split("\n") {
		if idx == 0 { continue }
		if line.trim_space().starts_with("---") {
			below = true
			continue
		}
		def := line.trim_space().split(":")
		mut done := def.len > 1
		if def.len > 1 {
			after := line.all_after_first(":").trim_space()
			match def[0] {
				"layout" { continue }
				"title" { project.title = after.trim("\"") }
				"important" { project.important = after.trim("\"") == "true" }
				"category" { project.category = after.trim("\"") }
				"shortinfo1" { project.short_desc = after.trim("\"") }
				"shortinfo2" { project.occasion = after.trim("\"") }
				"shortinfo3" { project.timeframe = after.trim("\"") }
				"shortinfo4" { project.tools = after.trim("\"") }
				"credits" { project.credits = json.decode([]string, after) or { [] } }
				"links" { project.links = json.decode([]string, after) or { [] } }
				"videos" { project.videos = json.decode([]string, after) or { [] } }
				"tag" { project.tags = after.trim("[]").trim_space() } // .split(",").map(|s| s.trim_space()) }
				else { done = false }
			}
		}
		if below && !done {
			if project.description != "" { project.description += "\n" }
			project.description += line
		}
	}
	projects << project
}

// save file
println("${projects.len} projects")
mut res := json.encode_pretty(projects).replace(":\t", ": ")
res = res.replace("\"Paul Hanisch\", \"\"", "\"Paul Hanisch\", \"https://paul-hanisch.de\"").replace("http:", "https:")
write_file("projects.json", res) or {
	println("file could not be written")
	exit(0)
}

///

if os.is_dir("../assets/projects") {
	os.rmdir_all("../assets/projects") or {
		println("Error: could not delete projects path - ${err}")
		exit(0)
	}
}
os.mkdir("../assets/projects") or {
	println("Error: could not create projects path - ${err}")
	exit(0)
}
for p in projects {
	opath := "../../../jekyll-bef/assets/projects/${p.moniker}"
	npath := "../assets/projects/${p.moniker}" //.to_lower()
	os.mkdir(npath) or {
		println("Error: path ${p.moniker} not created - ${err}")
	}
	if !os.is_dir(opath) {
		println("Warning: opath for ${p.moniker} does not exist")
	}
	else {
		mut pic_names := []string{}
		for pic in os.ls(opath) or { println(err) } {
			if os.is_dir("${opath}/${pic}") { continue }
			pic_names << pic
		}
		pic_names.sort(a < b)

		for pic in pic_names {
			//if pic != pic.to_lower() { println("lowercasing ${pic}")} // TODO should not be necessary
			os.cp("${opath}/${pic}", "${npath}/${pic}") or { println(err) }
		}
	}
}