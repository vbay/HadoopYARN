#!/bin/bash
#
#Author:wangxiaolei
#date:2016-02-29
#environment:aliyun Elastic Compute Service
#power by:Apache Hadoop YARN moving beyond mapreduce and batch processing with apache hadoop 2
# Install Hadoop 2 using pdsh/pdcp where possible.
#
# Command can be interactive or file-based.  This script sets up
# a Hadoop 2 cluster with basic configuration.  Modify data, log, and pid
# directories as desired.  Further configure your cluster with ./conf-hadoop2.sh
# after running this installation script.
#

# Basic environment variables.  Edit as necessary
HADOOP_VERSION=2.7.1
HADOOP_HOME="/opt/hadoop-${HADOOP_VERSION}"
NN_DATA_DIR=/var/data/hadoop/hdfs/nn
SNN_DATA_DIR=/var/data/hadoop/hdfs/snn
DN_DATA_DIR=/var/data/hadoop/hdfs/dn
YARN_LOG_DIR=/var/log/hadoop/yarn
HADOOP_LOG_DIR=/var/log/hadoop/hdfs
HADOOP_MAPRED_LOG_DIR=/var/log/hadoop/mapred
YARN_PID_DIR=/var/run/hadoop/yarn
HADOOP_PID_DIR=/var/run/hadoop/hdfs
HADOOP_MAPRED_PID_DIR=/var/run/hadoop/mapred
HTTP_STATIC_USER=hdfs
YARN_PROXY_PORT=8081
AVA_HOME=/opt/jdk1.8.0_72

source hadoop-xml-conf.sh
CMD_OPTIONS=$(getopt -n "$0"  -o hif --long "help,interactive,file"  -- "$@")

# Take care of bad options in the command
if [ $? -ne 0 ];
then
  exit 1
fi
eval set -- "$CMD_OPTIONS"

all_hosts="all_hosts"
nn_host="nn_host"
snn_host="snn_host"
dn_hosts="dn_hosts"
rm_host="rm_host"
nm_hosts="nm_hosts"
mr_history_host="mr_history_host"
yarn_proxy_host="yarn_proxy_host"



