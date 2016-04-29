path = require 'path'
fs = require 'fs'
_ = require 'lodash'
config = require './config.coffee'

regex_map = {}
for k, v of config
  for ext in v.type
    ext = ext.substring(2)
    if regex_map[ext]
      regex_map[ext] = _.uniq(v.regex, regex_map[ext])
    else
      regex_map[ext] = v.regex

directoryTree = (base_path) ->
  item = {path: base_path}

  try
    stats = fs.statSync(base_path)
  catch e
    return null

  if stats.isFile()
    ext = path.extname(base_path).toLowerCase().substring(1)
    if ext not in _.keys(regex_map)
      return null
    item.ext = ext
    item.mtime = stats.mtime.getTime()
    item.definition = []
    data = fs.readFileSync(base_path, 'utf8')
    for regex_str in regex_map[ext]
      regex_str = regex_str.replace(/{word}/g, '([a-zA-Z0-9_]+)')
      regex = new RegExp(regex_str, 'ig')
      results = data.match(regex)
      if results
        for result in results
          regex = new RegExp(regex_str, 'i')
          result = regex.exec(result)
          item.definition.push result[1]
    item.definition = _.uniq(item.definition)
  else
    item.children = fs.readdirSync(base_path)
      .map (child) =>
        directoryTree path.join(base_path, child)
      .filter (file) =>
        return file

    if not item.children.length
      return null

  return item

console.time('search')
files = directoryTree('../')
console.timeEnd('search')

fs.writeFile('./data.json', JSON.stringify(files, null, 2) , 'utf-8');
