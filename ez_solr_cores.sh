#!/bin/bash

# v.0.1 24 ott 2013

# Utilite' per aggiungere/togliere cores da una installazione solr multicore
#
# ATENZIONE: lo script prevede che 
#
# * il nome dell'installazione multicore sia "multicore-XXXX" dove XXXX e' il numero della porta
# * lo script di start/stop di solr sia /etc/init.s/solr-multicore-XXXX e sia riavviabile con "service solr.multicore-XXXX restart"
# * /home/solr/multicore-8984/java contenga una copia della directory extension/ezfind/java di ezfind
#
#SOLR_MULTICORES_NAMES="multicore-8984 multicore-8985"
#SOLR_MULTICORES_NAMES="multicore-8984"
# impostare SOLR_MULTICORES_ROOT_DIR pari alla directory che contiene le installazioni multicore:
SOLR_MULTICORES_ROOT_DIR=/home/solr


# directory where pid for daemon are stored
PID_DIR=/var/run
# attivare per debug
DEBUG=0

########## DO NOT CHANGE THE REST ################################################

#
SOLR_MULTICORES_NAMES=`ls -1 $SOLR_MULTICORES_ROOT_DIR | grep -e ^multicore- | grep -e [0-9][0-9][0-9][0-9]$`
SOLR_SERVER_NAME=`hostname -f`


THIS_SCRIPT=`basename $0`
THIS_SCRIPT_FULL_NAME=`dirname $0`/$THIS_SCRIPT

# getops see /usr/share/doc/util-linux/examples/getopt-parse.bash
TEMP=`getopt -o hvlsa:r: --long help,verbose,list,status,add:,remove: \
     -n "$THIS_SCRIPT" -- "$@"`

if [ $? != 0 ] ; then
  echo "try '$THIS_SCRIPT --help' for datailed options"
  echo "Terminating..." >&2
  exit 1
fi
eval set -- "$TEMP"
while true ; do
    case "$1" in
        -h|--help)
                echo
                echo "Usage: $THIS_SCRIPT OPTIONS"
                echo
                echo "Utility for  adding/removing solr cores"
                echo
                echo "Options:"
                echo "-h,--help                       "
                echo "-a,--add CORENAME               add core"
                echo "-r,--remove CORENAME            remove core"
                echo "-v,--verbose...                 display more information"
                #echo "-d,--debug...                  display debug output at end of execution"
                echo "-l,--list                       list all cores (default options)"
                echo "-s,--status                     running status of all cores"
                echo 
                exit;;
        -v|--verbose)
            VERBOSE=1
            shift ;;
        -l|--list)
            action="list"
            shift ;;
        -s|--status)
            action="status"
            shift ;;
        -a|--add)
            action="add"
            CORE_NAME="$2"
            shift 2 ;;
        -r|--remove)
            action="remove"
            CORE_NAME="$2"
            shift 2 ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

# il seguente necessario per ottenere $arg 
for arg do variabile_inutile=1 ; done

if [ $DEBUG -eq 1 ] ; then 
 echo "Remaining arguments:"
 for arg do echo '--> '"\`$arg'" ; done
fi

if [ $arg ] ; then
  echo "ERROR: no argoment should be entered, see $THIS_SCRIPT --help"
  exit 1
fi

# choosing the multicore
cores_number=0
for solr_multicore_name in $SOLR_MULTICORES_NAMES ; do
  cores_number=$[ $cores_number + 1 ]
done

if [ $cores_number -eq 0 ] ; then
  echo "ERRORE: there are not any valid multicore in $SOLR_MULTICORES_ROOT_DIR"
  exit 1
fi

if [ $action ] && ( [ $action = "add" ] || [ $action = "remove" ] ) ; then 
  if [ $cores_number -eq 1 ] ; then
    SOLR_MULTICORES_NAME=$SOLR_MULTICORES_NAMES
  else
    echo
    echo "Multicore disponibili:"
    counter=0
    echo
    echo "  Selection     Path"
    echo "------------------------------------------------------------"
    for solr_multicore_name in $SOLR_MULTICORES_NAMES ; do
      counter=$[ $counter + 1 ]
      solr_multicore_dir=$SOLR_MULTICORES_ROOT_DIR/$solr_multicore_name
      echo "  $counter             $solr_multicore_dir"
    done
    echo
    echo -n "Scegli il numero del multicore: "
    read choice
    
    counter=0
    for solr_multicore_name in $SOLR_MULTICORES_NAMES ; do
      counter=$[ $counter + 1 ]
      if [ "$choice" -eq $counter ] ; then
        SOLR_MULTICORES_NAME=$solr_multicore_name
      fi
    done
  fi
