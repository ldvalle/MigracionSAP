#! /bin/sh
#JAVA_HOME=/usr/java6/bin
JAVA_HOME=/usr/java6/jre/bin/
export JAVA_HOME
          
CLASSPATH=/home/ldvalle/locks/java/pba2/bin
#CLASSPATH=${CLASSPATH}:/home/ldvalle/locks/java/pba2/bin/connectBD
#CLASSPATH=${CLASSPATH}:/home/ldvalle/locks/java/pba2/bin/connectionBDInformix
#CLASSPATH=${CLASSPATH}:/home/ldvalle/locks/java/pba2/bin/dao
#CLASSPATH=${CLASSPATH}:/home/ldvalle/locks/java/pba2/bin/entidades
#CLASSPATH=${CLASSPATH}:/home/ldvalle/locks/java/pba2/bin/servicios
CLASSPATH=${CLASSPATH}:/home/ldvalle/locks/java/pba2/lib/ifxjdbc.jar
export CLASSPATH

$JAVA_HOME/java -cp $CLASSPATH ppal.startMuestreo "$@"
