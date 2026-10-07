# Literal, sequential Edit/MultiEdit reconstruction. Never interpret text as code.
def edit($e):
  if ($e.old_string|type)!="string" or ($e.new_string|type)!="string" or $e.old_string==""
  then error("unsupported edit shape")
  else split($e.old_string) as $parts |
    if ($parts|length)==1 then error("old_string absent")
    elif ($parts|length)>2 and ($e.replace_all // false)!=true then error("ambiguous edit")
    else $parts | join($e.new_string) end
  end;
.tool_input as $input |
if ($input.content|type)=="string" then $input.content
elif ($input.edits|type)=="array" then
  reduce $input.edits[] as $e ($current; edit($e))
elif ($input.old_string|type)=="string" then $current | edit($input)
else error("unsupported prospective write shape") end
