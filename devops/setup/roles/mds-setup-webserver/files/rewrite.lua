-- This file helps lighttpd decide how to handle a request to a MarkdownSite.
--
-- Take the following request: site.com/foo
--   These files will then be checked in order:
--
--    /var/www/hello.mds/html/foo
--    /var/www/hello.mds/html/foo.html
--    /var/www/hello.mds/html/foo/index.html
--    /var/www/hello.mds/html/foo/index.htm
--
--  The first of these files that matches is served for the request.
--
--  If no file matches, then the URL is rewritten so that MarkdownSite::CGI will
--  process the request.

file = lighty.c.stat(  lighty.r.req_attr["physical.doc-root"] .. lighty.r.req_attr["uri.path"]  )
if ( file and file.is_file ) then
  return file["http-response-send-file"]
end

file = lighty.c.stat(  lighty.r.req_attr["physical.doc-root"] .. lighty.r.req_attr["uri.path"] .. '.html' )
if ( file and file.is_file ) then
  return file["http-response-send-file"]
end

file = lighty.c.stat(  lighty.r.req_attr["physical.doc-root"] .. lighty.r.req_attr["uri.path"] .. '.htm' )
if ( file and file.is_file ) then
  return file["http-response-send-file"]
end

file = lighty.c.stat(  lighty.r.req_attr["physical.doc-root"] .. lighty.r.req_attr["uri.path"] .. '/index.html' )
if ( file and file.is_file ) then
  return file["http-response-send-file"]
end

file = lighty.c.stat(  lighty.r.req_attr["physical.doc-root"] .. lighty.r.req_attr["uri.path"] .. '/index.htm' )
if ( file and file.is_file ) then
  return file["http-response-send-file"]
end


-- No static files found, let markdownsite.cgi handle this request.
if ( string.sub(lighty.r.req_attr["request.uri"], 0, 9 )  ~= "/cgi-bin/" ) then
  lighty.env["uri.path"]          = "/cgi-bin/markdownsite.cgi" .. lighty.env["uri.path"]
  lighty.env["physical.rel-path"] = lighty.env["uri.path"]
  lighty.env["request.orig-uri"]  = lighty.env["request.uri"]
  lighty.env["physical.path"]     = "/var/lib/cgi-bin/" .. lighty.env["physical.rel-path"]
end

return 0
