---
title: Capturing terminal as HTML
hidden: false
# edit_date:
---
Here's a little script to record terminal sessions. It uses `script` to neatly record the commands and their output, and then transforms that typescript with `aha` to HTML with some minimal styling.

{% capture c %}{% raw %}
#!/usr/bin/env bash
echo $(pwd) > ~/.capture_relative_prompt_base

prompter() {
  current=$(pwd)
  base=$(<~/.capture_relative_prompt_base)
  relative_with_slash=${current#"$base"}
  relative=${relative_with_slash#"/"}
  export PS1="$relative\$ "
}

export -f prompter
export PROMPT_COMMAND=prompter
script -q
cd $(<~/.capture_relative_prompt_base)
cat ./typescript | tail -n +2 | head -n -3 | aha --black --no-header > capture.html
rm ./typescript
{% endraw %}{% endcapture %}{% include code_block.html code=c lang="bash" numbered=true %}

This is very limited but it allows to capture text without full terminal prompt and marks parts that are different color, so that I can easily add slightly better styling classes for them. Here's an example recording:

{% raw %}
<div><pre><code class="terminal">$ ls -al .
total 12
drwxrwxr-x  3 michal michal 4096 wrz  6 23:57 <span style="font-weight:bold;color:#3333FF;">.</span>
drwxr-xr-x 31 michal michal 4096 wrz  6 23:24 <span style="font-weight:bold;color:#3333FF;">..</span>
drwxrwxr-x  3 michal michal 4096 wrz  6 23:57 <span style="font-weight:bold;color:#3333FF;">directory</span>
-rwxrwxr-x  1 michal michal    0 wrz  6 23:24 <span style="font-weight:bold;color:lime;">executable</span>
-rw-rw-r--  1 michal michal    0 wrz  6 23:57 typescript
$ tree .
<span style="font-weight:bold;color:#3333FF;">.</span>
├── <span style="font-weight:bold;color:#3333FF;">directory</span>
│   ├── <span style="font-weight:bold;color:#3333FF;">nested</span>
│   └── other_file
├── <span style="font-weight:bold;color:lime;">executable</span>
└── typescript

2 directories, 3 files
$ cd directory/nested/
directory/nested$ cd ../../
$ exit</code></pre></div>
{% endraw %}

More interactive programs like `nano` can look pretty messed up. But overall editing that HTML with search+replace semems better than copying text and then manually finding every single place to add style.

I'd like to automate more of that editing away, and maybe add more features, like e.g. showing <kbd>Esc</kbd> etc and marking prompt command somehow to add click-to-copy through javascript for them.