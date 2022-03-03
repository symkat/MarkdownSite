file = lighty.c.stat(  lighty.r.req_attr["physical.doc-root"] .. string.sub(lighty.r.req_attr["uri.path"], 26) .. '/index.html' )
if ( file ) then
  return file["http-response-send-file"]
end
return 0
