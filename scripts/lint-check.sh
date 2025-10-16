#!/usr/bin/env bash
set -e

echo "🔍 Running lint checks..."
terraform fmt -check -recursive
tflint --init
tflint --recursive