fi 

# il seguente e' da sistemare
#if [ -z $SOLR_MULTICORES_NAME ] ; then
#  # if we are here user has inserted a number not referred to any multicore
#  echo "ERRORE: invalid multicore"
#  exit 1
#fi

SOLR_MULTICORES_DIR=$SOLR_MULTICORES_ROOT_DIR/$SOLR_MULTICORES_NAME # /home/solr/multicore
# ricavo porta
# ${string:position:length}
# ${#var} = lunghezza della variabiel var
SOLR_MULTICORES_PORT=${SOLR_MULTICORES_DIR:$(( ${#SOLR_MULTICORES_DIR}-4 ))}
# ricavo il nome del servizio
SOLR_MULTICORES_INIT_SCRIPT=solr-$SOLR_MULTICORES_NAME
# data in formato: 2013_10_24_h09_46_43
DATE=`date +%Y_%m_%d_h%H_%M_%S`

case $action in
  add)
    if ! [ -f "$SOLR_MULTICORES_DIR/java/solr/conf/schema.xml" ] ; then
      echo "ERRORE: $SOLR_MULTICORES_DIR/java/solr/conf/schema.xml mancante:  in $SOLR_MULTICORES_DIR/java/ e' necessario avere una copia di extension/ezfind/java/"
      [ $VERBOSE ] && echo "Creala con il comando:  cp -a extension/ezfind/java $SOLR_MULTICORES_DIR/java"
      exit 1
    fi
    # creo directory: se da' errore il core esiste gia
    if [ -d "$SOLR_MULTICORES_DIR/cores/$CORE_NAME" ] ; then
      echo "ERRORE: core '$CORE_NAME' gia' esistente"
      exit 1
    fi


    mkdir $SOLR_MULTICORES_DIR/cores/$CORE_NAME

    mkdir -p $SOLR_MULTICORES_DIR/cores/$CORE_NAME/data
    # creo /conf a partire da un template
    mkdir $SOLR_MULTICORES_DIR/cores/$CORE_NAME/conf
    cp -a $SOLR_MULTICORES_DIR/java/solr/conf/*  $SOLR_MULTICORES_DIR/cores/$CORE_NAME/conf/
    # modifico dataDir
    sed -i "s/solr.data.dir:.\/solr\/data/solr.data.dir:..\/cores\/$CORE_NAME\/data/" $SOLR_MULTICORES_DIR/cores/$CORE_NAME/conf/solrconfig.xml
    
    # modifico solr.xml
    cp -a $SOLR_MULTICORES_DIR/cores/solr.xml $SOLR_MULTICORES_DIR/cores/solr.xml.copia_ante_aggiunta_core_del_$DATE
    sed -i "s/<\/cores>/     <core name=\"$CORE_NAME\" instanceDir=\"$CORE_NAME\" \/>\n    <\/cores>/" $SOLR_MULTICORES_DIR/cores/solr.xml
    echo
    echo "OK, il core '$CORE_NAME' e' stato CREATO in: $SOLR_MULTICORES_DIR/cores/$CORE_NAME"
    echo 
    echo "*******************************************"
    echo
    echo "* Modifica ora extension/ezfind/settings/solr.ini inserendo:"
    echo "      [SolrBase]"
    echo "      SearchServerURI=http://$SOLR_SERVER_NAME:$SOLR_MULTICORES_PORT/solr/$CORE_NAME"
    echo "    oppure, se il solr e' in localhost:"
    echo "      SearchServerURI=http://localhost:$SOLR_MULTICORES_PORT/solr/$CORE_NAME"
    echo
    echo "Se vuoi migrare i dati esistenti, copia il contenuto di" 
    echo "  extension/ezfind/java/solr/data/ "
    echo "nella directory:"
    echo "  $SOLR_MULTICORES_DIR/cores/$CORE_NAME/data"
    echo 
    echo "* archivia la vecchia directory java eseguendo:"
    echo "    tar -czvf extension/ezfind/old_java.tar.gz extension/ezfind/java"
    echo "    rm -rf extension/ezfind/java"
    echo
    echo "Ricordati di riavviare solr eseguendo: "
    echo "  service $SOLR_MULTICORES_INIT_SCRIPT restart"
    echo
    ;; 
  remove) 
    if ! [ -d "$SOLR_MULTICORES_DIR/cores/$CORE_NAME"  ] ; then
      echo "ERRORE: il core '$CORE_NAME' non esiste"
      exit 1
    fi
    trash_dir=$SOLR_MULTICORES_DIR/cores/cestino/$DATE/
    echo "Elimino directory con data e configurazione (messe in cestino: $trash_dir)"
    mkdir -p $trash_dir
    mv -f $SOLR_MULTICORES_DIR/cores/$CORE_NAME $trash_dir 
    # modifico solr.xml
    solr_xml_trash_folder=$SOLR_MULTICORES_DIR/cores/cestino/old_solr.xml
    mkdir -p $solr_xml_trash_folder
    nomefile_backup=$solr_xml_trash_folder/solr.xml.copia_ante_aggiunta_core_del_$DATE
    echo "Elimino il core dal file  $SOLR_MULTICORES_DIR/cores/solr.xml (conservo copia in $nomefile_backup)"
    cp -a $SOLR_MULTICORES_DIR/cores/solr.xml $nomefile_backup
    sed -i "/instanceDir=\"$CORE_NAME\" \/>/d" $SOLR_MULTICORES_DIR/cores/solr.xml
    echo
    echo "OK, il core '$CORE_NAME' è stato RIMOSSO"
    echo
    echo "Ricordati di riavviare solr eseguendo: "
    echo "  service $SOLR_MULTICORES_INIT_SCRIPT restart"
    echo 
    ;;
  list)
    for solr_multicore_name in $SOLR_MULTICORES_NAMES ; do 
      solr_multicore_dir=$SOLR_MULTICORES_ROOT_DIR/$solr_multicore_name
      echo
      echo "* Multicore at $solr_multicore_dir"
      [ $VERBOSE ] && echo "Lucene Version  (cat $solr_multicore_dir/java/solr/conf/solrconfig.xml | grep '<luceneMatchVersion>')"
      [ $VERBOSE ] && cat $solr_multicore_dir/java/solr/conf/solrconfig.xml | grep '<luceneMatchVersion>'
      echo "Cores list:"
      [ $VERBOSE ] && echo "cat $solr_multicore_dir/cores/solr.xml | grep instanceDir )"
      cat $solr_multicore_dir/cores/solr.xml | grep instanceDir
      if [ $? -eq 1 ] ; then 
        echo "         none"
      fi
    done
    ;;
  status)
    for solr_multicore_name in $SOLR_MULTICORES_NAMES ; do
      solr_multicore_dir=$SOLR_MULTICORES_ROOT_DIR/$solr_multicore_name
      # get first core needed for testing its ping page
      CORE_NAMES=`cat $solr_multicore_dir/cores/solr.xml | grep "<core name="  | sed  's/[[:blank:]]*<core name=\"//g' |  sed  's/".*//g'`
      SOLR_MULTICORES_PORT=${solr_multicore_dir:$(( ${#solr_multicore_dir}-4 ))}
      SOLR_MULTICORES_INIT_SCRIPT=solr-$solr_multicore_name
      echo  "Status of solr multicore installation at $solr_multicore_dir: "
      if [ -f $PID_DIR/$SOLR_MULTICORES_INIT_SCRIPT.pid ] ; then
        echo "  Daemon: pid $PID_DIR/$SOLR_MULTICORES_INIT_SCRIPT.pid found (multicore daemon is running)"
      else
        echo "  Daemon: pid $PID_DIR/$SOLR_MULTICORES_INIT_SCRIPT.pid not found (multicore daemon is not running)"
      fi
      for core_name in $CORE_NAMES ; do
        echo "  core '$core_name':"
        ping_url="http://localhost:$SOLR_MULTICORES_PORT/solr/$core_name/admin/ping"
        wget  -qO - $ping_url | grep "<str name=\"status\">OK</str>" > /dev/null
        if [ $? -eq 0 ] ; then 
          echo "    Status OK at $ping_url (solr for core '$core_name' is running)"
        else
          echo "    ERR: status is NOT ok  (either $ping_url is unreachable or its content does not have OK status)"
        fi
      done
     done
    ;;
  *)
    # we arrive here in case the script is called with no options (and no arguments)
    $THIS_SCRIPT_FULL_NAME -h
    ;;
esac
