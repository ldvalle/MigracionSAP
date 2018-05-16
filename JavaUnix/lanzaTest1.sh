#! /bin/sh
#JAVA_HOME=/usr/java6/bin
JAVA_HOME=/usr/java6/jre/bin/
export JAVA_HOME

CLASSPATH=/home/ldvalle/locks/java/pba1
export CLASSPATH

$JAVA_HOME/java -cp $CLASSPATH edesur.Test1 "$@"
