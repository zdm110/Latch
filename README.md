### Illustrate
- This project aims to deploy _**OpenGrok**_ on Unix-like as easy as possible
- Imcremental installation and subsequential handling all in one
- serveral packages and scripts provided

Package | Version | Repo | Comment
:---: |:---: | :---: | ---
Universal ctags | latest | [Universal-Ctags](https://github.com/universal-ctags/ctags) | source compile
Java | 8u172 | [Jdk-Splits](./packages/jdk-splits) | using [split and cat](https://github.com/xiangp126/split-and-cat)
Tomcat | 8.5.31 | [Packages](./packages) | local binary
OpenGrok | 1.1-rc33 | [OpenGrok](https://github.com/oracle/opengrok) | official binary
- Take my [Giggle](http://giggle.ddns.net:8080/source) as example and refer [Guide](./gif/guide.gif) 
- Support *Mac OS* since `tag 2.9`

> Latest released version: 3.0

### Quick Start
```bash
git clone https://github.com/xiangp126/Latch
```
```bash
sh oneKey.sh

[NAME]
    sh oneKey.sh -- setup OpenGrok through one key stroke

[SYNOPSIS]
    sh oneKey.sh [install | summary | help] [PORT]

[EXAMPLE]
    sh oneKey.sh [help]
    sh oneKey.sh install
    sh oneKey.sh install 8081
    sh oneKey.sh summary

[DESCRIPTION]
    install -> install opengrok, need root privilege but no sudo prefix
    help    -> print help page
    summary -> print tomcat/opengrok guide and installation info

[TIPS]
    Default listen-port is 8080 if [PORT] was omitted

  ___  _ __   ___ _ __   __ _ _ __ ___ | | __
 / _ \| '_ \ / _ \ '_ \ / _` | '__/ _ \| |/ /
| (_) | |_) |  __/ | | | (_| | | | (_) |   <
 \___/| .__/ \___|_| |_|\__, |_|  \___/|_|\_\
      |_|               |___/
```
```bash
sh oneKey.sh install
```
> Take you server address as 127.0.0.1 for example<br>
> Put your source code into `OPENGROK_SRC_ROOT` as per directory

```bash
./OpenGrok index
```

_then browser your `http://127.0.0.1:8080/source`_

### Handle Service
#### Mac
```bash
catalina stop
catalina start
```

#### Linux
```bash
sudo ./daemon stop
sudo ./daemon start
```

### Create Index
```
# make index of source (multiple index)
./OpenGrok index [/opt/o-source]
                  /opt/source   -- proj1
                                -- proj2
                                -- proj3

---------------------------------------- SUMMARY ----
universal ctags path = /usr/local/bin/ctags
java path = /opt/java8/bin/java
jsvc path = /opt/tomcat8/bin/jsvc
java home = /opt/java8
tomcat home = /opt/tomcat8
opengrok instance base = /opt/opengrok
opengrok source root = /opt/o-source
http://127.0.0.1:8080/source
------------------------------------------------------
```

### Handy tools - _Auto Pull_
_only support Git repository, auto re-indexing_

```bash
# Go into your OPENGROK_SRC_ROOT
pwd
/opt/o-source

ls
coreutils-8.21      dpdk-stable-17.11.2 glibc-2.7           libconhash
dpdk-stable-17.05.2 dpvs                keepalived          nginx
```

_add or remove item in *`updateDir`* of [autopull.sh](./autopull.sh)_

```bash
updateDir=(
    "dpvs"
    "keepalived"
    "Add Repo Name according to upper dir name"
)
```

_execute it_

```bash
sh autopull.sh
```

### Handy tools - _Auto Rsync_
```bash
cat template/rsync.config
# config server info | rsync from
SSHPORT=
SSHUSER=
SERVER=
SRCDIR_ON_SERVER=

cp ./template/rsync.config .
vim rsync.config
# fix the information as instructed
```

```bash
sh rsync.sh
```

### Handy tools - _Cron Tool_
_chage the time as you wish in [addcron.sh](./addcron.sh)_

```bash
# Generate crontab file
cat << _EOF > $crontabFile
04 20 * * * $updateShellPath &> $logFile
_EOF
```

_and change *`updateShellPath`* as the shell needs auto executed by cron as you wish, default is `autopull.sh`_

```bash
updateShellPath=$mainWd/autopull.sh
```

_execute it_

```bash
sh addcron.sh
```

### Notice
    If you use EZ-Zoom on Chrome with OpenGrok, make sure it's 100% or OpenGrok will jump to the wrong line

### License
The [MIT](./LICENSE.txt) License (MIT)
