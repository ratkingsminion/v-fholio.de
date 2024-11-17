module main

import time
import math
import json
import veb
import os
import markdown
import strconv
import regex

const special_chars = [ ` `, `_`, `-`, `?`, `!`, `*`, `.`, `:`, `;`, `,`, `^` ]

const link_symbol_self = "▶"
const link_symbol_fav = "★"
const projects_entries_per_page = 15
const no_log_entries_warning = "No log entries (yet)!"

@[heap]
pub struct Context {
	veb.Context
}

pub struct App {
	veb.StaticHandler
pub mut:
	content Content
	log_years map[string]int
}

@[heap]
struct Content {
	topmenu []struct {
		title string
		url string
		target string = "_blank"
		moniker string

	}
	imprint struct {
		title string
		texts []struct {
			title string
			text string
		}
	}
	linktrees []Linktree
	log Log
mut:
	projects Projects
	parsed bool @[skip]
}

@[heap]
struct Linktree {
	title string
	shortlinks []struct {
		title string
		icon string
		url string
		target string = "_blank"
		fav bool
		rel string
	}
	links []struct {
		title string
		icon string
		url string
		target string = "_blank"
		fav bool
		rel string
	}
}

@[heap]
struct Log {
	title string
}

@[heap]
struct LogEntry {
	date string
	text string
}

@[heap]
struct Projects {
	title string
	title_entry string
mut:
	entries []Project // taken from different json
	tags map[string][]Project
}

@[heap]
struct Project {
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
	pics_cols int = 1
mut:
	pictures []string @[skip]
	tag_list []string @[skip]
	year int @[skip]
}

///

fn main() {
	mut app := App{
		log_years: {}
		content: Content{}
	}

	app.handle_static('assets', false)!

	$if deploy ? {
		deploy_all(mut app)
	}
	$else {
		veb.run[App, Context](mut app, 8081)
	}
}

@['/index']
pub fn (mut app App) index(mut ctx Context) veb.Result {
	content := app.get_content()
	linktrees := content.linktrees
	moniker := "home"

	return $veb.html("html/index.html")
}

@['/imprint']
pub fn (mut app App) imprint(mut ctx Context) veb.Result {
	content := app.get_content()
	imprint := content.imprint
	moniker := "imprint"

	return $veb.html("html/imprint.html")
}

// LOG

@['/log/:year']
pub fn (mut app App) log_single_year(mut ctx Context, log_cur_year string) veb.Result {
	content := app.get_content()
	log := content.log
	log_content := $if !deploy ? { get_log_content(mut app, log_cur_year) } $else { []LogEntry{} }
	moniker := "log"

	mut log_warning := ""
	if log_content.len == 0 {
		log_warning = no_log_entries_warning
	}
	else if log_content.len == 0 {
		ctx.res.set_status(.not_found) // status 404
		return ctx.html('<h1>Page not found!</h1>')
	}

	mut log_years := app.log_years.keys()
	log_years.sort(a > b) // sort high to low

	return $veb.html("html/log.html")
}

@['/log']
pub fn (mut app App) log(mut ctx Context) veb.Result {
	content := app.get_content()
	log := content.log
	log_content := $if !deploy ? { get_log_content(mut app, "") } $else { []LogEntry{} }
	moniker := "log"
	
	mut log_warning := if log_content.len == 0 { no_log_entries_warning } else { "" }
	
	mut log_years := app.log_years.keys()
	log_years.sort(a > b) // sort high to low
	log_cur_year := ""

	return $veb.html("html/log.html")
}

// PROJECTS

