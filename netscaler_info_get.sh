#!/bin/bash
#check for arguments

if [ $# -eq 0 ]; then
    echo "No arguments provided"
    echo "Here's an example: ./netscaler_jenkins_vars.sh -e prod -v site.example.com"
    exit 1
fi

while getopts :e:v: option
do
    case "$option" in
    e)
         NSENV=$OPTARG
         ;;
    v)
         NSVIP=$OPTARG
         ;;
    *)
        echo "An invalid option was received. -e and -v require an argument."
        echo "Here's an example: ./netscaler_jenkins_vars.sh -e prod -v site.example.com"
        exit 1
        ;;
        esac
done

#set initial params for login
NITRO_USER="readonly"
NITRO_PASS="readonly"
if [ "$NSENV" == "prod" ]
then
  NITRO_URL="http://prod.loadbalancer.com"
else
  NITRO_URL="http://dev.loadbalancer.com"
fi

#get the actual VIP by searching
LBSERVERNAME=$(curl -sS -H "Content-Type:application/vnd.com.citrix.netscaler.nsconfig+json" \
-H "X-NITRO-USER:$NITRO_USER" \
-H "X-NITRO-PASS:$NITRO_PASS" \
"$NITRO_URL/nitro/v1/config/lbvserver?filter=name:%2F$NSVIP%2F" | jq .lbvserver[].name | cut -d '"' -f2)

#get the services bound to the vip(s) found above
for LBSERVER in $LBSERVERNAME
do
  SERVICENAMES=$(curl -sS -H "Content-Type:application/vnd.com.citrix.netscaler.nsconfig+json" \
  -H "X-NITRO-USER:$NITRO_USER" \
  -H "X-NITRO-PASS:$NITRO_PASS" \
  "$NITRO_URL/nitro/v1/config/lbvserver_binding/$LBSERVER" | jq -r .lbvserver_binding[].lbvserver_service_binding[].servicename)
  for SERVICE in $SERVICENAMES
  do
    SERVICESTATUS=$(curl -sS -H "Content-Type:application/vnd.com.citrix.netscaler.nsconfig+json" \
    -H "X-NITRO-USER:$NITRO_USER" \
    -H "X-NITRO-PASS:$NITRO_PASS" \
    "$NITRO_URL/nitro/v1/config/service/$SERVICE" | jq -r .service[].svrstate)
    SERVERNAME=$(curl -sS -H "Content-Type:application/vnd.com.citrix.netscaler.nsconfig+json" \
    -H "X-NITRO-USER:$NITRO_USER" \
    -H "X-NITRO-PASS:$NITRO_PASS" \
    "$NITRO_URL/nitro/v1/config/service/$SERVICE" | jq -r .service[].servername)
    echo ""
    echo "$SERVICE" is "$SERVICESTATUS on $SERVERNAME for $LBSERVER"
  done
done
