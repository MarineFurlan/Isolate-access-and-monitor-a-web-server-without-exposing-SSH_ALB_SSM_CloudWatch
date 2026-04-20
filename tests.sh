#!/bin/bash
# =============================================================================
# TEST SCRIPT — Isolate, Access and Monitor a Web Server Without Exposing SSH
# =============================================================================
# Usage : bash tests.sh
# Run from the root of the project after terraform apply
# =============================================================================

set -euo pipefail  # Exit on error, undefined variable, or pipe failure

# --- Colors for terminal output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Helpers ---
pass() { echo -e "${GREEN}  ✔ PASS${RESET} — $1"; }
fail() { echo -e "${RED}  ✘ FAIL${RESET} — $1"; }
info() { echo -e "${CYAN}  →${RESET} $1"; }
section() { echo -e "\n${BOLD}${BLUE}══════════════════════════════════════════${RESET}"; \
            echo -e "${BOLD}${BLUE}  $1${RESET}"; \
            echo -e "${BOLD}${BLUE}══════════════════════════════════════════${RESET}"; }
warn()    { echo -e "${YELLOW}  ⚠ WARN${RESET} — $1"; }

PASS_COUNT=0
FAIL_COUNT=0

assert_pass() { PASS_COUNT=$((PASS_COUNT + 1)); pass "$1"; }
assert_fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); fail "$1"; }

# =============================================================================
# 0. INITIALIZATION — Load variables from Terraform outputs
# =============================================================================
section "0 / INITIALIZATION"

info "Loading variables from Terraform outputs..."

ALB_DNS=$(terraform output -raw alb_dns 2>/dev/null)
SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn 2>/dev/null)
TARGET_GROUP_ARN=$(terraform output -raw target_group_arn 2>/dev/null)
ALARM_NAME="webApp-ALB-4xx-alarm"
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
ALB_ARN_SUFFIX=$(echo $ALB_ARN | sed 's|.*loadbalancer/||')
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*webApp*ec2*" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "")

echo ""
echo -e "  ALB DNS         : ${BOLD}$ALB_DNS${RESET}"
echo -e "  ALB ARN Suffix  : ${BOLD}$ALB_ARN_SUFFIX${RESET}"
echo -e "  SNS Topic ARN   : ${BOLD}$SNS_TOPIC_ARN${RESET}"
echo -e "  Target Group    : ${BOLD}$TARGET_GROUP_ARN${RESET}"
echo -e "  Alarm Name      : ${BOLD}$ALARM_NAME${RESET}"
echo ""

# Abort if critical variables are empty
if [[ -z "$ALB_DNS" || -z "$SNS_TOPIC_ARN" || -z "$TARGET_GROUP_ARN" ]]; then
  echo -e "${RED}ERROR : One or more Terraform outputs are missing.${RESET}"
  echo -e "Run ${BOLD}terraform apply${RESET} first, then retry."
  exit 1
fi

assert_pass "All Terraform outputs loaded successfully"

# =============================================================================
# 1. SNS SUBSCRIPTION STATUS
# =============================================================================
section "1 / SNS SUBSCRIPTION STATUS"

info "Checking SNS subscription status for topic..."

SUBSCRIPTION_STATUS=$(aws sns list-subscriptions-by-topic \
  --topic-arn $SNS_TOPIC_ARN \
  --query 'Subscriptions[0].SubscriptionArn' --output text)

echo "  Status : $SUBSCRIPTION_STATUS"

if [[ "$SUBSCRIPTION_STATUS" == "PendingConfirmation" ]]; then
  warn "Subscription is pending — check your inbox and click the confirmation link before continuing."
elif [[ "$SUBSCRIPTION_STATUS" == arn:* ]]; then
  assert_pass "SNS email subscription is confirmed"
else
  assert_fail "SNS subscription not found or in unexpected state : $SUBSCRIPTION_STATUS"
fi

# =============================================================================
# 2. WEB SERVER ACCESS VIA ALB
# =============================================================================
section "2 / WEB SERVER ACCESS VIA ALB"

info "Sending HTTP request to ALB : http://$ALB_DNS ..."

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://$ALB_DNS" || echo "000")
echo "  HTTP response code : $HTTP_CODE"

if [[ "$HTTP_CODE" == "200" ]]; then
  assert_pass "Web server is reachable via ALB (HTTP 200)"
else
  assert_fail "Expected HTTP 200, got $HTTP_CODE — ALB or instances may not be healthy"
fi

info "Checking target group health..."

HEALTH_STATES=$(aws elbv2 describe-target-health \
  --target-group-arn $TARGET_GROUP_ARN \
  --query 'TargetHealthDescriptions[*].{ID:Target.Id,State:TargetHealth.State}' \
  --output table)

echo "$HEALTH_STATES"

UNHEALTHY=$(aws elbv2 describe-target-health \
  --target-group-arn $TARGET_GROUP_ARN \
  --query 'TargetHealthDescriptions[?TargetHealth.State!=`healthy`].Target.Id' \
  --output text)

if [[ -z "$UNHEALTHY" ]]; then
  assert_pass "All instances are healthy in the target group"
else
  assert_fail "Unhealthy instances detected : $UNHEALTHY"
fi

# =============================================================================
# 3. SSM CONNECTIVITY
# =============================================================================
section "3 / SSM CONNECTIVITY"

info "Checking which instances are registered and online in SSM Fleet Manager..."