@['/projects/:page_or_entry']
pub fn (mut app App) projects_subpage(mut ctx Context, subpage string) veb.Result {
	content := app.get_content()
	projects := content.projects
	mut moniker := "projects"

	projects_pages := (projects.entries.len / projects_entries_per_page) + 1
	mut projects_cur_page := (strconv.atoi(subpage) or { 0 }) - 1
	cur_subpage := subpage.trim_space().to_lower()

	if (projects_cur_page < 0 || projects_cur_page >= projects_pages) && (cur_subpage != "tags") {
		// project
		moniker = "project"
		mut project := Project{}
		for pe in content.projects.entries {
			if pe.moniker == cur_subpage {
				project = pe
				break
			}
		}
		if project.moniker == "" {
			ctx.res.set_status(.not_found) // status 404
			return ctx.html('<h1>Page not found!</h1>')
		}
		title_entry := projects.title_entry.replace("{ENTRY}", project.category.title())
		return $veb.html("html/project.html")
	}
	else if cur_subpage == "tags" {
		// tags
		mut all_tags := app.content.projects.tags.keys()
		all_tags.sort_with_compare(alphanum_compare)
		projects_cur_page = -2
		return $veb.html("html/projects_tags.html")
	}
	else {
		// page
		projects_entry_start := projects_entries_per_page * projects_cur_page
		projects_entry_end := math.min(projects.entries.len, projects_entries_per_page * (projects_cur_page + 1))
		return $veb.html("html/projects.html")
	}
}

@['/projects']
pub fn (mut app App) projects(mut ctx Context) veb.Result {
	content := app.get_content()
	projects := content.projects
	moniker := "projects"

	projects_cur_page := -1
	projects_pages := (projects.entries.len / projects_entries_per_page) + 1
	projects_entry_start := 0
	projects_entry_end := projects.entries.len

	return $veb.html("html/projects.html")
}

///

// ONLY FOR DEPLOY TARGET
@[if deploy?]
fn deploy_all(mut app App) {
	content := app.get_content()

	// copy the static assets
	assets := os.abs_path("./assets")
	path := os.abs_path("./publish")
	if os.exists(path) { os.rmdir_all(path) or { } }
	os.mkdir(path) or { panic(err) }
	os.cp_all(assets, "${path}/assets", true) or { panic(err) }

	// create the html file(s)

	// linktree
	linktrees := app.content.linktrees
	mut moniker := "home"
	index_html := $tmpl("html/index.html").replace("\r", "")
	os.write_file("${path}/index.html", index_html) or { println(err) }

	// imprint
	imprint := app.content.imprint
	moniker = "imprint"
	os.mkdir("${path}/imprint") or { panic(err) }
	imprint_html := $tmpl("html/imprint.html").replace("\r", "")
	os.write_file("${path}/imprint/index.html", imprint_html) or { println(err) }

	// log
	moniker = "log"
	log := app.content.log
	os.mkdir("${path}/log") or { panic(err) }
	mut log_content := get_log_content(mut app, "")
	mut log_years := app.log_years.keys()
	log_years.sort(a > b) // sort high to low
	mut log_cur_year := ""
	mut log_warning := if log_content.len == 0 { no_log_entries_warning } else { "" }
	
	mut log_html := $tmpl("html/log.html").replace("\r", "")
	os.write_file("${path}/log/index.html", log_html) or { println(err) }
	
	// log entries by year
	max_year := time.now().year
	for year in strconv.atoi(log_years[log_years.len - 1]) or { 2018 }..max_year + 1 {
		log_content = get_log_content(mut app, year.str())
		log_cur_year = year.str()
		os.mkdir("${path}/log/${log_cur_year}") or { panic(err) }

		log_warning = if log_content.len == 0 { no_log_entries_warning } else { "" }

		log_html = $tmpl("html/log.html").replace("\r", "")
		os.write_file("${path}/log/${log_cur_year}/index.html", log_html) or { println(err) }
	}

	// projects list
	moniker = "projects"
	projects := app.content.projects
	os.mkdir("${path}/projects") or { panic(err) }
	projects_pages := (projects.entries.len / projects_entries_per_page) + 1
	mut projects_cur_page := -1
	mut projects_entry_start := 0
	mut projects_entry_end := projects.entries.len
	mut projects_html := $tmpl("html/projects.html").replace("\r", "")
	os.write_file("${path}/projects/index.html", projects_html) or { println(err) }

	// projects list by tags
	mut all_tags := app.content.projects.tags.keys()
	all_tags.sort_with_compare(alphanum_compare)
	projects_cur_page = -2
	os.mkdir("${path}/projects/tags") or { panic(err) }
	projects_html = $tmpl("html/projects_tags.html").replace("\r", "")
	os.write_file("${path}/projects/tags/index.html", projects_html) or { println(err) }

	// projects list by page
	for i := 0; i < projects_pages; i++ {
		projects_cur_page = i
		projects_entry_start = projects_entries_per_page * i
		projects_entry_end = math.min(projects.entries.len, projects_entries_per_page * (i + 1))
		os.mkdir("${path}/projects/${i + 1}") or { panic(err) }

		projects_html = $tmpl("html/projects.html").replace("\r", "")
		os.write_file("${path}/projects/${i + 1}/index.html", projects_html) or { println(err) }
	}

	// all project entries
	moniker = "project"
	for project in projects.entries {
		title_entry := projects.title_entry.replace("{ENTRY}", project.category.title())
		os.mkdir("${path}/projects/${project.moniker}") or { panic(err) }
		project_html := $tmpl("html/project.html").replace("\r", "")
		os.write_file("${path}/projects/${project.moniker}/index.html", project_html) or { println(err) }
	}
}

