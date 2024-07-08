
#install filebeat
curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.14.1-darwin-x86_64.tar.gz
tar xzvf filebeat-8.14.1-darwin-x86_64.tar.gz

#configure filebeat
sudo chown -R $(whoami) ./filebeat.yml
sudo mkdir /usr/local/etc
sudo mkdir /usr/local/etc/filebeat
sudo mv ./filebeat.yml /usr/local/etc/filebeat/filebeat.yml
sudo chown -R $(whoami) /usr/local/etc/filebeat/filebeat.yml

#push logs to elasticsearch(background task)
nohup sudo ./filebeat-8.14.1-darwin-x86_64/filebeat -e -c /usr/local/etc/filebeat/filebeat.yml -d "*" -v

curl -XGET "http://${domain_name}/${index_name}/_search?q=*"