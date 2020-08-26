local VERBOSE = (os.getenv('VERBOSE') == "true")

function dump(o)
  if type(o) == 'table' then
     local s = '{ '
     for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. dump(v) .. ','
     end
     return s .. '} '
  else
     return tostring(o)
  end
end

function log(object) 
   print(dump(object))
end

function verbose(object) 
   if VERBOSE == false then
      --return
   end

   log(object)
end