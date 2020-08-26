-- Source: http://lua.2524044.n2.nabble.com/split-and-splitlines-in-5-3-td7687815.html
function split_string(str, pat)
  local arr = {}
  string.gsub(str, pat or "([^%s]+)", function (word)
      table.insert(arr, word)
    end)
  return arr
end

function split_lines(bigstr)
  local arr = split(bigstr, "([^\n]*)\n?")
  if _VERSION:sub(5) < "5.3" then
    table.remove(arr)
  end
  return arr
end