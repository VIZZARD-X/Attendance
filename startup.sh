#!/bin/bash
cd backend
echo "Running database migrations..."
python manage.py migrate
echo "Starting Gunicorn server..."
gunicorn attend_backend.wsgi:application --bind=0.0.0.0:8000 --timeout 600