SSM_STATUS=$(aws ssm describe-instance-information \
  --query 'InstanceInformationList[*].{ID:InstanceId,Status:PingStatus,Platform:PlatformName}' \
  --output table)

echo "$SSM_STATUS"

OFFLINE=$(aws ssm describe-instance-information \
  --query 'InstanceInformationList[?PingStatus!=`Online`].InstanceId' \
  --output text)

ONLINE_COUNT=$(aws ssm describe-instance-information \
  --query 'length(InstanceInformationList[?PingStatus==`Online`])' \
  --output text)

if [[ "$ONLINE_COUNT" -ge 1 && -z "$OFFLINE" ]]; then
  assert_pass "All $ONLINE_COUNT instance(s) are Online in SSM"
else
  assert_fail "Some instances are not reachable via SSM. Offline : $OFFLINE"
fi

# =============================================================================
# 4. PORT 22 CLOSED
# =============================================================================
section "4 / PORT 22 (SSH) CLOSED"

info "Checking security group rules for port 22..."

if [[ -z "$SG_ID" || "$SG_ID" == "None" ]]; then
  warn "Could not auto-detect EC2 security group. Listing all security groups :"
  aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].{ID:GroupId,Name:GroupName}' \
    --output table
  warn "Set SG_ID manually at the top of this script if needed."
else
  echo "  Security Group : $SG_ID"

  PORT_22_RULES=$(aws ec2 describe-security-groups \
    --group-ids $SG_ID \
    --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]' \
    --output json)

  echo "  Port 22 inbound rules : $PORT_22_RULES"

  if [[ "$PORT_22_RULES" == "[]" ]]; then
    assert_pass "Port 22 is closed — no inbound SSH rule found"
  else
    assert_fail "Port 22 is OPEN — SSH rule detected : $PORT_22_RULES"
  fi
fi

# =============================================================================
# 5. CLOUDWATCH ALARM — 4XX SIMULATION
# =============================================================================
section "5 / CLOUDWATCH ALARM — 4XX ERROR SIMULATION"

info "Sending 90 parallel invalid requests to trigger the 4XX alarm..."
info "Target : http://$ALB_DNS/invalid-<random>"
echo ""

for round in 1 2 3; do
  info "Round $round/3 — launching 30 parallel requests..."
  for i in $(seq 1 30); do
    curl -s -o /dev/null "http://$ALB_DNS/invalid-$RANDOM" &
  done
  wait
  info "Round $round complete"
done

echo ""
info "Burst finished at $(date -u +%H:%M:%S) UTC"
info "Waiting 5 minutes for CloudWatch to aggregate metrics..."
echo ""

for i in $(seq 5 -1 1); do
  echo -ne "  Waiting : ${BOLD}${i} min${RESET} remaining...\r"
  sleep 60
done
echo ""

info "Checking CloudWatch metric datapoints..."

DATAPOINTS=$(aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_4XX_Count \
  --dimensions Name=LoadBalancer,Value=$ALB_ARN_SUFFIX \
  --start-time $(date -u --date='15 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Sum \
  --query 'Datapoints[*].{Time:Timestamp,Count:Sum}' \
  --output table)

echo "$DATAPOINTS"

DATAPOINT_COUNT=$(aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_4XX_Count \
  --dimensions Name=LoadBalancer,Value=$ALB_ARN_SUFFIX \
  --start-time $(date -u --date='15 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Sum \
  --query 'length(Datapoints)' \
  --output text)

if [[ "$DATAPOINT_COUNT" -ge 1 ]]; then
  assert_pass "4XX metric datapoints received by CloudWatch ($DATAPOINT_COUNT period(s) with data)"
else
  assert_fail "No 4XX datapoints found — requests may not have reached the instances"
fi

info "Checking CloudWatch alarm state..."

ALARM_RESULT=$(aws cloudwatch describe-alarms \
  --alarm-names $ALARM_NAME \
  --query 'MetricAlarms[0].{State:StateValue,Reason:StateReason}' \
  --output table)

echo "$ALARM_RESULT"

ALARM_STATE=$(aws cloudwatch describe-alarms \
  --alarm-names $ALARM_NAME \
  --query 'MetricAlarms[0].StateValue' \
  --output text)

if [[ "$ALARM_STATE" == "ALARM" ]]; then
  assert_pass "CloudWatch alarm is in ALARM state — threshold crossed"
elif [[ "$ALARM_STATE" == "OK" ]]; then
  warn "Alarm is OK — threshold not crossed in a single 60s window. Try increasing burst volume."
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  assert_fail "Alarm state is $ALARM_STATE — expected ALARM"
fi

# =============================================================================
# SUMMARY
# =============================================================================
section "TEST SUMMARY"

TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo -e "  Tests run    : ${BOLD}$TOTAL${RESET}"
echo -e "  ${GREEN}Passed       : $PASS_COUNT${RESET}"
echo -e "  ${RED}Failed       : $FAIL_COUNT${RESET}"
echo ""

if [[ "$FAIL_COUNT" -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}  ✔ All tests passed — lab validated successfully.${RESET}"
else
  echo -e "${YELLOW}${BOLD}  ⚠ $FAIL_COUNT test(s) failed — review the output above.${RESET}"
fi

echo ""
echo -e "${CYAN}  ℹ  Check your inbox for the SNS alert email triggered by the 4XX simulation.${RESET}"
echo -e "${CYAN}  ℹ  Run ${BOLD}terraform destroy${RESET}${CYAN} when done to avoid unnecessary costs.${RESET}"
echo ""
