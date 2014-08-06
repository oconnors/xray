xquery version "1.0-ml";

module namespace blanket = "http://github.com/robwhitby/blanket/parser";

declare namespace s = 'http://www.w3.org/2005/xpath-functions';

declare function get-module-functions($dir as xs:string) as element(modules)
{
	<modules path="{$dir}">
	{
		for $filepath in get-modules($dir)
		let $funcs := parse($filepath)
	  return $funcs
	}
	</modules>
};


(: yuck :)
declare  function parse($module-path as xs:string) as element(module)*
{
	let $abs-path := fn:concat(fn:substring(xdmp:modules-root(), 1, fn:string-length(xdmp:modules-root()) - 1), $module-path)
	let $regex := fn:concat('declare\s+[A-Za-z %:]*\s+function\s+([^\(]+)\(')
	let $module := try { fn:string(xdmp:filesystem-file($abs-path)) } catch($e){}
	let $module-rel-path := $module-path
	where $module
	return
		let $lines := fn:tokenize($module, '\n')
		let $current := 0
		let $without-comments := fn:string-join(fn:analyze-string($module, '\(:.*?:\)', 's')/s:non-match, ' ')
		where 
			(: exclude main modules for now :)
			fn:exists($lines[fn:starts-with(., "module namespace")])
		return
			<module uri="{$module-rel-path}">
			{
				let $funcs := 
					for $match in fn:analyze-string($without-comments, $regex)/s:match
					let $line := $match/fn:string()
					let $line-nos := fn:index-of($lines, $lines[fn:contains(., $line)])
					let $name := if (fn:contains($match/s:group, ':')) then fn:substring-after($match/s:group, ":") else $match/s:group
					let $name := fn:replace($name, "\s", "")
					return 
						for $line-no in $line-nos
						return fn:concat($name, "|", $line-no)
				return
					for $f in fn:distinct-values($funcs)
					let $tokens := fn:tokenize($f, "\|")
					return <function name="{$tokens[1]}" start="{$tokens[2]}"/>
			}
			</module>
};


declare private function get-modules($dir as xs:string) as xs:string*
{
  let $fs-dir := fn:concat(xdmp:modules-root(), fn:replace($dir, "^/+", ""))
  where filesystem-directory-exists($fs-dir)
  return get-filelist($fs-dir)
};

declare private function get-filelist($dir as xs:string) as xs:string*
{
  for $entry in xdmp:filesystem-directory($dir)/dir:entry
  order by $entry/dir:type descending, $entry/dir:filename ascending
  return
    if ($entry/dir:type = "file")
    then 
      if (fn:matches($entry/dir:pathname, "\.xqy?$")) 
      then $entry/dir:pathname/fn:string()
      else ()
    else get-filelist($entry/dir:pathname/fn:string())
};

declare private function relative-path($path as xs:string) as xs:string
{
  fn:replace($path, xdmp:modules-root(), "/")
};

declare private function filesystem-directory-exists($dir as xs:string) as xs:boolean
{
  try  { fn:exists(xdmp:filesystem-directory($dir)) }
  catch($e) { fn:false() }
};