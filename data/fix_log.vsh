#!/usr/bin/env -S v -raw-vsh-tmp-prefix tmp run

import regex

///

system("clear")

args := arguments()
if args.len < 2 {
	println("file name needed")
	exit(0)
}

filename := args[1]
println("reading ${filename}...")
mut file := read_file(filename) or {
	println("file not found")
	exit(0)
}
println("removing backslashes...")

file_len := file.len

// fix \- ...
file = file.replace("\\-", "-")
		   .replace("\\_", "_")
		   .replace("\\[", "[")
		   .replace("\\]", "]")
		   .replace("\\<", "<")
		   .replace("\\>", ">")
		   .replace("\\(", "(")
		   .replace("\\)", ")")
		   .replace("\\=", "=")
		   .replace("\\#", "#")
		   .replace("\\!", "!")
		   .replace("\\~", "~")
		   .replace("\\&", "&")
		   .replace("\\%", "%")
		   .replace("\\*", "*")
		   .replace("\\+", "+")
		   .replace("\\.", ".")
		   .replace("\\\\", "\\")

println("removed ${file_len - file.len} backslashes")

// small stuff
file = file.replace("…", "...")
file = file.replace("\r\n", "\n")
file = file.replace("’", "'")

// fix [link](link) duplication
//query := r'\[[[:graph:]]*\]\([[:graph:]]*\)'
query_url := r'\[[0-9a-zA-Z:\/.\-?%~=_\\@#\&]+\]\([0-9a-zA-Z:\/.\-?%~=_\\@#\&]+\)'
mut re := regex.regex_opt(query_url) or { panic(err) }
matches_url := re.find_all_str(file)
for m in matches_url {
	url := m.substr(1, m.index("]") or { 2 })
	file = file.replace(m, url)
}
println("fixed ${matches_url.len} urls")

// fix missing ### for DONE, SEEN, PLAN (single word titles)
lines := file.split('\n')
file = ""
for l in lines {
	if l.len > 1 && l.split(' ').len == 1 && l.trim_space().len > 0 && !l.trim_space().starts_with("http") { file += "### " }
	file += l + "\n"
}

/*
// get single entries
mut entries := file.split("## 20")
for mut e in entries {
	e = "## 20" + e.trim_space().trim("\n").trim_space()
}

// remove "empty" entries
entries = entries.filter(|e| e.len > 8)

println("found ${entries.len} log entries")

// put entries in correct year
mut entries_by_year := map[string][]string{}
for e in entries {
	year := e.substr(3, 7)
	entries_by_year[year] << e
}

// save files for each year
// TODO separate script, because main file will be changed by hand?
for year, list in entries_by_year{
	write_file("fixed_" + year.str() + "_" + filename, list.join("\n\n")) or {
		println("file could not be written")
		exit(0)
	}
	println("> ${year}: ${list.len} entries")
}
*/

// save file
write_file("fixed_" + filename, file) or {
	println("file could not be written")
	exit(0)
}