install()
{


	#1.将本机Hadoop和jdk复制到目标机器
	#echo "1 of 16...Copying Hadoop $HADOOP_VERSION to all host..."
	#pdcp -w ^all_hosts /opt/hadoop-"$HADOOP_VERSION".tar.gz /opt

	#echo "Copying JDK to all hosts..."
	#pdcp -w ^all_hosts /opt/jdk-8u72-linux-x64.tar.gz /opt
	#解压Hadoop和jdk
	echo "1.3 of 2...Extracting JDK distribution on all hosts..."
	pdsh -w ^all_hosts tar -zxf/opt/jdk-8u72-linux-x64.tar.gz -C /opt

	echo "1.4 of 2...Extracting Hadoop $HADOOP_VERSION distribution on all hosts..."
	pdsh -w ^all_hosts tar -zxf /opt/hadoop-"$HADOOP_VERSION".tar.gz -C /opt

	#2.配置Hadoop和jdk环境变量
	echo "2 of 16...Setting JAVA_HOME and HADOOP_HOME environment variabales on all hosts..."
	pdsh -w ^all_hosts 'echo export JAVA_HOME=/opt/jdk1.8.0_72 > /etc/profile.d/java.sh'
	pdsh -w ^all_hosts 'echo export JRE_HOME=/opt/jdk1.8.0_72/jre >> /etc/profile.d/java.sh'
	pdsh -w ^all_hosts 'echo export CLASSPATH=.:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar:\$JRE_HOME/lib:\$CLASSPATH >> /etc/profile.d/java.sh'
	pdsh -w ^all_hosts 'echo export PATH=\$JAVA_HOME/bin:\$PATH >> /etc/profile.d/java.sh'
	pdsh -w ^all_hosts "source /etc/profile.d/java.sh"

	pdsh -w ^all_hosts "echo export HADOOP_HOME=$HADOOP_HOME > /etc/profile.d/hadoop.sh"
	pdsh -w ^all_hosts 'echo export HADOOP_PREFIX=\$HADOOP_HOME >> /etc/profile.d/hadoop.sh'
	pdsh -w ^all_hosts "source /etc/profile.d/hadoop.sh"
	#3.创建用户组合用户
	echo "3 of 16...Creating system accounts and groups on all hosts..."
	pdsh -w ^all_hosts groupadd hadoop
	pdsh -w ^all_hosts useradd -g hadoop yarn
	pdsh -w ^all_hosts useradd -g hadoop hdfs
	pdsh -w ^all_hosts useradd -g hadoop mapred
	#4.创建HDFS路径在NameNode、Secondary NameNode host、 DataNode hosts
	echo "4 of 16...Creating HDFS data directories on NameNode host, Secondary NameNode host, and DataNode hosts..."
	pdsh -w ^nn_host "mkdir -p $NN_DATA_DIR && chown hdfs:hadoop $NN_DATA_DIR"
	pdsh -w ^snn_host "mkdir -p $SNN_DATA_DIR && chown hdfs:hadoop $SNN_DATA_DIR"
	pdsh -w ^dn_hosts "mkdir -p $DN_DATA_DIR && chown hdfs:hadoop $DN_DATA_DIR"
	#5.在全部主机上创建日志文件
	echo "5 of 16...Creating log directories on all hosts..."
	pdsh -w ^all_hosts "mkdir -p $YARN_LOG_DIR && chown yarn:hadoop $YARN_LOG_DIR"
	pdsh -w ^all_hosts "mkdir -p $HADOOP_LOG_DIR && chown hdfs:hadoop $HADOOP_LOG_DIR"
	pdsh -w ^all_hosts "mkdir -p $HADOOP_MAPRED_LOG_DIR && chown mapred:hadoop $HADOOP_MAPRED_LOG_DIR"
	#6.在全部主机上创建pid文件
	echo "6 of 16...Creating pid directories on all hosts..."
	pdsh -w ^all_hosts "mkdir -p $YARN_PID_DIR && chown yarn:hadoop $YARN_PID_DIR"
	pdsh -w ^all_hosts "mkdir -p $HADOOP_PID_DIR && chown hdfs:hadoop $HADOOP_PID_DIR"
	pdsh -w ^all_hosts "mkdir -p $HADOOP_MAPRED_PID_DIR && chown mapred:hadoop $HADOOP_MAPRED_PID_DIR"
	#7.将log路径追加到Hadoop 环境文件中
	echo "7 of 16...Editing Hadoop environment scripts for log directories on all hosts..."
	pdsh -w ^all_hosts echo "export HADOOP_LOG_DIR=$HADOOP_LOG_DIR >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh"
	pdsh -w ^all_hosts echo "export YARN_LOG_DIR=$YARN_LOG_DIR >> $HADOOP_HOME/etc/hadoop/yarn-env.sh"
	pdsh -w ^all_hosts echo "export HADOOP_MAPRED_LOG_DIR=$HADOOP_MAPRED_LOG_DIR >> $HADOOP_HOME/etc/hadoop/mapred-env.sh"
	#8.将pid路径追加到Hadoop环境文件中
	echo "8 of 16...Editing Hadoop environment scripts for pid directories on all hosts..."
	pdsh -w ^all_hosts echo "export HADOOP_PID_DIR=$HADOOP_PID_DIR >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh"
	pdsh -w ^all_hosts echo "export YARN_PID_DIR=$YARN_PID_DIR >> $HADOOP_HOME/etc/hadoop/yarn-env.sh"
	pdsh -w ^all_hosts echo "export HADOOP_MAPRED_PID_DIR=$HADOOP_MAPRED_PID_DIR >> $HADOOP_HOME/etc/hadoop/mapred-env.sh"
	#9.创建HadoopXML配置文件，此时由hadoop-xml-conf.sh生成XML文件
	echo "9 of 16...Creating base Hadoop XML config files..."
	echo "Creating base Hadoop XML config files..."
	create_config --file core-site.xml
	put_config --file core-site.xml --property fs.default.name --value "hdfs://$nn:9000"
	put_config --file core-site.xml --property hadoop.http.staticuser.user --value "$HTTP_STATIC_USER"

	create_config --file hdfs-site.xml
	put_config --file hdfs-site.xml --property dfs.namenode.name.dir --value "$NN_DATA_DIR"
	put_config --file hdfs-site.xml --property fs.checkpoint.dir --value "$SNN_DATA_DIR"
	put_config --file hdfs-site.xml --property fs.checkpoint.edits.dir --value "$SNN_DATA_DIR"
	put_config --file hdfs-site.xml --property dfs.datanode.data.dir --value "$DN_DATA_DIR"
	put_config --file hdfs-site.xml --property dfs.namenode.http-address --value "$nn:50070"
	put_config --file hdfs-site.xml --property dfs.namenode.secondary.http-address --value "$snn:50090"

	create_config --file mapred-site.xml
	put_config --file mapred-site.xml --property mapreduce.framework.name --value yarn
	put_config --file mapred-site.xml --property mapreduce.jobhistory.address --value "$mr_hist:10020"
	put_config --file mapred-site.xml --property mapreduce.jobhistory.webapp.address --value "$mr_hist:19888"
	put_config --file mapred-site.xml --property yarn.app.mapreduce.am.staging-dir --value /mapred

	create_config --file yarn-site.xml
	put_config --file yarn-site.xml --property yarn.nodemanager.aux-services --value mapreduce_shuffle
	put_config --file yarn-site.xml --property yarn.nodemanager.aux-services.mapreduce.shuffle.class --value org.apache.hadoop.mapred.ShuffleHandler
	put_config --file yarn-site.xml --property yarn.web-proxy.address --value "$yarn_proxy:$YARN_PROXY_PORT"
	put_config --file yarn-site.xml --property yarn.resourcemanager.scheduler.address --value "$rmgr:8030"
	put_config --file yarn-site.xml --property yarn.resourcemanager.resource-tracker.address --value "$rmgr:8031"
	put_config --file yarn-site.xml --property yarn.resourcemanager.address --value "$rmgr:8032"
	put_config --file yarn-site.xml --property yarn.resourcemanager.admin.address --value "$rmgr:8033"
	put_config --file yarn-site.xml --property yarn.resourcemanager.webapp.address --value "$rmgr:8088"

	#10.复制基本的HadoopXML配置文件到全部机器
	echo "10 of 16...Copying base Hadoop XML config files and slaves to all hosts..."
	pdcp -w ^all_hosts core-site.xml hdfs-site.xml mapred-site.xml yarn-site.xml slaves $HADOOP_HOME/etc/hadoop/
	#11.创建连接,添加了f，可以删除原有文件重新建立
	echo "11 of 16...Creating configuration, command, and script links on all hosts..."
	pdsh -w ^all_hosts "ln -fs $HADOOP_HOME/etc/hadoop /etc/hadoop"
	pdsh -w ^all_hosts "ln -fs $HADOOP_HOME/bin/* /usr/bin"
	pdsh -w ^all_hosts "ln -fs $HADOOP_HOME/libexec/* /usr/libexec"
	#12.格式化NameNode（重要的一步）
	echo "12 of 16...Formatting the NameNode..."
	pdsh -w ^nn_host "su - hdfs -c '$HADOOP_HOME/bin/hdfs namenode -format'"
	#13.复制启动脚本到对应主机
	echo "13 of 16...Copying startup scripts to all hosts..."
	pdcp -w ^nn_host hadoop-namenode /etc/init.d/
	pdcp -w ^snn_host hadoop-secondarynamenode /etc/init.d/
	pdcp -w ^dn_hosts hadoop-datanode /etc/init.d/
	pdcp -w ^rm_host hadoop-resourcemanager /etc/init.d/
	pdcp -w ^nm_hosts hadoop-nodemanager /etc/init.d/
	pdcp -w ^mr_history_host hadoop-historyserver /etc/init.d/
	pdcp -w ^yarn_proxy_host hadoop-proxyserver /etc/init.d/
	#14.开启全部主机的Hadoop服务
	echo "14 of 16...Starting Hadoop $HADOOP_VERSION services on all hosts..."
	pdsh -w ^nn_host "chmod 755 /etc/init.d/hadoop-namenode && chkconfig hadoop-namenode on && service hadoop-namenode start"
	pdsh -w ^snn_host "chmod 755 /etc/init.d/hadoop-secondarynamenode && chkconfig hadoop-secondarynamenode on && service hadoop-secondarynamenode start"
	pdsh -w ^dn_hosts "chmod 755 /etc/init.d/hadoop-datanode && chkconfig hadoop-datanode on && service hadoop-datanode start"
	pdsh -w ^rm_host "chmod 755 /etc/init.d/hadoop-resourcemanager && chkconfig hadoop-resourcemanager on && service hadoop-resourcemanager start"
	pdsh -w ^nm_hosts "chmod 755 /etc/init.d/hadoop-nodemanager && chkconfig hadoop-nodemanager on && service hadoop-nodemanager start"

	pdsh -w ^yarn_proxy_host "chmod 755 /etc/init.d/hadoop-proxyserver && chkconfig hadoop-proxyserver on && service hadoop-proxyserver start"
	#15.在本机上创建mapreduce作业历史文件
	echo "15 of 16...Creating MapReduce Job History directories..."
	su - hdfs -c "hadoop fs -mkdir -p /mapred/history/done_intermediate"
	su - hdfs -c "hadoop fs -chown -R mapred:hadoop /mapred"
	su - hdfs -c "hadoop fs -chmod -R g+rwx /mapred"

	pdsh -w ^mr_history_host "chmod 755 /etc/init.d/hadoop-historyserver && chkconfig hadoop-historyserver on && service hadoop-historyserver start"
	#16.开始跑测试例子
	echo "16 of 16...Running YARN smoke test..."
	pdsh -w ^all_hosts "usermod -a -G hadoop $(whoami)"
	su - hdfs -c "hadoop fs -mkdir -p /user/$(whoami)"
	su - hdfs -c "hadoop fs -chown $(whoami):$(whoami) /user/$(whoami)"
	source /etc/profile.d/java.sh
	source /etc/profile.d/hadoop.sh
	source /etc/hadoop/hadoop-env.sh
	source /etc/hadoop/yarn-env.sh
	echo "17...open pi eg..."

	hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-$HADOOP_VERSION.jar pi -Dmapreduce.clientfactory.class.name=org.apache.hadoop.mapred.YarnClientFactory -libjars $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-$HADOOP_VERSION.jar 4 100
}