///

pub fn (mut app App) get_content() Content {
	if !app.content.parsed {
		content_file := os.read_file("data/content.json") or { "" }
		app.content = json.decode(Content, content_file) or { Content{} }
		app.content.parsed = true

		projects_content_file := os.read_file("data/projects.json") or { "" }
		app.content.projects.entries = json.decode([]Project, projects_content_file) or { []Project{} }
		app.content.projects.tags = map[string][]Project{}
		
		for mut pe in app.content.projects.entries {
			pe.pictures = []string{}
			for entry in os.ls("assets/projects/${pe.moniker}") or { panic(err) } {
				if os.is_dir("assets/projects/${pe.moniker}/${entry}") { continue }
				if entry.contains("preview") { continue }
				pe.pictures << entry
			}
			pe.pictures.sort_with_compare(alphanum_compare)

			// year
			mut re := regex.regex_opt(r'\d+/\d+') or { panic(err) }
			for m in re.find_all_str(pe.timeframe) {
				split := m.split("/")
				year_str := split[0].substr(0, split[0].len - split[1].len) + split[1]
				year_int := strconv.atoi(year_str) or { 0 }
				if year_int > pe.year { pe.year = year_int }
			}
			re = regex.regex_opt(r'\d{4}') or { panic(err) }
			for m in re.find_all_str(pe.timeframe) {
				year_int := strconv.atoi(m) or { 0 }
				if year_int > pe.year { pe.year = year_int }
			}

			// tags
			pe.tag_list = []string{}
			for tag in pe.tags.split(",") {
				ttag := tag.trim_space()
				pe.tag_list << ttag
				if ttag !in app.content.projects.tags { app.content.projects.tags[ttag] = []Project{} }
				app.content.projects.tags[ttag] << pe
			}
		}
		for _, mut pl in app.content.projects.tags {
			pl.sort_with_compare(projects_compare)
		}
	}
	return app.content
}

fn get_log_content(mut app App, year string) []LogEntry {
	mut log_text := ''
	filenames := os.ls("data/") or { [] }
	for filename in filenames {
		if !filename.starts_with("log") || !filename.ends_with(".md") { continue }
		text := os.read_file("data/" + filename) or { continue }
		log_text += text
	}

	// get single entries
	mut entries := log_text.split("## 20")
	for mut e in entries {
		e = "## 20" + e.trim_space().trim("\n").trim_space()
	}
	// remove "empty" entries
	entries = entries.filter(|e| e.len > 8)

	mut log_content := []LogEntry{}
	for e in entries {
		entry_year := e.substr(3, 7)
		app.log_years[entry_year] = 1
		if year != "" && entry_year != year {
			continue
		}
		fnl := e.index("\n") or { 0 }
		log_content << LogEntry{
			date: e.substr(3, fnl).trim_space()
			text: e.substr(fnl, max_int).trim_space()
		}
	}

	return log_content
}

// helpers for templates

fn md(text string) veb.RawHtml {
	return markdown.to_html(text)
}

fn md_nop(text string) veb.RawHtml {
	return markdown.to_html(text).trim_string_left("<p>").trim_string_right("</p>")
}

fn raw(text string) veb.RawHtml {
	return text
}

