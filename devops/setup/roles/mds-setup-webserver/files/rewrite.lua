file = lighty.c.stat(  lighty.r.req_attr["physical.doc-root"] .. lighty.r.req_attr["uri.path"] .. '/index.html' )
if ( file ) then
  return file["http-response-send-file"]
end
return 0
