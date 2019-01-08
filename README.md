# NAME

tag - a script which sets, modifies and inspect tags on the system.

# SYNOPSIS

tag \[--verbose\] \[--dir\[=\]&lt;path>\] --list\[\[=\]&lt;domain>\] | --set\[=\]&lt;tag>,&lt;tag>...| \[--match\[=\]\]&lt;tag> &lt;tag>... \[--exec\[=\]&lt;command>�\[&lt;args>\]\] | --help | --version

# OPTIONS

    --dir[=]<directory>            Change directory where tags are stored (default is /etc/tags.d).
    --exec[=]<command> [<args>]    Execute a command if match successful. 
    --help                         Print this help message. 
    --list[[=][<domain>]           List tags in specific domain (if any) or tags without a domain.
    --match[=]<tags list>          Match given tags with system tags. Exit status = 0 if all tags matched, exit status = 1 otherwise. 
    --set[=]<tags list>            Set/delete tags.
    --verbose                      Turn on verbose messages.
    --version                      Prints version.
    
    <tags list> is a <tag>,<tag>,<tag>... or <tag> <tag> <tag>...

    <tag> is [+|-][<domain>:]<identifier> where:

    <domain>       tag namespace (optional)
    <identifier>   tag name (alphanumeric)
    +              (may be omitted) sets a tag (with --set) or matches presence of tag (with --match)
    -              removes a tag (with --set) or matches absence of tag (with --match)

# EXAMPLES

**tag --set +tag1,tag2**

        Sets tag1 and tag2 (note omitted '+' in tag2)

**tag --set local:tag1 -tag2**

           Sets tag1 in 'local' namespace and clears tag2
    

**tag --list**

          Lists tags
    

**tag --list work**

           Lists tags in 'work' namespace
    

**tag --match='tag2,-tag1'**

        Match presence of tag2 and absence of tag1

**tag tag3 -tag4**

           Match presence of tag3 and absence of tag4 (shorter form)
    

**tag tag5 tag6 --exec 'echo "tag5 and tag6 matched"'**

           Executes echo command if tag2 and tag6 present
    

**tag tag7,-tag8 && echo "use shell's command lists"**

           Executes echo command if tag7 presend and tag8 absent (shell compatible)
    

**tag tag8 || tag tag10 && tag -tag11 && echo "and this too"**

        Executes echo command if tag8 or tag10 present and tag11 absent
