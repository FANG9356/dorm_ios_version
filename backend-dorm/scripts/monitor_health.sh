#!/bin/bash

# DormiNetX - Health Monitoring & Alerting Script
# สามารถใส่ไว้ใน cronjob เช่น `* * * * * /opt/dormitory/scripts/monitor_health.sh`

HEALTH_URL="https://dorminet.studio/api/system/ping"
LOG_FILE="/var/log/dorminet_monitor.log"

check_health() {
    response=$(curl --write-out "%{http_code}" --silent --output /dev/null "$HEALTH_URL")
    
    if [ "$response" -eq 200 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - HEALTHY - HTTP $response" >> "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - UNHEALTHY - HTTP $response" >> "$LOG_FILE"
        # หากมี LINE Notify สามารถนำ Token มาใส่ในตัวแปร LINE_NOTIFY_TOKEN 
        # curl -X POST -H "Authorization: Bearer $LINE_NOTIFY_TOKEN" -F "message=⚠️ System Alert: DormiNetX is DOWN (HTTP $response)" https://notify-api.line.me/api/notify
    fi
}

check_health
