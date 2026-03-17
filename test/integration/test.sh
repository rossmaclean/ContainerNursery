#!/bin/bash
set -euo pipefail

# This is a simple test intented to act as a regression test to ensure nothing is broken too badly when upgrading dependencies
# This test starts up CN and Nginx, waits for Nginx to stop after timeout, calls CN and verifies a loading page is shown, 
# calls it again and verifies the Nginx response is shown, wait for the timeout and verify Nginx was stopped again

echo "=== ContainerNursery Integration Test ==="
echo ""

cleanup() {
    echo "Cleaning up containers..."
    docker compose -f docker-compose-integration.yml down 2>/dev/null || true
}
trap cleanup EXIT

# Only build locally if not running in CI
if [ "${CI:-false}" != "true" ]; then
    echo "Installing dependencies..."
    npm ci

    echo "Building app..."
    npm run build

    echo "Building and starting Container Nursery and Nginx containers"
    docker compose -f docker-compose-integration.yml up --build -d
else
    echo "CI detected: skipping local build"
fi


echo "Waiting for services to initialize..."
sleep 5

echo "Check Nginx is running"
if [ "$(docker inspect -f '{{.State.Running}}' test-nginx)" = "false" ]; then
  echo "Nginx did not start"
  exit 1
fi

echo "Check Container Nursery is running"
if [ "$(docker inspect -f '{{.State.Running}}' container-nursery)" = "false" ]; then
  echo "Container Nursery did not start"
  exit 1
fi

echo "Sleeping for timeout period"
sleep 12

response=$(curl -s --header 'Host: test.example.com' http://localhost)
echo "Calling Nginx via ContainerNursery and verifying loading page is shown"
if diff -u <(echo "$response") test/integration/expected-cn-loading-response.html; then
  echo "Loading HTML matches!"
else
  echo "Loading HTML does not match"
  echo "Response:"
  echo "$response"
  exit 1
fi

sleep 1

response=$(curl -s --header 'Host: test.example.com' http://localhost)
echo "Calling Nginx via ContainerNursery and verifying correct Nginx response is shown"
if diff -u <(echo "$response") test/integration/expected-nginx-response.html; then
  echo "Nginx HTML matches!"
else
  echo "Nginx HTML does not match"
  echo "Response:"
  echo "$response"
  exit 1
fi

echo "Sleeping for timeout period"
sleep 12

echo "Verifying Nginx is stopped"
if [ "$(docker inspect -f '{{.State.Running}}' test-nginx)" = "true" ]; then
  echo "Nginx did not stop after timeout period"
  exit 1
fi

echo "TESTS PASS"