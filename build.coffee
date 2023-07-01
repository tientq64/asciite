fs = require "fs"
coffee = require "coffeescript"
stylus = require "stylus"

importRegex = /(?<=^|\n)(\t*)# import (.+)\n/
indentRegexG = /(^|\n)(?!\n)/g
code = fs.readFileSync "index.coffee", "utf8"
while match = importRegex.exec code
	[, tab, path] = match
	path += ".coffee" unless path.endsWith ".coffee"
	subcode = fs.readFileSync path, "utf8"
	subcode = subcode.replace indentRegexG, "\n#{tab}"
	code = code.replace importRegex, subcode
code = "do->\n" + code.replace(indentRegexG, "\n\t") + "return"
code = coffee.compile code, bare: yes

babel = require "@babel/core"
babelPresetReact = require "@babel/preset-react"
babelPluginProposalObjectRestSpread = require "@babel/plugin-proposal-object-rest-spread"
{code} = babel.transform code,
	ast: no
	comments: no
	compact: yes
	presets: [babelPresetReact]
	plugins: [babelPluginProposalObjectRestSpread]

uglify = require "uglify-es"
{code} = uglify.minify code

# jscrewit = require "jscrewit"
# code = jscrewit.encode code,
# 	features: "BROWSER"

css = fs.readFileSync "index.styl", "utf8"
css = stylus.render css
css = css
	.replace /\n|  |(?<=[,:>]) | (?=[{(>]|\!important)|(?<=[ ,(])0(?=\.)/g, ""
	.replace /;(?=\})/g, ""
	.replace /rgba\((\d+),(\d+),(\d+),(\.?\d+)\)/g, (s, r, g, b, a) =>
		r = (+r).toString(16).padStart(2, 0)
		g = (+g).toString(16).padStart(2, 0)
		b = (+b).toString(16).padStart(2, 0)
		a = Math.round(a * 255).toString(16).padStart(2, 0)
		if r[0] is r[1] and g[0] is g[1] and b[0] is b[1] and a[0] is a[1]
			r = r[0]
			g = g[0]
			b = b[0]
			a = a[0]
		a = "" if a in ["f", "ff"]
		"#" + r + g + b + a

html = fs.readFileSync "index.html", "utf8"
html = html
	.split /\s*\n\s*/
	.filter (val) => not /\ dev>/.test val
	.join ""
	.replace /<script |<\/head>/, "<link rel='stylesheet' href='index.css'>$&"
	.replace "</body>", "<script src='index.js'></script>$&"

fs.mkdirSync "dist" unless fs.existsSync "dist"
fs.writeFileSync "dist/index.js", code
fs.writeFileSync "dist/index.css", css
fs.writeFileSync "dist/index.html", html
