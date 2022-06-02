---
title: Run Visual Studio Code inside Ubuntu or Debian Distrobox containers
---

[Distrobox](https://distrobox.privatedns.org/) is a toolbox (similar to Fedora's [toolbx](https://containertoolbx.org/)) for creating containerized Linux development environments. It is built around Podman (or Docker), and can run any "Dockerized" distro, on top of any systemd-based host distribution.

Because Distrobox transparently integrates with host's desktop environment, it can also be used for running graphical applications. (Distrobox containers are not well sandboxed [yet](https://github.com/89luca89/distrobox/issues/28), although you can configure them to at least use a separate `HOME` directory.) There is documentation on [running VSCode inside an Arch Linux container](https://distrobox.privatedns.org/posts/integrate_vscode_distrobox.html#the-easy-one). What if you need (or prefer) to use it on Debian-based containers?

You can create a new Ubuntu container with:

{% raw %}
<div><pre><code class="terminal">$ distrobox create --image ubuntu:latest --name ubuntu-latest --home &quot;$HOME/ubuntu-latest&quot; 
c6a17f85450195557fc1e39a3f37590a7eed00c4207b3746fb1b23a91fdd050d
Distrobox &apos;ubuntu-latest&apos; successfully created.
To enter, run:

distrobox-enter ubuntu-latest

[michal@yoga ~]$ distrobox enter ubuntu-latest
Container ubuntu-latest is not running.
Starting container ubuntu-latest
run this command to follow along:

 podman logs -f ubuntu-latest

 Starting container...                  	<font color="#859900"> [ OK ]</font>
 ...

Container Setup Complete!
{% endraw %}

In theory, to install VSCode, _all you need to do_ is follow their [official instructions](https://code.visualstudio.com/docs/setup/linux#_debian-and-ubuntu-based-distributions):

{% capture c %}{% raw %}
$ sudo apt-get install wget gpg
$ wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
$ sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
$ sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
$ rm -f packages.microsoft.gpg
$ sudo apt update && sudo apt install code
{% endraw %}{% endcapture %}{% include code_block.html code=c class="terminal" %}

In practice, when executing the `code` command from within the container, nothing happens. It is easy to put blame on Podman or Distrobox, e.g. for not setting up the Apparmor/SELinux policies correctly, or limiting the application in some other way. Turns out there's a small issue with Microsoft's VSCode `deb` packaging, where they don't specify all of the package's actual dependencies. It works completely fine on regular desktop system installations, because the missing packages are usually already installed.

## Solution

To fix the issue, you need to additionally run:

{% capture c %}{% raw %}
$ sudo apt install libasound2 libxshmfence1 libx11-xcb1
{% endraw %}{% endcapture %}{% include code_block.html code=c class="terminal" %}

That's it! Now you can start up VScode using the `code` command, or create a shortcut in your host's desktop environment with `distrobox-export --app code`.