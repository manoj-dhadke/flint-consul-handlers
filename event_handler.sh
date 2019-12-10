#! /bin/bash

#
#  INFIVERVE TECHNOLOGIES PTE LIMITED CONFIDENTIAL
#  _______________________________________________
# 
#  (C) INFIVERVE TECHNOLOGIES PTE LIMITED, SINGAPORE
#  All Rights Reserved.
#  Product / Project: Flint IT Automation Platform
#  NOTICE:  All information contained herein is, and remains
#  the property of INFIVERVE TECHNOLOGIES PTE LIMITED.
#  The intellectual and technical concepts contained
#  herein are proprietary to INFIVERVE TECHNOLOGIES PTE LIMITED.
#  Dissemination of this information or any form of reproduction of this material
#  is strictly forbidden unless prior written permission is obtained
#  from INFIVERVE TECHNOLOGIES PTE LIMITED, SINGAPORE.


FLINT_HOSTNAME="flint-hostname"
FLINT_USERNAME="flint-username"
FLINT_PASSWORD="flint-password"
FLINTBIT="flintbit"
consul_HTTP_Protocol="http"
consul_Hostname="localhost"
consul_HTTP_Port="8500"
URL_agent_Self_Info="/v1/agent/self"
URL_get_Leader="/v1/status/leader"
URL_trigger_flintbit="/v1/bit/run/"
URL_get_key_value_store="/v1/kv/?recurse"
agent_Hostname="agent-hostname"
leader_Address="leader-address"
HEADER_content_type="Content-Type: application/json"
HEADER_cache_control="Cache-Control: no-cache"


#To validate flint configuration parameters like hostname,username,password and flintbit-name
ValidateFlintConfigParam() {
  echo "validating flint hostname..."
  if [ ! -z $FLINT_HOSTNAME ]; then
     echo "validating flint username..."
     if [ ! -z $FLINT_USERNAME ]; then
         echo "validating flint password..."
         if [ ! -z $FLINT_PASSWORD ]; then
            echo "validating flint flintbit name..."
            if [ ! -z $FLINTBIT ]; then
              echo "flint configuration parameters are valid!!"
              echo "flint-username: $FLINT_USERNAME,flint-password: $FLINT_PASSWORD,flint-hostname: $FLINT_HOSTNAME,flintbit-name: $FLINTBIT"
              return 0
            else
              echo "Error: flint flintbit name not found!!"
              return 1
            fi;
         else
           echo "Error: flint password not found!!"
           return 1
         fi;
    else
      echo "Error: flint username not found!!"
      return 1
    fi;
  else
    echo "Error: flint hostname not found!!"
    return 1
  fi;
}

GetFlintConfigParam(){
  FLINT_HOSTNAME=`echo "$1" | jq '.[] | select(.Key=="flint/hostname")' | jq '.Value' | tr -d '"' | base64 -d`
  FLINT_USERNAME=`echo "$1" | jq '.[] | select(.Key=="flint/username")' | jq '.Value' | tr -d '"' | base64 -d`
  FLINT_PASSWORD=`echo "$1" | jq '.[] | select(.Key=="flint/password")' | jq '.Value' | tr -d '"' | base64 -d`
  FLINTBIT=`echo "$1" | jq '.[] | select(.Key=="flint/events/'$2'")' | jq '.Value' | tr -d '"' | base64 -d`
}

#To retrieve the agent hostname
GetAgentHostname(){
  url="$consul_HTTP_Protocol""://""$consul_Hostname"":""$consul_HTTP_Port""$URL_agent_Self_Info"
  agent_Hostname=`curl -sS -X GET -H "$HEADER_cache_control" "$url" | jq '.Config.AdvertiseAddr' |  tr -d '"'`
  if [ $? -eq 0 ]; then
     if [ ! -z $agent_Hostname ]; then
         echo "agent hostname: $agent_Hostname"
     else
         echo "Error: Unable to retrieve agent hostname"
         exit 1
     fi;
  else
    echo "Error: Unable to retrieve agent information"
    exit 1
  fi;
}

#To retrieve the leader hostname
GetLeaderHostname(){
  url="$consul_HTTP_Protocol""://""$consul_Hostname"":""$consul_HTTP_Port""$URL_get_Leader"
  leader_Address=`curl -sS -X GET -H "$HEADER_cache_control" "$url" | tr -d '"' | cut -d':' -f1`
  if [ $? -eq 0 ]; then
    if [ ! -z $leader_Address ]; then
       echo "leader hostname: $leader_Address"
    else
      echo "Error: Unable to retrieve leader hostname"
      exit 1
    fi;
  else
    echo "Error: Unable to retrieve leader information"
    exit 1
  fi;
}

#To check whether the agent is leader of the cluster
IsLeader(){
  if [ "$agent_Hostname" = "$leader_Address" ]; then
    return 0
  fi;
return 1
}


event_info=`cat $STDIN`
event_info_array_length=`echo "$event_info" | jq 'length'`
if [ $event_info_array_length -eq 0 ]; then
   echo "Error: event information not found!!"
else
  if [ $event_info_array_length -eq 1 ];then
    echo "event occured..."
    eventName=`echo "$event_info" | jq '.[].Name' | tr -d '"'`
    echo "event triggered: $eventName"
    eventDetails=`echo $event_info | jq '.'`
    echo "event details: $eventDetails"
    url="$consul_HTTP_Protocol""://""$consul_Hostname"":""$consul_HTTP_Port""$URL_get_key_value_store"
    allKeysInfo=`curl -sS -X GET -H "$HEADER_cache_control" "$url"`
    if [ $? -eq 0 ]; then
     if [ ! -z $allKeysInfo ]; then
       GetFlintConfigParam $allKeysInfo $eventName
       ValidateFlintConfigParam
       if [ $? -eq 0 ]; then
         #statements
         GetAgentHostname
         GetLeaderHostname
         echo "now, going to trigger flintbit..."
         IsLeader
         if [ $? -eq 0 ]; then
           #statements
           echo "triggering flintbit: $FLINTBIT"
           flint_URL="$FLINT_HOSTNAME""$URL_trigger_flintbit""$FLINTBIT""/sync"
           flintbitresponse=`curl -sS -X POST -H "x-flint-username:$FLINT_USERNAME" -H "x-flint-password:$FLINT_PASSWORD" -H "$HEADER_content_type" -H "$HEADER_cache_control" -d '{"my_message":"Flint"}' "$flint_URL"`
           echo "flint response: `echo $flintbitresponse | jq '.'`"
        else
          echo "Error: Access denied!! agent: $agent_Hostname is not a leader."
        fi;
       else
         echo "Error: flint configuration parameters are invalid!!"
         exit 1
       fi
    else
         echo "Error: Unable to retrieve key-value store"
         exit 1
     fi;
  else
    echo "Error: Unable to retrieve key-value store"
    exit 1
  fi;
  else
    echo "waiting for event to take place.."
  fi;
fi;