interactive()
{
	echo -n "Enter NameNode hostname: "
	read nn
	echo -n "Enter Secondary NameNode hostname: "
	read snn
	echo -n "Enter ResourceManager hostname: "
	read rmgr
	echo -n "Enter Job History Server hostname: "
	read mr_hist
	echo -n "Enter YARN Proxy hostname: "
	read yarn_proxy
	echo -n "Enter DataNode hostnames (comma separated or hostlist syntax): "
	read dns
	echo -n "Enter NodeManager hostnames (comma separated or hostlist syntax): "
	read nms

	echo "$nn" > "$nn_host"
	echo "$snn" > "$snn_host"
	echo "$rmgr" > "$rm_host"
	echo "$mr_hist" > "$mr_history_host"
	echo "$yarn_proxy" > "$yarn_proxy_host"
	dn_hosts_var=$(sed 's/\,/\n/g' <<< $dns)
	nm_hosts_var=$(sed 's/\,/\n/g' <<< $nms)
	echo "$dn_hosts_var" > "$dn_hosts"
	echo "$nm_hosts_var" > "$nm_hosts"
	echo "$(echo "$nn $snn $rmgr $mr_hist $yarn_proxy $dn_hosts_var $nm_hosts_var" | tr ' ' '\n' | sort -u)" > "$all_hosts"
}

