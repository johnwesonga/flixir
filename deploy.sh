#!/bin/bash

# Flixir Docker Deployment Script

set -e

echo "🚀 Starting Flixir deployment..."

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ .env file not found. Please copy .env.example to .env and configure it."
    echo "   cp .env.example .env"
    echo "   # Edit .env with your configuration"
    exit 1
fi

# Check required environment variables
required_vars=("SECRET_KEY_BASE" "TMDB_API_KEY" "POSTGRES_PASSWORD")
for var in "${required_vars[@]}"; do
    if ! grep -q "^$var=" .env || grep -q "^$var=$" .env || grep -q "^$var=your_" .env; then
        echo "❌ Required environment variable $var is missing or not configured in .env"
        exit 1
    fi
done

echo "✅ Environment configuration validated"

# Build and start services
echo "🔨 Building and starting services..."
docker compose --env-file .env up -d --build

echo "⏳ Waiting for services to be healthy..."
sleep 10

# Wait for database to be ready
echo "🗄️  Waiting for database to be ready..."
docker compose exec -T postgres pg_isready -U flixir -d flixir_prod || {
    echo "❌ Database is not ready"
    exit 1
}

# Run database migrations
echo "🔄 Running database migrations..."
docker compose exec -T flixir /app/bin/flixir eval "Flixir.Release.migrate()"

echo "✅ Deployment completed successfully!"
echo ""
echo "🌐 Application is available at:"
echo "   http://localhost:4000"
echo ""
echo "📊 To view logs:"
echo "   docker-compose logs -f flixir"
echo ""
echo "🛑 To stop the application:"
echo "   docker-compose down"
echo ""
echo "🔄 To update the application:"
echo "   docker-compose down"
echo "   docker-compose up -d --build"