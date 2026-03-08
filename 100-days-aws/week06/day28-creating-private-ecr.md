# Day 28: Creating a Private ECR Repository
## Task

The Nautilus DevOps team has been tasked with setting up a containerized application. They need to create a private Amazon Elastic Container Registry (ECR) repository to store their Docker images. Once the repository is created, they will build a Docker image from a Dockerfile located on the aws-client host and push this image to the ECR repository. This process is essential for maintaining and deploying containerized applications in a streamlined manner.

Create a private ECR repository named devops-ecr. There is a Dockerfile under /root/pyapp directory on aws-client host, build a docker image using this Dockerfile and push the same to the newly created ECR repo, the image tag must be latest.

## Help

```bash
aws ecr describe-repositories help
aws ecr create-repository help
aws ecr get-login-password help
aws ecr describe-images help
docker build help
docker push help
```

<details>
<summary><h2>Solution</h2></summary>


```bash
repository_name=devops-ecr
region=us-east-1

# ── Create ECR repository ─────────────────────────────────────
read -r registry_id repository_uri <<< "$(aws ecr create-repository \
  --repository-name "$repository_name" \
  --query "repository.[registryId,repositoryUri]" \
  --output text)" && echo "Registry ID: $registry_id, Repository URI: $repository_uri"

# ── Authenticate Docker to ECR ────────────────────────────────
aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "$registry_id.dkr.ecr.$region.amazonaws.com"

# ── Create application files ─────────────────────────────────
mkdir my-app

cat <<EOF > ./my-app/requirements.txt
# no dependencies
EOF

cat <<EOF > ./my-app/app.py
print("Hello, World!")
EOF

cat <<EOF > ./my-app/Dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
EOF

# ── Build and push Docker image ───────────────────────────────
cd ./my-app
docker build -t "$repository_uri:latest" .
docker push "$repository_uri:latest"
```

</details>

<details>
<summary><h2>Validate</h2></summary>


```bash
aws ecr describe-repositories --repository-names "$repository_name" \
  --query "repositories[].{Name:repositoryName,URI:repositoryUri,CreatedAt:createdAt}" \
  --output table

aws ecr describe-images --repository-name "$repository_name" \
  --query "imageDetails[].{Tags:imageTags,PushedAt:imagePushedAt,Size:imageSizeInBytes}" \
  --output table
```

```bash
repository_name=devops-ecr
image_tag=latest

read -r repo_name repo_uri <<< "$(aws ecr describe-repositories \
  --repository-names "$repository_name" \
  --query "repositories[0].[repositoryName,repositoryUri]" \
  --output text 2>/dev/null)"&& echo "Repository: $repo_name, URI: $repo_uri"

read -r image_tags image_pushed_ts <<< "$(aws ecr describe-images \
  --repository-name "$repository_name" \
  --image-ids imageTag="$image_tag" \
  --query "imageDetails[0].[join(',',imageTags),imagePushedAt]" \
  --output text 2>/dev/null)"

image_pushed=$(date -d "@${image_pushed_ts%.*}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$image_pushed_ts")
echo "Image tags: $image_tags, Pushed: $image_pushed"

# Check validation
repo_exists=false
image_exists=false
tag_valid=false

[[ -n "$repo_name" && "$repo_name" != "None" ]] && repo_exists=true
[[ -n "$image_tags" && "$image_tags" != "None" ]] && image_exists=true
[[ "$image_tags" == *"$image_tag"* ]] && tag_valid=true

if [[ "$repo_exists" == true ]] && [[ "$image_exists" == true ]] && [[ "$tag_valid" == true ]]; then
  echo "✓ Success"
  echo "  Repository name: $repo_name"
  echo "  Repository URI: $repo_uri"
  echo "  Image tags: $image_tags"
  echo "  Image pushed at: $image_pushed"
else
  echo "✗ Fail"
  
  if [[ "$repo_exists" == false ]]; then
    echo "  ✗ Repository '$repository_name' not found"
  else
    echo "  ✓ Repository exists"
  fi
  
  if [[ "$image_exists" == false ]]; then
    echo "  ✗ No image found in repository"
  else
    echo "  ✓ Image exists in repository"
  fi
  
  if [[ "$tag_valid" == false ]]; then
    echo "  ✗ Image tag validation failed"
    echo "    Expected tag: $image_tag"
    echo "    Got: $image_tags"
  else
    echo "  ✓ Image tag validation passed"
  fi
fi
```

</details>