file()
{
	nn=$(cat nn_host)
	snn=$(cat snn_host)
	rmgr=$(cat rm_host)
	mr_hist=$(cat mr_history_host)
	yarn_proxy=$(cat yarn_proxy_host)
	dns=$(cat dn_hosts)
	nms=$(cat nm_hosts)

	echo "$(echo "$nn $snn $rmgr $mr_hist $dns $nms" | tr ' ' '\n' | sort -u)" > "$all_hosts"
}

help()
{
cat << EOF
install-hadoop2.sh

This script installs Hadoop 2 with basic data, log, and pid directories.

USAGE:  install-hadoop2.sh [options]

OPTIONS:
   -i, --interactive      Prompt for fully qualified domain names (FQDN) of the NameNode,
                          Secondary NameNode, DataNodes, ResourceManager, NodeManagers,
                          MapReduce Job History Server, and YARN Proxy server.  Values
                          entered are stored in files in the same directory as this command.

   -f, --file             Use files with fully qualified domain names (FQDN), new-line
                          separated.  Place files in the same directory as this script.
                          Services and file name are as follows:
                          NameNode = nn_host
                          Secondary NameNode = snn_host
                          DataNodes = dn_hosts
                          ResourceManager = rm_host
                          NodeManagers = nm_hosts
                          MapReduce Job History Server = mr_history_host
                          YARN Proxy Server = yarn_proxy_host

   -h, --help             Show this message.

EXAMPLES:
   Prompt for host names:
     install-hadoop2.sh -i
     install-hadoop2.sh --interactive

   Use values from files in the same directory:
     install-hadoop2.sh -f
     install-hadoop2.sh --file

EOF
}

while true;
do
  case "$1" in

    -h|--help)
      help
      exit 0
      ;;
    -i|--interactive)
      interactive
      install
      shift
      ;;
    -f|--file)
      file
      install
      shift
      ;;
    --)
      shift
      break
      ;;
  esac
done
