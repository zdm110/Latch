#!/bin/bash
# from which path it was executed
startDir=`pwd`
# absolute path of this shell, not influenced by start dir
mainWd=$(cd $(dirname $0); pwd)
# common install directory
rootInstDir=/opt
commInstdir=$rootInstDir
# execute prefix: sudo
execPrefix="sudo"
# universal ctags install dir
uCtagsInstDir=${commInstdir}/u-ctags
javaInstDir=/opt/java8
tomcatInstDir=/opt/tomcat8
# default new listen port is 8080
newListenPort=8080
serverXmlPath=${tomcatInstDir}/conf/server.xml
srvXmlTemplate=$mainWd/template/server.xml
# dynamic env global name
dynamicEnvName=dynamic.env
opengrokInstanceBase=/opt/opengrok
openGrokBinPath=""
opengrokSrcRoot=${commInstdir}/o-source
# new user/group to run tomcat
tomcatUser=tomcat8
tomcatGrp=tomcat8
# store install summary
summaryTxt=INSTALLATION.TXT
mRunFlagFile=$mainWd/.MORETIME.txt
# store all downloaded packages here
downloadPath=$mainWd/downloads
# store JDK/Tomcat packages
pktPath=$mainWd/packages
loggingPath=$mainWd/log
callIndexerFilePath=$mainWd/callIndexer
isSourceWarDeployed=false
OpenGrokVersion=1.1-rc74

