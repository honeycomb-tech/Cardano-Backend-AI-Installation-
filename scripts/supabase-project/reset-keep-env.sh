#!/bin/bash

echo "WARNING: This will remove all containers and container data. Your .env file will be PRESERVED. This action cannot be undone!"
read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
echo    # Move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Operation cancelled."
    exit 1
fi

echo "Stopping and removing all containers (defined in docker-compose.yml and dev/docker-compose.dev.yml)..."
docker compose -f docker-compose.yml -f ./dev/docker-compose.dev.yml down -v --remove-orphans

echo "Cleaning up bind-mounted directories..."
BIND_MOUNTS=(
  "./volumes/db/data"
)

for DIR in "${BIND_MOUNTS[@]}"; do
  if [ -d "$DIR" ]; then
    echo "Deleting $DIR..."
    rm -rf "$DIR"
  else
    echo "Directory $DIR does not exist. Skipping bind mount deletion step..."
  fi
done

# .env file handling removed to preserve existing .env

echo "Volume cleanup complete! Your .env file has been preserved."
echo "Next steps: Start Supabase (e.g., 'docker compose up -d') and then manually recreate the 'carpdb' database if needed." 