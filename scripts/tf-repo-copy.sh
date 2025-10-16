rsync -av --progress \
  --exclude='.git' \
  --exclude='.venv' \
  --exclude='LICENSE' \
  ./terraform-template-framework/ ./terraform-aws-static-site-framework/