logo() {
    cat << "_EOF"
  ___  _ __   ___ _ __   __ _ _ __ ___ | | __
 / _ \| '_ \ / _ \ '_ \ / _` | '__/ _ \| |/ /
| (_) | |_) |  __/ | | | (_| | | | (_) |   <
 \___/| .__/ \___|_| |_|\__, |_|  \___/|_|\_\
      |_|               |___/

_EOF
}

usage() {
    exeName=${0##*/}
    cat << _EOF
[NAME]
    sh $exeName -- setup OpenGrok through one key stroke

[SYNOPSIS]
    sh $exeName [install | summary | help] [PORT]

[EXAMPLE]
    sh $exeName [help]
    sh $exeName install
    sh $exeName install 8081
    sh $exeName summary

[DESCRIPTION]
    install -> install opengrok, need root privilege but no sudo prefix
    help    -> print help page
    summary -> print tomcat/opengrok guide and installation info

[TIPS]
    Default listen-port is $newListenPort if [PORT] was omitted

_EOF
    logo
}

installuCtags() {
    # check if already installed
    checkCmd=`ctags --version | grep -i universal 2> /dev/null`
    if [[ $checkCmd != "" ]]; then
        uCtagsPath=`which ctags`
        uCtagsBinDir=${uCtagsPath%/*}
        uCtagsInstDir=${uCtagsBinDir%/*}
        return
    fi
    # check if this shell already installed u-ctags
    uCtagsPath=$uCtagsInstDir/bin/ctags
    if [[ -x "$uCtagsPath" ]]; then
        echo "[Warning]: already has u-ctags installed"
        return
    fi
    cat << "_EOF"
------------------------------------------------------
Installing Universal Ctags
------------------------------------------------------
_EOF
    cd $downloadPath
    clonedName=ctags
    if [[ -d "$clonedName" ]]; then
        echo [Warning]: $clonedName/ already exist
    else
        git clone https://github.com/universal-ctags/ctags
        # check if git clone returns successfully
        if [[ $? != 0 ]]; then
            echo [Error]: git clone error, quiting now
            exit
        fi
    fi

    cd $clonedName
    # pull the latest code
    git pull
    ./autogen.sh
    ./configure --prefix=$uCtagsInstDir
    make -j
    # check if make returns successfully
    if [[ $? != 0 ]]; then
        echo [Error]: make error, quitting now
        exit
    fi

    $execPrefix make install
    # check if make returns successfully
    if [[ $? != 0 ]]; then
        echo [Error]: make install error, quitting now
        exit
    fi
    cat << _EOF
------------------------------------------------------
ctags path = $uCtagsPath
------------------------------------------------------
$($uCtagsPath --version)
_EOF
}

reAssembleJDK() {
    cat << "_EOF"
------------------------------------------------------
Re-assemble Jdk Using Linux split & cat
------------------------------------------------------
_EOF
    jdkSliceDir=$mainWd/packages/jdk-splits
    slicePrefix=jdk-8u172-linux-x64
    jdkTarName=${slicePrefix}.tar.gz

    cd $pktPath
    if [[ -f "$jdkTarName" ]]; then
        echo [Warning]: Already has JDK re-assembled, skip
        return
    fi
    # check if re-assemble successfully
    cat $jdkSliceDir/${slicePrefix}a* > $jdkTarName
    if [[ $? != 0 ]]; then
        echo [Error]: cat JDK tar.gz error, quiting now
        exit
    fi
    cat << "_EOF"
------------------------------------------------------
Checking the Shasum of Jdk
------------------------------------------------------
_EOF
    shasumPath=`which sha256sum 2> /dev/null`
    if [[ $shasumPath == "" ]]; then
        return
    fi
    checkSumPath=../template/jdk.checksum
    if [[ ! -f ${checkSumPath} ]]; then
        echo [Error]: missing jdk checksum file, default match
        return
    fi
    ret=$(sha256sum --check $checkSumPath)
    checkRet=$(echo $ret | grep -i ok 2> /dev/null)
    if [[ "$checkRet" == "" ]]; then
        echo [FatalError]: jdk checksum failed
        exit 255
    fi
}

installJava8() {
    cat << "_EOF"
------------------------------------------------------
Installing Java version 8
------------------------------------------------------
_EOF
    javaPath=$javaInstDir/bin/java
    if [[ -x $javaPath ]]; then
        echo "[Warning]: already has java 8 installed, skip"
        return
    fi
    # tackle to install java8
    JAVA_HOME=$javaInstDir
    jdkVersion=jdk-8u172-linux-x64
    tarName=${jdkVersion}.tar.gz

    $execPrefix rm -rf $javaInstDir
    $execPrefix mkdir -p $javaInstDir
    cd $pktPath
    $execPrefix tar -zxv -f $tarName --strip-components=1 -C $javaInstDir
    # check if returns successfully
    if [[ $? != 0 ]]; then
        echo [Error]: untar java package error, quitting now
        exit
    fi

    # javaPath=$javaInstDir/bin/java already defined at top
    if [[ ! -x $javaPath ]]; then
        echo [Error]: java install error, quitting now
        exit
    fi
    # change owner of java install directory to root:root
    $execPrefix chown -R root:root $javaInstDir

    cat << _EOF
------------------------------------------------------
java package install path = $javaInstDir
java path = $javaPath
$($javaPath -version)
------------------------------------------------------
_EOF
}

changeListenPort() {
    # Restore server.sml to original
    # srvXmlTemplate=$mainWd/template/server.xml
    $execPrefix cp $srvXmlTemplate $serverXmlPath

    # change listen port if not the default value, passed as $1
    if [[ "$1" != "" && "$1" != 8080 ]]; then
        newListenPort=$1
        cat << _EOF
------------------------------------------------------
Changing Default Listen Port 8080 to $newListenPort
------------------------------------------------------
_EOF
        $execPrefix sed -i --regexp-extended \
            "s/(<Connector port=)\"8080\"/\1\"${newListenPort}\"/" \
            $serverXmlPath
        # check if returns successfully
        if [[ $? != 0 ]]; then
            echo [Error]: change listen port error, quitting now
            exit
        fi
    fi
}

installTomcat8() {
    cat << "_EOF"
------------------------------------------------------
Installing Tomcat version 8
------------------------------------------------------
_EOF
    # check, if jsvc already compiled, return
    jsvcPath=$tomcatInstDir/bin/jsvc
    if [[ -x $jsvcPath ]]; then
        # copy template server.xml to replace old version
        # serverXmlPath=${tomcatInstDir}/conf/server.xml
        if [[ ! -f $serverXmlPath ]]; then
            echo [Error]: missing $serverXmlPath, please check it
            exit 255
        fi

        # change listen port if not the default value, passed as $1
        changeListenPort $1
        return
    fi

    # run tomcat using newly made user: tomcat:tomcat
    newUser=$tomcatUser
    newGrp=$tomcatGrp
    # create group if not exist
    egrep "^$newGrp" /etc/group &> /dev/null
    if [[ $? = 0 ]]; then
        echo [Warning]: group $newGrp already exist
    else
        $execPrefix groupadd $newUser
    fi
    # create user if not exist
    egrep "^$newUser" /etc/passwd &> /dev/null
    if [[ $? = 0 ]]; then
        echo [Warning]: group $newGrp already exist
    else
        $execPrefix useradd -s /bin/false -g $newGrp -d $tomcatInstDir $newUser
    fi

    # wgetLink=http://www-eu.apache.org/dist/tomcat/tomcat-8/v8.5.27/bin
    tomcatVersion=apache-tomcat-8.5.31
    tarName=${tomcatVersion}.tar.gz

    cd $pktPath
    # untar into /opt/tomcat and strip one level directory
    if [[ ! -d $tomcatInstDir ]]; then
        $execPrefix mkdir -p $tomcatInstDir
        $execPrefix tar -zxv -f $tarName --strip-components=1 -C $tomcatInstDir
    fi
    # check if untar returns successfully
    if [[ $? != 0 ]]; then
        echo [Error]: untar tomcat package error, quitting now
        exit
    fi

    # change owner:group of TOMCAT_HOME
    $execPrefix chown -R $newUser:$newGrp $tomcatInstDir
    cd $tomcatInstDir
    $execPrefix chmod 775 conf
    $execPrefix chmod g+r conf/*

    # change listen port if not the default value, passed as $1
    changeListenPort $1

    # make daemon script to start/shutdown Tomcat
    cd $mainWd
    # template script to copy from
    sptCopyFrom=./template/daemon.sh
    # rename this script to
    daeName=daemon.sh
    if [[ ! -f $daeName ]]; then
        cp $sptCopyFrom $daeName
        # add source command at top of script daemon.sh
        sed -i "2a source ${mainWd}/${dynamicEnvName}" $daeName
    fi
    # check if returns successfully
    if [[ $? != 0 ]]; then
        echo [Error]: make daemon.sh error, quitting now
        exit
    fi
    cat << _EOF
------------------------------------------------------
Start to Compiling Jsvc
------------------------------------------------------
_EOF
    $execPrefix chmod 755 $tomcatInstDir/bin
    cd $tomcatInstDir/bin
    jsvcTarName=commons-daemon-native.tar.gz
    jsvcUntarName=commons-daemon-1.1.0-native-src
    # jsvcUntarName=commons-daemon-1.0.15-native-src
    if [[ ! -f $jsvcTarName ]]; then
        echo [Error]: $jsvcTarName not found, wrong tomcat package downloaded
        exit
    fi
    if [[ ! -d $jsvcUntarName ]]; then
        $execPrefix tar -zxv -f $jsvcTarName
    fi
    $execPrefix chmod -R 777 $jsvcUntarName

    # enter into commons-daemon-1.1.0-native-src
    cd $jsvcUntarName/unix
    sh support/buildconf.sh
    ./configure --with-java=${javaInstDir}
    if [[ $? != 0 ]]; then
        echo [Error]: ./configure jsvc error, quitting now
        exit 255
    fi
    make -j
    # check if make returns successfully
    if [[ $? != 0 ]]; then
        echo [Error]: make error, quitting now
        exit 255
    fi

    $execPrefix cp jsvc ${tomcatInstDir}/bin
    # jsvcPath=$tomcatInstDir/bin/jsvc
    ls -l $jsvcPath
    if [[ $? != 0 ]]; then
        echo [Error]: check jsvc path error, quitting now
        exit
    fi
    # change owner of jsvc
    cd $tomcatInstDir/bin
    $execPrefix chown -R $newUser:$newGrp jsvc
    # remove jsvc build dir
    $execPrefix rm -rf $jsvcUntarName
}

makeDynEnv() {
    cat << _EOF
------------------------------------------------------
Making Dynamic Environment File for Sourcing
------------------------------------------------------
_EOF
    cd $mainWd
    JAVA_HOME=$javaInstDir
    TOMCAT_HOME=${tomcatInstDir}
    CATALINA_HOME=$TOMCAT_HOME
    # parse value of $var
    cat > $dynamicEnvName << _EOF
#!/bin/bash
export COMMON_INSTALL_DIR=$commInstdir
export UCTAGS_INSTALL_DIR=$uCtagsInstDir
export JAVA_HOME=${JAVA_HOME}
export JRE_HOME=${JAVA_HOME}/jre
export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib
export TOMCAT_USER=${tomcatUser}
export TOMCAT_HOME=${TOMCAT_HOME}
export CATALINA_HOME=${TOMCAT_HOME}
export CATALINA_BASE=${TOMCAT_HOME}
export CATALINA_TMPDIR=${TOMCAT_HOME}/temp
export OPENGROK_INSTANCE_BASE=${opengrokInstanceBase}
export OPENGROK_TOMCAT_BASE=$CATALINA_HOME
export OPENGROK_SRC_ROOT=$opengrokSrcRoot
# export OPENGROK_WEBAPP_CONTEXT=ROOT
# export OPENGROK_GENERATE_HISTORY=off
export OPENGROK_CTAGS=$uCtagsPath
export OPENGROK_BIN_PATH=$openGrokBinPath
_EOF
    # do not parse value of $var
    cat >> $dynamicEnvName << "_EOF"
export PATH=${JAVA_HOME}/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin
_EOF
    chmod +x $dynamicEnvName
}

# install OpenGrok
installOpenGrok() {
    cat << "_EOF"
------------------------------------------------------
Installing OpenGrok
------------------------------------------------------
_EOF
    wgetVersion=$OpenGrokVersion
    wgetLink=https://github.com/oracle/opengrok/releases/download/$wgetVersion
    tarName=opengrok-$wgetVersion.tar.gz
    untarName=opengrok-$wgetVersion

    opengropPath=$downloadPath/$untarName
    sourceWarPath=$tomcatInstDir/webapps/source.war
    $execPrefix ls -l $sourceWarPath 2> /dev/null
    if [[ $? == 0 ]]; then
        echo "[Warning]: already has source.war deployed, skip"
        isSourceWarDeployed=true
    fi

    cd $downloadPath
    # check if already has this tar ball.
    if [[ -f $tarName ]]; then
        echo [Warning]: Tar Ball $tarName already exist
    else
        wget --no-cookies \
            --no-check-certificate \
            --header "Cookie: oraclelicense=accept-securebackup-cookie" \
            "${wgetLink}/${tarName}" \
            -O $tarName
        # check if wget returns successfully
        if [[ $? != 0 ]]; then
            echo "wget OpenGrok version $OpenGrokVersion failed"
            exit 1
        fi
    fi

    if [[ ! -d $untarName ]]; then
        tar -zxv -f $tarName
    fi

    # will copy legacy bash OpenGrok script
    openGrokBinPath=$opengropPath/tools/OpenGrok
    cp -f $mainWd/template/OpenGrok $openGrokBinPath
    # call func makeDynEnv -- for legacy bash OpenGrok
    makeDynEnv

    # default deploy OpenGrok using python tools
    pythonDeployOpenGrok $untarName
    # only ready bash script OpenGrok, not use it to 'deploy'
    bashDeployOpenGrok $untarName

    # fix one warning
    $execPrefix mkdir -p ${opengrokInstanceBase}/{src,data,etc}
    $execPrefix cp -f $downloadPath/$untarName/doc/logging.properties \
                 ${opengrokInstanceBase}/logging.properties
    # mkdir opengrok SRC_ROOT if not exist
    $execPrefix mkdir -p $opengrokSrcRoot
    srcRootUser=`whoami 2> /dev/null`
    if [[ '$srcRootUser' != '' ]]; then
        $execPrefix chown -R $srcRootUser $opengrokSrcRoot
        $execPrefix chown -R $srcRootUser $opengrokInstanceBase
    fi

    # generating index
    callIndexer $untarName
}

# callIndexer <untarName>
callIndexer() {
    cat << "_EOF"
------------------------------------------------------
Prepare to Call Indexer
------------------------------------------------------
_EOF
    untarName=$1
    # $mainWd/downloads/opengrok-1.1-rc74
    opengropPath=$downloadPath/$untarName
    # /usr/local/bin/opengrok-indexer
    opengrokIndexPath=`which opengrok-indexer 2> /dev/null`
    if [[ "$opengrokIndexPath" == "" ]]; then
        echo No opengrok-indexer found, exit now
        exit 5
    fi

    # Example:
    # opengrok-indexer -C \
    #     -J=-Djava.util.logging.config.file=/opt/opengrok/logging.properties \
    #     -a /Users/corsair/myGit/let-opengrok/downloads/opengrok-1.1-rc74/lib/opengrok.jar -- \
    #     -s /opt/o-source -d /opt/opengrok/data -H -P -S -G \
    #     -W /opt/opengrok/etc/configuration.xml

    propertyFile=$opengrokInstanceBase/logging.properties
    callIndexerCommand=$(echo $opengrokIndexPath -C \
        -J=-Djava.util.logging.config.file=$propertyFile \
        -j $javaPath \
        -a $opengropPath/lib/opengrok.jar -- \
        -s $opengrokSrcRoot \
        -d $opengrokInstanceBase/data -H -P -S -G \
        -W $opengrokInstanceBase/etc/configuration.xml)

    # save indexer command into a shell
    makeIndexerFile $callIndexerCommand

    # opengrok-indexer will generate opengrok0.0.log, leaving them into log directory
    cd $loggingPath
    # $opengrokIndexPath -C -J=-Djava.util.logging.config.file=$propertyFile \
    #     -a $opengropPath/lib/opengrok.jar -- \
    #     -s $opengrokSrcRoot \
    #     -d $opengrokInstanceBase/data -H -P -S -G \
    #     -W $opengrokInstanceBase/etc/configuration.xml

    cat << "_EOF"
------------------------------------------------------
Generating Index using Python Tools
------------------------------------------------------
_EOF
    $callIndexerCommand

    if [[ $? != 0 ]]; then
        echo Generating index failed
        exit 1
    fi
}

# save indexer commands into a shell
makeIndexerFile() {
    cat << "_EOF"
------------------------------------------------------
Saving Indexer Commands into Bash Script
------------------------------------------------------
_EOF
    # $callIndexerCommand was set in func: installOpenGrok
    cat << _EOF > $callIndexerFilePath
#/bin/bash
set -x
cd $loggingPath
$callIndexerCommand
_EOF
    chmod +x $callIndexerFilePath
}

# pythonDeployBinPath <untarName>
pythonDeployOpenGrok() {
    cat << "_EOF"
------------------------------------------------------
Deploy OpenGrok Using Python Tools -- New Method
------------------------------------------------------
_EOF
    untarName=$1
    # $mainWd/downloads/opengrok-1.1-rc74
    opengropPath=$downloadPath/$untarName

    # check python3 env
    python3Path=`which python3 2> /dev/null`
    pythonDeployBinPath=`which opengrok-deploy 2> /dev/null`
    if [[ "$pythonDeployBinPath" == "" ]]; then
        if [[ "python3Path" == "" ]]; then
    cat << "_EOF"
No python3 installed, exit now
--- try
yum install python3 -y
apt-get install python3 -y
brew install python3 -y
---
_EOF
            exit 255
        fi

        # check pip env
        pipPath=`which pip 2>/dev/null`
        if [[ "$pipPath" == "" ]]; then
            # install pip
            curl https://bootstrap.pypa.io/get-pip.py | sudo python3
            if [[ $? != 0 ]]; then
                echo install pip failed
                echo apt-get install python3-pip
                exit 3
            fi
        fi

        # install python tools
        cd $opengropPath
        cd tools
        $execPrefix python3 -m pip install opengrok-tools.tar.gz
        # python3 -m pip uninstall opengrok-tools
        if [[ $? != 0 ]]; then
            echo install python tools failed
            exit 2
        fi
    fi

    # deploy OpenGrok
    if [[ "$isSourceWarDeployed" == "true" ]]; then
        return
    fi
    pythonDeployBinPath=`which opengrok-deploy 2> /dev/null`
    configPath=$opengrokInstanceBase/etc/configuration.xml

    # sudo opengrok-deploy -c /opt/opengrok/etc/configuration.xml \
    #     downloads/opengrok-1.1-rc74/lib/source.war \
    #     /usr/local/Cellar/tomcat/9.0.8/libexec/webapps
    $execPrefix $pythonDeployBinPath -c $configPath \
        $opengropPath/lib/source.war $tomcatInstDir/webapps

    if [[ $? != 0 ]]; then
        echo Deploy OpenGrok using Python Tools failed
        echo Jump to Deploy OpenGrok using Bash Script
        bashDeployOpenGrok
    fi
}

# bashDeployOpenGrok <untarName>
bashDeployOpenGrok() {
    cat << "_EOF"
------------------------------------------------------
Get Legacy OpenGrok Bash Script
------------------------------------------------------
_EOF
    untarName=$1
    opengropPath=$downloadPath/$untarName

    cd $opengropPath/tools
    # add write privilege to OpenGrok - the script
    chmod +x OpenGrok
    # add 'source command' on top of 'OpenGrok'
    # delete previous added 'source command' first
    # be careful for double quotation marks
    sed -i '/^source.*env$/d' OpenGrok 2> /dev/null
    sed -i "2a source ${mainWd}/${dynamicEnvName}" OpenGrok

#    # deploy OpenGrok war to tomcat
#    $execPrefix ./OpenGrok deploy
#    # [Warning]: OpenGrok can not be well executed from other location.

    if [[ $? != 0 ]]; then
        echo failed at bashDeployOpenGrok
    fi
}

installSummary() {
    cat > $summaryTxt << _EOF

---------------------------------------- Summary ----
Universal Ctags Path = $uCtagsPath
Java Path = $javaPath
_EOF
    if [[ $osType == "linux" ]]; then
        echo jsvc path = $jsvcPath >> $summaryTxt
    fi
    cat >> $summaryTxt << _EOF
Java Home = $javaInstDir
Tomcat Home = $tomcatInstDir
Opengrok Instance Base = $opengrokInstanceBase
Opengrok Source Root = $opengrokSrcRoot
Browser Site: http://127.0.0.1:${newListenPort}/source
_EOF
    cat >> $summaryTxt << _EOF
---------------------------------------- Indexer ----
$callIndexerFilePath
-----------------------------------------------------
_EOF
    cat $summaryTxt
}

printHelpPage() {
    if [[ $osType = "linux" ]]; then
        cat << _EOF
-------------------------------------------------
FOR TOMCAT 8 GUIDE
-------------------------------------------------
-- Under $mainWd
# start tomcat
sudo ./daemon.sh start
or
sudo ./daemon.sh run
sudo ./daemon.sh run &> /dev/null &
# stop tomcat
sudo ./daemon.sh stop
-------------------------------------------------
FOR OPENGROK GUIDE
-------------------------------------------------
-- Under ./downloads/opengrok-1.1-rc17/bin
# deploy OpenGrok
sudo ./OpenGrok deploy

# if make soft link of source to SRC_ROOT
# care for Permission of SRC_ROOT for user: $tomcatUser
cd $opengrokSrcRoot
sudo ln -s /usr/local/src/* .

# make index of source (multiple index)
sudo ./OpenGrok index [$opengrokSrcRoot]
                       /opt/source   -- proj1
                                     -- proj2
                                     -- proj3
--------------------------------------------------------
-- GUIDE TO CHANGE LISTEN PORT
# replace s/original/8080/ to the port you want to change
sudo sed -i 's/${newListenPort}/8080/' $serverXmlPath
sudo ./daemon.sh stop
sudo ./daemon.sh start
------------------------------------------------------
_EOF
    fi
    if [[ -f $summaryTxt ]]; then
        cat $summaryTxt
    fi
}

#start web service
tackleWebService() {
    # restart tomcat daemon underground
    cd $mainWd
    cat << _EOF
--------------------------------------------------------
Stop Tomcat Web Service
--------------------------------------------------------
_EOF
    if [[ $osType == "mac" ]]; then
        catalina stop 2> /dev/null
    else
        sudo ./daemon.sh stop
        retVal=$?
        # just print warning
        if [[ $retVal != 0 ]]; then
            set +x
            cat << _EOF
[Warning]: daemon stop returns value: $retVal
_EOF
            # loop to kill tomcat living threads if daemon method failed
            for (( i = 0; i < 2; i++ )); do
                # root   70057  431  0.1 38846760 318236 pts/39 Sl  05:36   0:08 jsvc.
                tomcatThreads=`ps aux | grep -i tomcat | grep -i jsvc.exec | tr -s " " \
                    | cut -d " " -f 2`
                if [[ "$tomcatThreads" != "" ]]; then
                    $execPrefix kill -15 $tomcatThreads
                    if [[ $? != 0 ]]; then
                        echo [Error]: Stop Tomcat failed $(echo $1 + 1 | bc) time
                        sleep 1
                        continue
                    fi
                else
                    break
                fi
            done
            set -x
        fi
    fi
    cat << _EOF
--------------------------------------------------------
START TOMCAT WEB SERVICE
--------------------------------------------------------
_EOF
    sleep 1
    if [[ $osType == "mac" ]]; then
        catalina start
    else
        # try some times to start tomcat web service
        $execPrefix ./daemon.sh start
    fi

    retVal=$?
    # just print warning
    if [[ $retVal != 0 ]]; then
        cat << _EOF
[Warning]: daemon start returns value: $retVal
_EOF
    fi
}

preInstallForMac() {
    cat << _EOF
--------------------------------------------------------
Pre-Install for Mac
--------------------------------------------------------
_EOF
    # brew cask remove caskroom/versions/java8
    if [[ ! -f $mRunFlagFile ]]; then
        brew cask install caskroom/versions/java8
        # check if java was successfully installed
        if [[ $? != 0 ]]; then
            cat << _EOF
If your Java application still asks for JRE installation, you might need
to reboot or logout/login.
_EOF
            exit 255
        fi
        brew install tomcat python3
        # pip install --upgrade pip
        pip3 install --upgrade pip
        touch $mRunFlagFile
    fi

    javaInstDir=$(/usr/libexec/java_home -v 1.8)
    javaPath=`which java 2> /dev/null`
    tomcatInstPDir=/usr/local/Cellar/tomcat
    instVersion=`cd $tomcatInstPDir&& ls`
    # such as /usr/local/Cellar/tomcat/9.0.8
    tomcatInstDir=$tomcatInstPDir/$instVersion/libexec
    serverXmlPath=${tomcatInstDir}/conf/server.xml
    tomcatUser=`whoami`
    tomcatGrp='staff'
}

install() {
    mkdir -p $downloadPath
    mkdir -p $loggingPath
    osName=`uname -s 2> /dev/null`
    if [[ "$osName" == "Darwin" ]]; then
        # os type is Mac OS
        osType=mac
        preInstallForMac
        # $1 passed as new listen port
        changeListenPort $1
    else
        # os type is Linux
        osType=linux
        reAssembleJDK
        installJava8
        # $1 passed as new listen port
        installTomcat8 $1
    fi
    installuCtags
    installOpenGrok
    tackleWebService
    installSummary
}

case $1 in
    'install')
        set -x
        install $2
        ;;

    "summary")
        set +x
        printHelpPage
        ;;

    *)
        set +x
        usage
        ;;
esac