fn url(txt string) string {
	cur_year := (time.now().year).str()
	return txt.replace("{cur_year}", cur_year)
}

fn project_preview_pic(moniker string) string {
	path := "assets/projects/${moniker}"
	if !os.is_dir(path) { return "" }
	mut files := os.ls(path) or { return "" }
	if files.len == 0 { return "" }
	files.sort_with_compare(alphanum_compare)
	return "${path}/${files[0]}"
}

/// string helpers

fn get_moniker(input string) string {
	return normalize_string(input).replace(" ", "-")
}

fn normalize_string(input string) string {
	mut res := []rune{}
	for x in input.to_lower().runes() {
		// via https://ask.libreoffice.org/t/formula-to-remove-all-accented-characters/102041
		// TODO!
		//const source_letters = [ "ß", "À", "Á", "Â", "Ã", "Ä", "Å", "Ấ", "Ắ", "Ẳ", "Ẵ", "Ặ", "Ầ", "Ằ", "Ȃ", "Ả", "Ạ", "Ẩ", "Ẫ", "Ậ", "à", "á", "â", "ã", "ä", "å", "ấ", "ắ", "ẳ", "ẵ", "ặ", "ầ", "ằ", "ȃ", "ả", "ạ", "ẩ", "ẫ", "ậ", "Ā", "ā", "Ă", "ă", "Ą", "ą", "Ǎ", "ǎ", "Ǻ", "ǻ", "A̋", "a̋", "Ȁ", "ȁ", "A̧", "a̧", "Æ", "æ", "Ǽ", "ǽ", "B̌", "b̌", "B̧", "b̧", "Ç", "Ḉ", "ç", "ḉ", "Ć", "ć", "Ĉ", "ĉ", "Ċ", "ċ", "Č", "č", "C̆", "c̆", "Č̣", "č̣", "Ð", "ð", "Ď", "ď", "Đ", "đ", "Ḑ", "ḑ", "È", "É", "Ê", "Ë", "Ế", "Ḗ", "Ề", "Ḕ", "Ḝ", "Ȇ", "Ẻ", "Ẽ", "Ẹ", "Ể", "Ễ", "Ệ", "è", "é", "ê", "ë", "ế", "ḗ", "ề", "ḕ", "ḝ", "ȇ", "ẻ", "ẽ", "ẹ", "ể", "ễ", "ệ", "Ē", "ē", "Ĕ", "ĕ", "Ė", "ė", "Ę", "ę", "Ě", "ě", "E̋", "e̋", "Ȅ", "ȅ", "Ê̌", "ê̌", "Ȩ", "ȩ", "Ɛ̧", "ɛ̧", "ƒ", "F̌", "f̌", "Ĝ", "Ǵ", "ĝ", "ǵ", "Ğ", "ğ", "Ġ", "ġ", "Ģ", "ģ", "Ǧ", "ǧ", "Ĥ", "ĥ", "Ħ", "ħ", "Ḫ", "ḫ", "Ȟ", "ȟ", "Ḩ", "ḩ", "Ì", "Í", "Î", "Ï", "Ḯ", "Ȋ", "Ỉ", "Ị", "ì", "í", "î", "ï", "ḯ", "ȋ", "ỉ", "ị", "Ĩ", "ĩ", "Ī", "ī", "Ĭ", "ĭ", "Į", "į", "İ", "ı", "Ǐ", "ǐ", "I̋", "i̋", "Ȉ", "ȉ", "I̧", "i̧", "Ɨ̧", "ɨ̧", "Ĳ", "ĳ", "Ĵ", "ĵ", "J̌", "ǰ", "Ķ", "ķ", "Ḱ", "ḱ", "K̆", "k̆", "Ǩ", "ǩ", "Ĺ", "ĺ", "Ļ", "ļ", "Ľ", "ľ", "Ŀ", "ŀ", "Ł", "ł", "Ḿ", "ḿ", "M̆", "m̆", "M̌", "m̌", "M̧", "m̧", "Ñ", "ñ", "Ń", "ń", "Ņ", "ņ", "Ň", "ň", "ŉ", "N̆", "n̆", "Ǹ", "ǹ", "Ò", "Ó", "Ô", "Õ", "Ö", "Ø", "Ố", "Ṍ", "Ṓ", "Ȏ", "Ỏ", "Ọ", "Ổ", "Ỗ", "Ộ", "Ờ", "Ở", "Ỡ", "Ớ", "Ợ", "ò", "ó", "ô", "õ", "ö", "ø", "ố", "ṍ", "ṓ", "ȏ", "ỏ", "ọ", "ổ", "ỗ", "ộ", "ờ", "ở", "ỡ", "ớ", "ợ", "Ō", "ō", "Ŏ", "ŏ", "Ő", "ő", "Ơ", "ơ", "Ǒ", "ǒ", "Ǿ", "ǿ", "Ồ", "ồ", "Ṑ", "ṑ", "Ȍ", "ȍ", "O̧", "o̧", "Œ", "œ", "P̆", "p̆", "Ṕ", "ṕ", "P̌", "p̌", "Q̌", "q̌", "Q̧", "q̧", "Ŕ", "ŕ", "Ŗ", "ŗ", "Ř", "ř", "R̆", "r̆", "Ȓ", "ȓ", "Ȑ", "ȑ", "Ř̩", "ř̩", "Ś", "ś", "Ŝ", "ŝ", "Ş", "Ș", "ș", "ş", "Š", "š", "ſ", "Ṥ", "ṥ", "Ṧ", "ṧ", "Ţ", "ţ", "ț", "Ț", "Ť", "ť", "Ŧ", "ŧ", "T̆", "t̆", "Þ", "þ", "Ù", "Ú", "Û", "Ü", "Ủ", "Ụ", "Ử", "Ữ", "Ự", "ù", "ú", "û", "ü", "ủ", "ụ", "ử", "ữ", "ự", "Ũ", "ũ", "Ū", "ū", "Ŭ", "ŭ", "Ů", "ů", "Ű", "ű", "Ų", "ų", "Ȗ", "ȗ", "Ư", "ư", "Ǔ", "ǔ", "Ǖ", "ǖ", "Ǘ", "ǘ", "Ǚ", "ǚ", "Ǜ", "ǜ", "Ứ", "ứ", "Ṹ", "ṹ", "Ừ", "ừ", "Ȕ", "ȕ", "U̧", "u̧", "V̆", "v̆", "V̌", "v̌", "Ŵ", "ŵ", "Ẃ", "ẃ", "Ẁ", "ẁ", "W̌", "w̌", "X̆", "x̆", "X́", "x́", "X̌", "x̌", "X̧", "x̧", "Ý", "ý", "ÿ", "Ŷ", "ŷ", "Ÿ", "Y̆", "y̆", "Ỳ", "ỳ", "Y̌", "y̌", "Ź", "ź", "Ż", "ż", "Ž", "ž", "Z̧", "z̧", "Ѓ", "ѓ", "ё", "Ё", "й", "Й", "Ќ", "ќ" ]
		//const target_letters = [ "ss", "A", "A", "A", "A", "A", "A", "A", "A", "A", "A", "A", "A", "A", "A", "A", "A", "A", "A", "A", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a", "A", "a", "A", "a", "A", "a", "A", "a", "A", "a", "A", "a", "A", "a", "A", "a", "AE", "ae", "AE", "ae", "B", "b", "B", "b", "C", "C", "c", "c", "C", "c", "C", "c", "C", "c", "C", "c", "C", "c", "C", "c", "D", "d", "D", "d", "D", "d", "D", "d", "E", "E", "E", "E", "E", "E", "E", "E", "E", "E", "E", "E", "E", "E", "E", "E", "e", "e", "e", "e", "e", "e", "e", "e", "e", "e", "e", "e", "e", "e", "e", "e", "E", "e", "E", "e", "E", "e", "E", "e", "E", "e", "E", "e", "E", "e", "E", "e", "E", "e", "E", "e", "f", "F", "f", "G", "G", "g", "g", "G", "g", "G", "g", "G", "g", "G", "g", "H", "h", "H", "h", "H", "h", "H", "h", "H", "h", "I", "I", "I", "I", "I", "I", "I", "I", "i", "i", "i", "i", "i", "i", "i", "i", "I", "i", "I", "i", "I", "i", "I", "i", "I", "i", "I", "i", "I", "i", "I", "i", "I", "i", "I", "i", "IJ", "ij", "J", "j", "J", "j", "K", "k", "K", "k", "K", "k", "K", "k", "L", "l", "L", "l", "L", "l", "L", "l", "l", "l", "M", "m", "M", "m", "M", "m", "M", "m", "N", "n", "N", "n", "N", "n", "N", "n", "n", "N", "n", "N", "n", "O", "O", "O", "O", "O", "O", "O", "O", "O", "O", "O", "O", "O", "O", "O", "O", "O", "O", "O", "O", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "O", "o", "O", "o", "O", "o", "O", "o", "O", "o", "O", "o", "O", "o", "O", "o", "O", "o", "O", "o", "OE", "oe", "P", "p", "P", "p", "P", "p", "Q", "q", "Q", "q", "R", "r", "R", "r", "R", "r", "R", "r", "R", "r", "R", "r", "R", "r", "S", "s", "S", "s", "S", "S", "s", "s", "S", "s", "s", "S", "s", "S", "s", "T", "t", "t", "T", "T", "t", "T", "t", "T", "t", "TH", "th", "U", "U", "U", "U", "U", "U", "U", "U", "U", "u", "u", "u", "u", "u", "u", "u", "u", "u", "U", "u", "U", "u", "U", "u", "U", "u", "U", "u", "U", "u", "U", "u", "U", "u", "U", "u", "U", "u", "U", "u", "U", "u", "U", "u", "U", "u", "U", "u", "U", "u", "U", "u", "U", "u", "V", "v", "V", "v", "W", "w", "W", "w", "W", "w", "W", "w", "X", "x", "X", "x", "X", "x", "X", "x", "Y", "y", "y", "Y", "y", "Y", "Y", "y", "Y", "y", "Y", "y", "Z", "z", "Z", "z", "Z", "z", "Z", "z", "Г", "г", "е", "Е", "и", "И", "К", "к" ]
		match x {
			`à`, `á`, `ä` { res << `a` }
			`ò`, `ó`, `ö` { res << `o` }
			`ù`, `ú`, `ü` { res << `u` }
			`ß` { res << `s`; res << `s` }
			else { res << x }
		}
	}
	return res.string()
}

