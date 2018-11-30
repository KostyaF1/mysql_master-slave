#!/bin/bash
BASE_PATH=$(dirname $0)

echo "Waiting 1 min. for mysql"
sleep 60

echo -e "******************************************\n
******************************************\n
******************************************"
echo "Create MySQL Servers (master - slave repl)"
echo -e "******************************************\n
******************************************\n
******************************************"

echo "***********************\n
Create replication user\n
***********************"

mysql --host mysqlslave -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e 'STOP SLAVE;';
mysql --host mysqlslave -uroot -p$MYSQL_MASTER_PASSWORD -AN -e 'RESET SLAVE ALL;';

mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "CREATE USER '$MYSQL_REPLICATION_USER'@'%';"
mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_REPLICATION_USER'@'%' IDENTIFIED BY '$MYSQL_REPLICATION_PASSWORD';"
mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -AN -e 'flush privileges;'

mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "CREATE DATABASE test DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"

mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "USE testbase;"
mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "FLUSH TABLES WITH READ LOCK;"

echo "Master STATUS"

mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "SHOW MASTER STATUS;"

echo "MYSQL dump"

mysqldump --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD testbase > test_dump.sql

mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "UNLOCK TABLES;"


echo "Slave here"

mysql --host mysqlslave -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e "CREATE DATABASE test;"

echo "Loading mysql dump"

mysql --host mysqlslave -uroot -p$MYSQL_SLAVE_PASSWORD test  < test_dump.sql

echo "Write Position and bin file for master"

MYSQL01_Position=$(eval "mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -e 'show master status \G' | grep Position | sed -n -e 's/^.*: //p'")
MYSQL01_File=$(eval "mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -e 'show master status \G'     | grep File     | sed -n -e 's/^.*: //p'")
MASTER_IP=$(eval "getent hosts mysqlmaster|awk '{print \$1}'")
echo $MASTER_IP

mysql --host mysqlslave -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e "CHANGE MASTER TO master_host='mysqlmaster', master_port=3306, \
        master_user='$MYSQL_REPLICATION_USER', master_password='$MYSQL_REPLICATION_PASSWORD', master_log_file='$MYSQL01_File', \
        master_log_pos=$MYSQL01_Position;"

echo "Write Position and bin file for master"

MYSQL02_Position=$(eval "mysql --host mysqlslave -uroot -p$MYSQL_SLAVE_PASSWORD -e 'show master status \G' | grep Position | sed -n -e 's/^.*: //p'")
MYSQL02_File=$(eval "mysql --host mysqlslave -uroot -p$MYSQL_SLAVE_PASSWORD -e 'show master status \G'     | grep File     | sed -n -e 's/^.*: //p'")
SLAVE_IP=$(eval "getent hosts mysqlslave|awk '{print \$1}'")
echo $SLAVE_IP
mysql --host mysqlmaster -uroot -p$MYSQL_MASTER_PASSWORD -AN -e "CHANGE MASTER TO master_host='mysqlslave', master_port=3306, \
        master_user='$MYSQL_REPLICATION_USER', master_password='$MYSQL_REPLICATION_PASSWORD', master_log_file='$MYSQL02_File', \
        master_log_pos=$MYSQL02_Position;"

mysql --host mysqlslave -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e "START SLAVE;"

mysql --host mysqlslave -uroot -p$MYSQL_SLAVE_PASSWORD -AN -e "SHOW SLAVE STATUS\G"
