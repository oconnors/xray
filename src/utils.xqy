xquery version '1.0-ml';

module namespace utils = 'http://github.com/robwhitby/xray/utils';
declare namespace xray = 'http://github.com/robwhitby/xray';
declare namespace test = 'http://github.com/robwhitby/xray/test';
import module namespace parser = 'XQueryML10' at 'parsers/XQueryML10.xq';


declare function utils:get-filelist($dir as xs:string) as xs:string*
{
  for $entry in xdmp:filesystem-directory($dir)/dir:entry
  order by $entry/dir:type descending, $entry/dir:filename ascending
  return
    if ($entry/dir:type = 'file')
    then 
      if (fn:matches($entry/dir:pathname, '.xqy?$')) 
      then $entry/dir:pathname/fn:string()
      else ()
    else utils:get-filelist($entry/dir:pathname/fn:string())
};


declare function utils:get-functions($module-path as xs:string) as xdmp:function*
{
  let $parsed := utils:parse-xquery($module-path)
  return 
    for $fn in $parsed//FunctionDecl
    where $fn[fn:not(TOKEN = 'private')]
    return xdmp:function(xs:QName($fn/FunctionName/QName), fn:replace($module-path, xdmp:modules-root(), '/'))
};


declare function utils:get-modules($test-dir as xs:string, $pattern as xs:string?) as xs:string*
{
  let $fs-dir := fn:concat(xdmp:modules-root(), fn:replace($test-dir, '^/+', ''))
  where xdmp:filesystem-file-exists($fs-dir)
  return
    for $filepath in utils:get-filelist($fs-dir)
    where fn:matches(utils:relative-path($filepath), $pattern)
    return $filepath
};


declare function utils:relative-path($path as xs:string) as xs:string
{
  fn:replace($path, xdmp:modules-root(), '/')
};


declare function utils:get-local-name($fn as xdmp:function) as xs:string
{
  fn:string(fn:local-name-from-QName(xdmp:function-name($fn)))
};


declare function utils:transform(
  $el as element(), 
  $test-dir as xs:string, 
  $module-pattern as xs:string?, 
  $test-pattern as xs:string?, 
  $format as xs:string
) as document-node()
{
  if ($format eq 'text') then xdmp:set-response-content-type('text/plain') else ()
  ,
  if ($format = ('html', 'text'))
  then 
    let $params := map:map()
    let $_ := map:put($params, 'test-dir', $test-dir)
    let $_ := map:put($params, 'module-pattern', $module-pattern)
    let $_ := map:put($params, 'test-pattern', $test-pattern)
    return xdmp:xslt-invoke(fn:concat('output/', $format, '.xsl'), $el, $params)
  else document { $el }
};


declare function utils:parse-xquery($module-path as xs:string) as element(XQuery)
{
  let $source := fn:string(xdmp:filesystem-file($module-path))
  return parser:parse-XQuery($source)
};