fn projects_compare(a &Project, b &Project) int {
	return alphanum_compare(a.title, b.title)
}

fn alphanum_compare(a &string, b &string) int {
    a_parts := split_parts(normalize_string(a))
    b_parts := split_parts(normalize_string(b))
    for i := 0; i < a_parts.len && i < b_parts.len; i++ {
		if a_parts[i] == b_parts[i] { continue }
        if a_parts[i][0] in special_chars && b_parts[i][0] in special_chars {
           return a_parts[i].compare(b_parts[i])
		}
		else if a_parts[i][0].is_digit() && b_parts[i][0].is_digit() {
            a_num := strconv.atoi(a_parts[i]) or { 0 }
            b_num := strconv.atoi(b_parts[i]) or { 0 }
            return a_num - b_num
		}
		else if a_parts[i][0] in special_chars {
			return -1
		}
		else if b_parts[i][0] in special_chars {
			return 1
		}
		else {
           return a_parts[i].compare(b_parts[i])
        }
    }
    return a_parts.len - b_parts.len
}

fn split_parts(s string) []string {
    mut parts := []string{}
    mut cur_part := ""
    for c in s {
        if c in special_chars {
			if cur_part.len > 0 && !(cur_part[cur_part.len - 1] in special_chars) { parts << cur_part; cur_part = "" }
			parts << c.ascii_str()
        }
		else if c.is_digit() {
			if cur_part.len > 0 && !cur_part[cur_part.len - 1].is_digit() { parts << cur_part;  cur_part = "" }
            cur_part += c.ascii_str()
        }
		else {
            if cur_part.len > 0 && (cur_part[cur_part.len - 1].is_digit() || (cur_part[cur_part.len - 1] in special_chars)) {  parts << cur_part; cur_part = "" }
            cur_part += c.ascii_str()
        }
    }
    if cur_part.len > 0 {
        parts << cur_part
    }
    return parts
}