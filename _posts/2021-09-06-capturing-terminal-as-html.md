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

This is very limited and falls appart when using more interactive programs. But it allows to capture text without full terminal prompt and marks parts that are different color, so that I can easily add slightly better styling classes for them. Here's an example recording:

{% raw %}
<div><pre><code class="terminal">$ ls -l
total 4
drwxrwxr-x 2 michal michal 4096 wrz  6 23:24 <span style="font-weight:bold;color:#3333FF;">directory</span>
-rwxrwxr-x 1 michal michal    0 wrz  6 23:24 <span style="font-weight:bold;color:lime;">executable</span>
-rw-rw-r-- 1 michal michal    0 wrz  6 23:24 file
-rw-rw-r-- 1 michal michal    0 wrz  6 23:35 typescript
$ nano file
<span style="color:white;background-color:white;"></span><span style="color:black;background-color:white;">[ Reading... ]</span><span style="color:black;background-color:white;">[ Read 0 lines ]</span><span style="color:black;background-color:white;">  GNU nano 4.8                                     file                                                </span>
<span style="color:black;background-color:white;">^G</span> Get Help   <span style="color:black;background-color:white;">^O</span> Write Out  <span style="color:black;background-color:white;">^W</span> Where Is   <span style="color:black;background-color:white;">^K</span> Cut Text   <span style="color:black;background-color:white;">^J</span> Justify    <span style="color:black;background-color:white;">^C</span> Cur Pos    <span style="color:black;background-color:white;">M-U</span> Undo
<span style="color:black;background-color:white;">^X</span> Exit<span style="color:black;background-color:white;">^R</span> Read File  <span style="color:black;background-color:white;">^\</span> Replace    <span style="color:black;background-color:white;">^U</span> Paste Text <span style="color:black;background-color:white;">^T</span> To Spell   <span style="color:black;background-color:white;">^_</span> Go To Line <span style="color:black;background-color:white;">M-E</span> Redo
<span style="color:white;background-color:white;"></span><span style="color:black;background-color:white;">Modified</span>
hey !           <span style="color:black;background-color:white;">M-D</span> DOS Format           <span style="color:black;background-color:white;">M-A</span> Append<span style="color:black;background-color:white;">M-B</span> Backup File<span style="color:black;background-color:white;">C</span> Cancel<span style="color:black;background-color:white;">M-M</span> Mac Format           <span style="color:black;background-color:white;">M-P</span> Prepend<span style="color:black;background-color:white;">^T</span> To Files
<span style="color:black;background-color:white;">File Name to Write: file                                                                               </span> <span style="color:black;background-color:white;">[ Writing... ]</span><span style="color:black;background-color:white;">        </span><span style="color:black;background-color:white;">[ Wrote 1 line ]</span><span style="color:black;background-color:white;">^O</span> Write Out  <span style="color:black;background-color:white;">^W</span> Where Is   <span style="color:black;background-color:white;">^K</span> Cut Text   <span style="color:black;background-color:white;">^J</span> Justify    <span style="color:black;background-color:white;">^C</span> Cur Pos    <span style="color:black;background-color:white;">M-U</span> Undo<span style="color:black;background-color:white;">X</span> Exit       <span style="color:black;background-color:white;">^R</span> Read File  <span style="color:black;background-color:white;">^\</span> Replace    <span style="color:black;background-color:white;">^U</span> Paste Text <span style="color:black;background-color:white;">^T</span> To Spell   <span style="color:black;background-color:white;">^_</span> Go To Line <span style="color:black;background-color:white;">M-E</span> Redo


$ cat file
hey !
$ exit</code></pre></div>
{% endraw %}

The part with `nano` looks pretty messed up. Overall editing that HTML with search+replace semems better than copying text and then manually finding every single place to add style.
